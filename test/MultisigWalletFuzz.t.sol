// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IMultisigWallet} from "../src/interfaces/IMultisigWallet.sol";
import {MultisigWalletFixture} from "./helpers/MultisigWalletTestHarness.sol";

contract FuzzWalletExecutionTarget {
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

contract MultisigWalletFuzzTest is MultisigWalletFixture {
    FuzzWalletExecutionTarget internal firstTarget;
    FuzzWalletExecutionTarget internal secondTarget;

    function setUp() public override {
        super.setUp();
        firstTarget = new FuzzWalletExecutionTarget();
        secondTarget = new FuzzWalletExecutionTarget();
    }

    function testFuzzExecuteTransactionWithThresholdSignatures(uint96 numberRaw, uint96 valueRaw) public {
        uint256 value = uint256(valueRaw) % 1 ether;
        bytes memory data = abi.encodeCall(FuzzWalletExecutionTarget.setNumber, (uint256(numberRaw)));
        bytes memory signatures = _packedSignaturesForTransaction(address(firstTarget), value, data, wallet.nonce(), 2);

        VM.deal(address(wallet), value);

        uint256 nonceBefore = wallet.nonce();
        wallet.executeTransaction(address(firstTarget), value, data, signatures);

        assertTrue(firstTarget.storedNumber() == uint256(numberRaw), "target number mismatch");
        assertTrue(firstTarget.lastCaller() == address(wallet), "wallet should be caller");
        assertTrue(firstTarget.lastValue() == value, "target value mismatch");
        assertTrue(wallet.nonce() == nonceBefore + 1, "nonce should increment once");
    }

    function testFuzzExecuteBatchWithThresholdSignatures(uint96 firstRaw, uint96 secondRaw, uint96 valueRaw) public {
        uint256 value = uint256(valueRaw) % 1 ether;
        bytes memory transactions = bytes.concat(
            _encodeBatchEntry(
                address(firstTarget), 0, abi.encodeCall(FuzzWalletExecutionTarget.setNumber, (uint256(firstRaw)))
            ),
            _encodeBatchEntry(
                address(secondTarget), value, abi.encodeCall(FuzzWalletExecutionTarget.setNumber, (uint256(secondRaw)))
            )
        );
        bytes memory signatures = _packedSignaturesForBatch(transactions, wallet.nonce(), 2);

        VM.deal(address(wallet), value);

        uint256 nonceBefore = wallet.nonce();
        wallet.executeBatch(transactions, signatures);

        assertTrue(firstTarget.storedNumber() == uint256(firstRaw), "first target mismatch");
        assertTrue(secondTarget.storedNumber() == uint256(secondRaw), "second target mismatch");
        assertTrue(firstTarget.lastCaller() == address(wallet), "wallet should call first target");
        assertTrue(secondTarget.lastCaller() == address(wallet), "wallet should call second target");
        assertTrue(secondTarget.lastValue() == value, "second target value mismatch");
        assertTrue(wallet.nonce() == nonceBefore + 1, "nonce should increment once");
    }

    function testFuzzMalformedSignatureLengthPreservesNonce(uint16 lengthRaw) public {
        uint256 length = uint256(lengthRaw) % 260;
        if (length == 130) {
            length = 129;
        }
        bytes memory data = abi.encodeCall(FuzzWalletExecutionTarget.setNumber, (1));
        bytes memory signatures = new bytes(length);

        uint256 nonceBefore = wallet.nonce();

        VM.expectRevert(
            abi.encodeWithSelector(IMultisigWallet.MultisigWalletInvalidSignaturesLength.selector, length, 130)
        );
        wallet.executeTransaction(address(firstTarget), 0, data, signatures);

        assertTrue(wallet.nonce() == nonceBefore, "nonce should not change");
    }

    function testFuzzWrongNonceSignaturePreservesNonce(uint8 nonceOffsetRaw, uint96 numberRaw) public {
        uint256 wrongNonce = wallet.nonce() + (uint256(nonceOffsetRaw) % 64) + 1;
        bytes memory data = abi.encodeCall(FuzzWalletExecutionTarget.setNumber, (uint256(numberRaw)));
        bytes memory signatures = _packedSignaturesForTransaction(address(firstTarget), 0, data, wrongNonce, 2);

        uint256 nonceBefore = wallet.nonce();

        VM.expectRevert();
        wallet.executeTransaction(address(firstTarget), 0, data, signatures);

        assertTrue(wallet.nonce() == nonceBefore, "nonce should not change");
    }

    function testFuzzDuplicateSignersPreserveNonce(uint96 numberRaw) public {
        bytes memory data = abi.encodeCall(FuzzWalletExecutionTarget.setNumber, (uint256(numberRaw)));
        bytes32 digest = wallet.getTransactionHash(address(firstTarget), 0, data, wallet.nonce());
        bytes memory signatures = bytes.concat(_signatureForOwnerIndex(digest, 0), _signatureForOwnerIndex(digest, 0));

        uint256 nonceBefore = wallet.nonce();

        VM.expectRevert();
        wallet.executeTransaction(address(firstTarget), 0, data, signatures);

        assertTrue(wallet.nonce() == nonceBefore, "nonce should not change");
    }

    function testFuzzUnsortedSignersPreserveNonce(uint96 numberRaw) public {
        bytes memory data = abi.encodeCall(FuzzWalletExecutionTarget.setNumber, (uint256(numberRaw)));
        bytes32 digest = wallet.getTransactionHash(address(firstTarget), 0, data, wallet.nonce());
        uint256[] memory sortedIndexes = _sortedOwnerIndexes(2);
        bytes memory signatures = bytes.concat(
            _signatureForOwnerIndex(digest, sortedIndexes[1]), _signatureForOwnerIndex(digest, sortedIndexes[0])
        );

        uint256 nonceBefore = wallet.nonce();

        VM.expectRevert();
        wallet.executeTransaction(address(firstTarget), 0, data, signatures);

        assertTrue(wallet.nonce() == nonceBefore, "nonce should not change");
    }

    function testFuzzInvalidNonOwnerSignerPreservesNonce(uint96 numberRaw) public {
        bytes memory data = abi.encodeCall(FuzzWalletExecutionTarget.setNumber, (uint256(numberRaw)));
        uint256[] memory signerIndexes = new uint256[](2);
        signerIndexes[0] = 0;
        signerIndexes[1] = 3;
        bytes memory signatures =
            _packedSignaturesForTransactionByIndexes(address(firstTarget), 0, data, wallet.nonce(), signerIndexes);

        uint256 nonceBefore = wallet.nonce();

        VM.expectRevert();
        wallet.executeTransaction(address(firstTarget), 0, data, signatures);

        assertTrue(wallet.nonce() == nonceBefore, "nonce should not change");
    }

    function testFuzzReplayPreservesNonceAfterSuccessfulExecution(uint96 numberRaw) public {
        bytes memory data = abi.encodeCall(FuzzWalletExecutionTarget.setNumber, (uint256(numberRaw)));
        bytes memory signatures = _packedSignaturesForTransaction(address(firstTarget), 0, data, wallet.nonce(), 2);

        wallet.executeTransaction(address(firstTarget), 0, data, signatures);
        uint256 nonceAfterSuccess = wallet.nonce();

        VM.expectRevert();
        wallet.executeTransaction(address(firstTarget), 0, data, signatures);

        assertTrue(wallet.nonce() == nonceAfterSuccess, "nonce should not change on replay");
    }

    function testFuzzTargetRevertPreservesNonce(bool useBatch) public {
        uint256 nonceBefore = wallet.nonce();

        if (useBatch) {
            bytes memory transactions = _encodeBatchEntry(
                address(firstTarget), 0, abi.encodeCall(FuzzWalletExecutionTarget.revertWithReason, ())
            );
            bytes memory signatures = _packedSignaturesForBatch(transactions, wallet.nonce(), 2);

            VM.expectRevert(bytes("wallet-call-failed"));
            wallet.executeBatch(transactions, signatures);
        } else {
            bytes memory data = abi.encodeCall(FuzzWalletExecutionTarget.revertWithReason, ());
            bytes memory signatures = _packedSignaturesForTransaction(address(firstTarget), 0, data, wallet.nonce(), 2);

            VM.expectRevert(bytes("wallet-call-failed"));
            wallet.executeTransaction(address(firstTarget), 0, data, signatures);
        }

        assertTrue(wallet.nonce() == nonceBefore, "nonce should not change");
    }

    function testFuzzFreshWalletThresholdRequiresExactSignatureCount(uint8 ownerCountRaw, uint8 thresholdRaw) public {
        uint256 ownerCount = (uint256(ownerCountRaw) % actorAddresses.length) + 1;
        uint256 threshold_ = (uint256(thresholdRaw) % ownerCount) + 1;
        address[] memory owners = _ownerPrefix(ownerCount);
        bytes32 salt = keccak256(abi.encode("threshold-fuzz", ownerCount, threshold_, ownerCountRaw, thresholdRaw));
        IMultisigWallet localWallet = _deployInitializedWallet(salt, owners, threshold_, defaultMultiSend);

        bytes memory data = abi.encodeCall(FuzzWalletExecutionTarget.setNumber, (ownerCount + threshold_));
        bytes memory validSignatures =
            _packedSignaturesForTransactionAtWallet(address(localWallet), address(firstTarget), 0, data, 0, threshold_);

        localWallet.executeTransaction(address(firstTarget), 0, data, validSignatures);
        assertTrue(localWallet.nonce() == 1, "valid threshold nonce mismatch");
        assertTrue(firstTarget.storedNumber() == ownerCount + threshold_, "valid threshold execution mismatch");

        bytes memory shortSignatures = _packedSignaturesForTransactionAtWallet(
            address(localWallet), address(firstTarget), 0, data, localWallet.nonce(), threshold_ - 1
        );

        VM.expectRevert(
            abi.encodeWithSelector(
                IMultisigWallet.MultisigWalletInvalidSignaturesLength.selector, shortSignatures.length, threshold_ * 65
            )
        );
        localWallet.executeTransaction(address(firstTarget), 0, data, shortSignatures);

        assertTrue(localWallet.nonce() == 1, "short signature nonce should not change");
    }

    function _ownerPrefix(uint256 ownerCount) internal view returns (address[] memory owners) {
        owners = new address[](ownerCount);
        for (uint256 i = 0; i < ownerCount; i++) {
            owners[i] = actorAddresses[i];
        }
    }

    function _signatureForOwnerIndex(bytes32 digest, uint256 ownerIndex) internal returns (bytes memory signature) {
        (uint8 v, bytes32 r, bytes32 s) = VM.sign(actorKeys[ownerIndex], digest);
        signature = new bytes(65);

        assembly {
            mstore(add(signature, 0x20), r)
            mstore(add(signature, 0x40), s)
            mstore8(add(signature, 0x60), v)
        }
    }
}
