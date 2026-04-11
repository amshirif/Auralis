// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IMultiSendCallOnly} from "../src/interfaces/IMultiSendCallOnly.sol";
import {IMultisigWallet} from "../src/interfaces/IMultisigWallet.sol";
import {IMultisigWalletFactory} from "../src/interfaces/IMultisigWalletFactory.sol";
import {LibClone} from "../src/libraries/LibClone.sol";
import {MultisigWalletFactory} from "../src/wallet/MultisigWalletFactory.sol";
import {MultisigWalletFixture} from "./helpers/MultisigWalletTestHarness.sol";

contract BatchExecutionTarget {
    uint256 public storedNumber;
    address public lastCaller;
    uint256 public lastValue;

    receive() external payable {
        lastCaller = msg.sender;
        lastValue = msg.value;
    }

    function setNumber(uint256 newNumber) external payable {
        storedNumber = newNumber;
        lastCaller = msg.sender;
        lastValue = msg.value;
    }

    function revertWithReason() external pure {
        revert("wallet-call-failed");
    }
}

contract MultisigWalletIntegrationTest is MultisigWalletFixture {
    MultisigWalletFactory internal factory;
    BatchExecutionTarget internal firstTarget;
    BatchExecutionTarget internal secondTarget;

    function setUp() public override {
        super.setUp();

        factory = new MultisigWalletFactory(address(implementation));
        firstTarget = new BatchExecutionTarget();
        secondTarget = new BatchExecutionTarget();
    }

    function testBatchHashMatchesExpectedDigest() public view {
        bytes memory transactions = bytes.concat(
            _encodeBatchEntry(address(firstTarget), 0, abi.encodeCall(BatchExecutionTarget.setNumber, (11))),
            _encodeBatchEntry(address(secondTarget), 0, abi.encodeCall(BatchExecutionTarget.setNumber, (22)))
        );

        assertTrue(
            wallet.getBatchHash(transactions, 0) == _batchDigest(address(wallet), transactions, 0), "hash mismatch"
        );
    }

    function testExecuteBatchCallsMultipleTargetsAndAdvancesNonce() public {
        bytes memory transactions = bytes.concat(
            _encodeBatchEntry(address(firstTarget), 0, abi.encodeCall(BatchExecutionTarget.setNumber, (11))),
            _encodeBatchEntry(address(secondTarget), 0, abi.encodeCall(BatchExecutionTarget.setNumber, (22)))
        );
        bytes memory signatures = _packedSignaturesForBatch(transactions, wallet.nonce(), 2);

        wallet.executeBatch(transactions, signatures);

        assertTrue(firstTarget.storedNumber() == 11, "first target mismatch");
        assertTrue(secondTarget.storedNumber() == 22, "second target mismatch");
        assertTrue(firstTarget.lastCaller() == address(wallet), "wallet should call first target");
        assertTrue(secondTarget.lastCaller() == address(wallet), "wallet should call second target");
        assertTrue(wallet.nonce() == 1, "nonce should increment");
    }

    function testExecuteBatchTransfersEthToMultipleTargets() public {
        VM.deal(address(wallet), 1 ether);

        bytes memory transactions = bytes.concat(
            _encodeBatchEntry(address(firstTarget), 0.2 ether, ""),
            _encodeBatchEntry(address(secondTarget), 0.3 ether, "")
        );
        bytes memory signatures = _packedSignaturesForBatch(transactions, wallet.nonce(), 2);

        wallet.executeBatch(transactions, signatures);

        assertTrue(address(firstTarget).balance == 0.2 ether, "first target balance mismatch");
        assertTrue(address(secondTarget).balance == 0.3 ether, "second target balance mismatch");
        assertTrue(firstTarget.lastValue() == 0.2 ether, "first target value mismatch");
        assertTrue(secondTarget.lastValue() == 0.3 ether, "second target value mismatch");
    }

    function testExecuteBatchBubblesTargetRevertAndPreservesNonce() public {
        bytes memory transactions = bytes.concat(
            _encodeBatchEntry(address(firstTarget), 0, abi.encodeCall(BatchExecutionTarget.setNumber, (11))),
            _encodeBatchEntry(address(secondTarget), 0, abi.encodeCall(BatchExecutionTarget.revertWithReason, ()))
        );
        bytes memory signatures = _packedSignaturesForBatch(transactions, wallet.nonce(), 2);

        VM.expectRevert(bytes("wallet-call-failed"));
        wallet.executeBatch(transactions, signatures);

        assertTrue(wallet.nonce() == 0, "nonce should not advance");
        assertTrue(firstTarget.storedNumber() == 0, "batch should revert atomically");
    }

    function testExecuteBatchRejectsMalformedEncoding() public {
        bytes memory transactions =
            bytes.concat(bytes20(address(firstTarget)), bytes32(uint256(0)), bytes32(uint256(3)));
        bytes memory signatures = _packedSignaturesForBatch(transactions, wallet.nonce(), 2);

        VM.expectRevert();
        wallet.executeBatch(transactions, signatures);
    }

    function testExecuteBatchRejectsZeroTargetEntry() public {
        bytes memory transactions = _encodeBatchEntry(address(0), 0, "");
        bytes memory signatures = _packedSignaturesForBatch(transactions, wallet.nonce(), 2);

        VM.expectRevert(abi.encodeWithSelector(IMultiSendCallOnly.MultiSendCallOnlyZeroTarget.selector, 0));
        wallet.executeBatch(transactions, signatures);
    }

    function testFactoryPredictsDeterministicAddress() public view {
        bytes32 salt = keccak256("auralis.multisig.factory-wallet");
        address expected = LibClone.predictDeterministicAddress(address(implementation), salt, address(factory));

        assertTrue(factory.predictWalletAddress(salt) == expected, "predicted address mismatch");
    }

    function testFactoryDeploysAndInitializesWallet() public {
        bytes32 salt = keccak256("auralis.multisig.factory-initialize");
        address expected = factory.predictWalletAddress(salt);

        address deployed = factory.deployWallet(salt, _initialOwners(), 2, defaultMultiSend);
        IMultisigWallet deployedWallet = IMultisigWallet(deployed);

        assertTrue(deployed == expected, "deployed wallet mismatch");
        assertTrue(deployedWallet.threshold() == 2, "threshold mismatch");
        assertTrue(deployedWallet.ownerCount() == 3, "owner count mismatch");
        assertTrue(deployedWallet.multiSendCallOnly() == defaultMultiSend, "helper mismatch");
    }

    function testFactoryDeployedWalletExecutesSignedSingleCall() public {
        bytes32 salt = keccak256("auralis.multisig.factory-single-call");
        IMultisigWallet deployedWallet =
            IMultisigWallet(factory.deployWallet(salt, _initialOwners(), 2, defaultMultiSend));

        bytes memory data = abi.encodeCall(BatchExecutionTarget.setNumber, (33));
        bytes memory signatures =
            _packedSignaturesForTransactionAtWallet(address(deployedWallet), address(firstTarget), 0, data, 0, 2);

        deployedWallet.executeTransaction(address(firstTarget), 0, data, signatures);

        assertTrue(firstTarget.storedNumber() == 33, "single-call target mismatch");
        assertTrue(deployedWallet.nonce() == 1, "single-call nonce mismatch");
    }

    function testFactoryDeployedWalletExecutesSignedBatch() public {
        bytes32 salt = keccak256("auralis.multisig.factory-batch-call");
        IMultisigWallet deployedWallet =
            IMultisigWallet(factory.deployWallet(salt, _initialOwners(), 2, defaultMultiSend));

        bytes memory transactions = bytes.concat(
            _encodeBatchEntry(address(firstTarget), 0, abi.encodeCall(BatchExecutionTarget.setNumber, (44))),
            _encodeBatchEntry(address(secondTarget), 0, abi.encodeCall(BatchExecutionTarget.setNumber, (55)))
        );
        bytes memory signatures = _packedSignaturesForBatchAtWallet(address(deployedWallet), transactions, 0, 2);

        deployedWallet.executeBatch(transactions, signatures);

        assertTrue(firstTarget.storedNumber() == 44, "first batch target mismatch");
        assertTrue(secondTarget.storedNumber() == 55, "second batch target mismatch");
        assertTrue(deployedWallet.nonce() == 1, "batch nonce mismatch");
    }

    function testFactoryRejectsZeroImplementation() public {
        VM.expectRevert(IMultisigWalletFactory.MultisigWalletFactoryZeroImplementation.selector);
        new MultisigWalletFactory(address(0));
    }
}
