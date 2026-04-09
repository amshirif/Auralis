// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IMultisigWallet} from "../src/interfaces/IMultisigWallet.sol";
import {MultisigWalletFixture} from "./helpers/MultisigWalletTestHarness.sol";

contract MultisigWalletFoundationCoreTest is MultisigWalletFixture {
    function testImplementationIsLockedAndCloneInitializesOnce() public {
        VM.expectRevert(IMultisigWallet.MultisigWalletAlreadyInitialized.selector);
        implementation.initialize(_initialOwners(), 2, DEFAULT_MULTI_SEND);

        VM.expectRevert(IMultisigWallet.MultisigWalletAlreadyInitialized.selector);
        wallet.initialize(_initialOwners(), 2, DEFAULT_MULTI_SEND);

        assertTrue(wallet.threshold() == 2, "threshold mismatch");
        assertTrue(wallet.ownerCount() == 3, "owner count mismatch");
        assertTrue(wallet.multiSendCallOnly() == DEFAULT_MULTI_SEND, "helper mismatch");
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
        clone.initialize(owners, 2, DEFAULT_MULTI_SEND);
    }

    function testInitializationRejectsZeroOwner() public {
        address[] memory owners = new address[](2);
        owners[0] = actorAddresses[0];
        owners[1] = address(0);

        IMultisigWallet clone = IMultisigWallet(_deployUninitializedClone(keccak256("zero-owner")));

        VM.expectRevert(IMultisigWallet.MultisigWalletZeroOwner.selector);
        clone.initialize(owners, 2, DEFAULT_MULTI_SEND);
    }

    function testInitializationRejectsInvalidThreshold() public {
        address[] memory owners = new address[](2);
        owners[0] = actorAddresses[0];
        owners[1] = actorAddresses[1];

        IMultisigWallet zeroThresholdClone =
            IMultisigWallet(_deployUninitializedClone(keccak256("zero-threshold")));
        VM.expectRevert(abi.encodeWithSelector(IMultisigWallet.MultisigWalletInvalidThreshold.selector, 0, 2));
        zeroThresholdClone.initialize(owners, 0, DEFAULT_MULTI_SEND);

        IMultisigWallet highThresholdClone =
            IMultisigWallet(_deployUninitializedClone(keccak256("high-threshold")));
        VM.expectRevert(abi.encodeWithSelector(IMultisigWallet.MultisigWalletInvalidThreshold.selector, 3, 2));
        highThresholdClone.initialize(owners, 3, DEFAULT_MULTI_SEND);
    }

    function testInitializationRejectsZeroMultiSendAddress() public {
        IMultisigWallet clone = IMultisigWallet(_deployUninitializedClone(keccak256("zero-multisend")));

        VM.expectRevert(IMultisigWallet.MultisigWalletZeroMultiSend.selector);
        clone.initialize(_initialOwners(), 2, address(0));
    }

    function testGetOwnersReturnsInitializedSet() public view {
        address[] memory owners = wallet.getOwners();

        assertTrue(owners.length == 3, "unexpected owner length");
        assertTrue(owners[0] == actorAddresses[0], "owner 0 mismatch");
        assertTrue(owners[1] == actorAddresses[1], "owner 1 mismatch");
        assertTrue(owners[2] == actorAddresses[2], "owner 2 mismatch");
    }
}
