// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC1271} from "../src/interfaces/IERC1271.sol";
import {IMultisigWallet} from "../src/interfaces/IMultisigWallet.sol";
import {MultisigWalletFixture} from "./helpers/MultisigWalletTestHarness.sol";

contract MultisigWalletFoundationCoreTest is MultisigWalletFixture {
    function testImplementationIsLockedAndCloneInitializesOnce() public {
        VM.expectRevert(IMultisigWallet.MultisigWalletAlreadyInitialized.selector);
        implementation.initialize(_initialOwners(), 2, defaultMultiSend);

        VM.expectRevert(IMultisigWallet.MultisigWalletAlreadyInitialized.selector);
        wallet.initialize(_initialOwners(), 2, defaultMultiSend);

        assertTrue(wallet.threshold() == 2, "threshold mismatch");
        assertTrue(wallet.ownerCount() == 3, "owner count mismatch");
        assertTrue(wallet.multiSendCallOnly() == defaultMultiSend, "helper mismatch");
        assertTrue(wallet.nonce() == 0, "nonce mismatch");
        assertTrue(wallet.isOwner(actorAddresses[0]), "owner A missing");
        assertTrue(wallet.isOwner(actorAddresses[1]), "owner B missing");
        assertTrue(wallet.isOwner(actorAddresses[2]), "owner C missing");
        _assertSupportedInterfaces();
    }

    function testInitializationRejectsDuplicateOwners() public {
        address[] memory owners = new address[](2);
        owners[0] = actorAddresses[0];
        owners[1] = actorAddresses[0];

        IMultisigWallet clone = IMultisigWallet(_deployUninitializedClone(keccak256("duplicate-owner")));

        VM.expectRevert(abi.encodeWithSelector(IMultisigWallet.MultisigWalletDuplicateOwner.selector, owners[0]));
        clone.initialize(owners, 2, defaultMultiSend);
    }

    function testInitializationRejectsZeroOwner() public {
        address[] memory owners = new address[](2);
        owners[0] = actorAddresses[0];
        owners[1] = address(0);

        IMultisigWallet clone = IMultisigWallet(_deployUninitializedClone(keccak256("zero-owner")));

        VM.expectRevert(IMultisigWallet.MultisigWalletZeroOwner.selector);
        clone.initialize(owners, 2, defaultMultiSend);
    }

    function testInitializationRejectsInvalidThreshold() public {
        address[] memory owners = new address[](2);
        owners[0] = actorAddresses[0];
        owners[1] = actorAddresses[1];

        IMultisigWallet zeroThresholdClone = IMultisigWallet(_deployUninitializedClone(keccak256("zero-threshold")));
        VM.expectRevert(abi.encodeWithSelector(IMultisigWallet.MultisigWalletInvalidThreshold.selector, 0, 2));
        zeroThresholdClone.initialize(owners, 0, defaultMultiSend);

        IMultisigWallet highThresholdClone = IMultisigWallet(_deployUninitializedClone(keccak256("high-threshold")));
        VM.expectRevert(abi.encodeWithSelector(IMultisigWallet.MultisigWalletInvalidThreshold.selector, 3, 2));
        highThresholdClone.initialize(owners, 3, defaultMultiSend);
    }

    function testInitializationRejectsZeroMultiSendAddress() public {
        IMultisigWallet clone = IMultisigWallet(_deployUninitializedClone(keccak256("zero-multisend")));

        VM.expectRevert(IMultisigWallet.MultisigWalletZeroMultiSend.selector);
        clone.initialize(_initialOwners(), 2, address(0));
    }

    function testUninitializedCloneCannotExecuteTransactionOrBatch() public {
        IMultisigWallet clone = IMultisigWallet(_deployUninitializedClone(keccak256("uninitialized-execution")));

        VM.expectRevert(IMultisigWallet.MultisigWalletNotOperational.selector);
        clone.executeTransaction(actorAddresses[3], 0, "", "");

        VM.expectRevert(IMultisigWallet.MultisigWalletNotOperational.selector);
        clone.executeBatch("", "");
    }

    function testUninitializedCloneNeverReturnsErc1271Magic() public {
        IMultisigWallet clone = IMultisigWallet(_deployUninitializedClone(keccak256("uninitialized-1271")));
        bytes32 digest = keccak256("auralis.multisig.uninitialized");

        assertTrue(
            IERC1271(address(clone)).isValidSignature(digest, "") == ERC1271_INVALID_SIGNATURE,
            "uninitialized clone should reject empty signatures"
        );
        assertTrue(
            IERC1271(address(clone)).isValidSignature(digest, hex"deadbeef") == ERC1271_INVALID_SIGNATURE,
            "uninitialized clone should reject garbage signatures"
        );
    }

    function testInitializedCloneBecomesOperational() public {
        IMultisigWallet clone = IMultisigWallet(_deployUninitializedClone(keccak256("initialized-operational")));
        clone.initialize(_initialOwners(), 2, defaultMultiSend);

        bytes32 digest = clone.getTransactionHash(actorAddresses[3], 0, "", 0);
        bytes memory signatures = _packedSignaturesForDigestByIndexes(digest, _sortedOwnerIndexes(2));

        clone.executeTransaction(actorAddresses[3], 0, "", signatures);

        assertTrue(
            IERC1271(address(clone)).isValidSignature(digest, signatures) == ERC1271_MAGIC_VALUE,
            "initialized clone should return ERC1271 magic"
        );
        assertTrue(clone.nonce() == 1, "initialized clone should execute successfully");
    }

    function testImplementationCannotExecuteTransactionOrBatch() public {
        VM.expectRevert(IMultisigWallet.MultisigWalletNotOperational.selector);
        implementation.executeTransaction(actorAddresses[3], 0, "", "");

        VM.expectRevert(IMultisigWallet.MultisigWalletNotOperational.selector);
        implementation.executeBatch("", "");
    }

    function testImplementationNeverReturnsErc1271Magic() public view {
        bytes32 digest = keccak256("auralis.multisig.implementation");

        assertTrue(
            IERC1271(address(implementation)).isValidSignature(digest, "") == ERC1271_INVALID_SIGNATURE,
            "implementation should reject empty signatures"
        );
        assertTrue(
            IERC1271(address(implementation)).isValidSignature(digest, hex"deadbeef") == ERC1271_INVALID_SIGNATURE,
            "implementation should reject garbage signatures"
        );
    }

    function testGetOwnersReturnsInitializedSet() public view {
        address[] memory owners = wallet.getOwners();

        assertTrue(owners.length == 3, "unexpected owner length");
        assertTrue(owners[0] == actorAddresses[0], "owner 0 mismatch");
        assertTrue(owners[1] == actorAddresses[1], "owner 1 mismatch");
        assertTrue(owners[2] == actorAddresses[2], "owner 2 mismatch");
    }
}
