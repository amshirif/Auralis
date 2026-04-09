// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC1271} from "../src/interfaces/IERC1271.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IMultisigWallet} from "../src/interfaces/IMultisigWallet.sol";
import {MultisigWalletFixture} from "./helpers/MultisigWalletTestHarness.sol";

contract WalletExecutionTarget {
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

contract MultisigWalletCoreExecutionTest is MultisigWalletFixture {
    WalletExecutionTarget internal target;

    function setUp() public override {
        super.setUp();
        target = new WalletExecutionTarget();
    }

    function testTransactionHashMatchesExpectedDigest() public view {
        bytes memory data = abi.encodeCall(WalletExecutionTarget.setNumber, (77));
        bytes32 expected = _transactionDigest(address(wallet), address(target), 0, data, 0);

        assertTrue(wallet.getTransactionHash(address(target), 0, data, 0) == expected, "transaction hash mismatch");
    }

    function testExecuteTransactionWithThresholdSignatures() public {
        bytes memory data = abi.encodeCall(WalletExecutionTarget.setNumber, (88));
        bytes memory signatures = _packedSignaturesForTransaction(address(target), 0, data, wallet.nonce(), 2);

        VM.prank(actorAddresses[3]);
        wallet.executeTransaction(address(target), 0, data, signatures);

        assertTrue(target.storedNumber() == 88, "target call mismatch");
        assertTrue(target.lastCaller() == address(wallet), "wallet should be caller");
        assertTrue(wallet.nonce() == 1, "nonce should increment");
    }

    function testExecuteTransactionRejectsMalformedSignatureLength() public {
        bytes memory data = abi.encodeCall(WalletExecutionTarget.setNumber, (1));
        bytes memory signatures = new bytes(64);

        VM.expectRevert(abi.encodeWithSelector(IMultisigWallet.MultisigWalletInvalidSignaturesLength.selector, 64, 130));
        wallet.executeTransaction(address(target), 0, data, signatures);
    }

    function testExecuteTransactionRejectsInvalidSigner() public {
        bytes memory data = abi.encodeCall(WalletExecutionTarget.setNumber, (2));
        uint256[] memory signerIndexes = new uint256[](2);
        signerIndexes[0] = 0;
        signerIndexes[1] = 3;
        bytes memory signatures =
            _packedSignaturesForTransactionByIndexes(address(target), 0, data, wallet.nonce(), signerIndexes);

        VM.expectRevert();
        wallet.executeTransaction(address(target), 0, data, signatures);
    }

    function testExecuteTransactionRejectsDuplicateSigners() public {
        bytes memory data = abi.encodeCall(WalletExecutionTarget.setNumber, (3));
        bytes32 digest = wallet.getTransactionHash(address(target), 0, data, wallet.nonce());
        bytes memory signatures = bytes.concat(_signatureForOwnerIndex(digest, 0), _signatureForOwnerIndex(digest, 0));

        VM.expectRevert();
        wallet.executeTransaction(address(target), 0, data, signatures);
    }

    function testExecuteTransactionRejectsUnsortedSigners() public {
        bytes memory data = abi.encodeCall(WalletExecutionTarget.setNumber, (4));
        bytes32 digest = wallet.getTransactionHash(address(target), 0, data, wallet.nonce());
        uint256[] memory sortedIndexes = _sortedOwnerIndexes(2);
        bytes memory signatures = bytes.concat(
            _signatureForOwnerIndex(digest, sortedIndexes[1]), _signatureForOwnerIndex(digest, sortedIndexes[0])
        );

        VM.expectRevert();
        wallet.executeTransaction(address(target), 0, data, signatures);
    }

    function testExecuteTransactionRejectsReplayAfterSuccessfulExecution() public {
        bytes memory data = abi.encodeCall(WalletExecutionTarget.setNumber, (5));
        bytes memory signatures = _packedSignaturesForTransaction(address(target), 0, data, wallet.nonce(), 2);

        wallet.executeTransaction(address(target), 0, data, signatures);

        VM.expectRevert();
        wallet.executeTransaction(address(target), 0, data, signatures);
    }

    function testExecuteTransactionRejectsWrongNonceSignature() public {
        bytes memory data = abi.encodeCall(WalletExecutionTarget.setNumber, (6));
        bytes memory signatures = _packedSignaturesForTransaction(address(target), 0, data, wallet.nonce() + 1, 2);

        VM.expectRevert();
        wallet.executeTransaction(address(target), 0, data, signatures);
    }

    function testExecuteTransactionOnlyAdvancesNonceOnSuccessfulCall() public {
        bytes memory data = abi.encodeCall(WalletExecutionTarget.revertWithReason, ());
        bytes memory signatures = _packedSignaturesForTransaction(address(target), 0, data, wallet.nonce(), 2);

        VM.expectRevert(bytes("wallet-call-failed"));
        wallet.executeTransaction(address(target), 0, data, signatures);

        assertTrue(wallet.nonce() == 0, "nonce should not advance after revert");
    }

    function testExecuteTransactionTransfersEth() public {
        VM.deal(address(wallet), 1 ether);

        bytes memory signatures = _packedSignaturesForTransaction(address(target), 0.25 ether, "", wallet.nonce(), 2);
        wallet.executeTransaction(address(target), 0.25 ether, "", signatures);

        assertTrue(address(target).balance == 0.25 ether, "target eth mismatch");
        assertTrue(target.lastCaller() == address(wallet), "wallet should send ether");
        assertTrue(target.lastValue() == 0.25 ether, "target value mismatch");
    }

    function testIsValidSignatureReturnsMagicValueForValidSignatures() public {
        bytes32 digest = keccak256("auralis.multisig.digest");
        bytes memory signatures = _packedSignaturesForDigest(digest, 2);

        assertTrue(
            IERC1271(address(wallet)).isValidSignature(digest, signatures) == ERC1271_MAGIC_VALUE,
            "valid signature should return magic value"
        );
    }

    function testIsValidSignatureReturnsFailureValueForInvalidSignatures() public {
        bytes32 digest = keccak256("auralis.multisig.invalid-digest");
        uint256[] memory signerIndexes = new uint256[](2);
        signerIndexes[0] = 0;
        signerIndexes[1] = 3;
        bytes memory signatures = _packedSignaturesForDigestByIndexes(digest, signerIndexes);

        assertTrue(
            IERC1271(address(wallet)).isValidSignature(digest, signatures) == ERC1271_INVALID_SIGNATURE,
            "invalid signature should fail"
        );
    }

    function testSupportsInterfaceIncludesErc1271() public view {
        assertTrue(IERC165(address(wallet)).supportsInterface(type(IERC1271).interfaceId), "missing IERC1271");
        assertTrue(IERC165(address(wallet)).supportsInterface(type(IMultisigWallet).interfaceId), "missing wallet");
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
