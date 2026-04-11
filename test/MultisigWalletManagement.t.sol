// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IMultisigWallet} from "../src/interfaces/IMultisigWallet.sol";
import {MultisigWalletFixture} from "./helpers/MultisigWalletTestHarness.sol";

contract MultisigWalletManagementTest is MultisigWalletFixture {
    function testDirectManagementCallsRequireSelfCall() public {
        VM.expectRevert(IMultisigWallet.MultisigWalletCallerNotSelf.selector);
        wallet.addOwner(actorAddresses[3]);

        VM.expectRevert(IMultisigWallet.MultisigWalletCallerNotSelf.selector);
        wallet.removeOwner(actorAddresses[0]);

        VM.expectRevert(IMultisigWallet.MultisigWalletCallerNotSelf.selector);
        wallet.replaceOwner(actorAddresses[0], actorAddresses[3]);

        VM.expectRevert(IMultisigWallet.MultisigWalletCallerNotSelf.selector);
        wallet.changeThreshold(1);
    }

    function testSignedSelfCallCanAddOwner() public {
        _executeSelfTransaction(wallet, abi.encodeCall(IMultisigWallet.addOwner, (actorAddresses[3])));

        assertTrue(wallet.ownerCount() == 4, "owner count mismatch");
        assertTrue(wallet.threshold() == 2, "threshold should remain unchanged");
        assertTrue(wallet.isOwner(actorAddresses[3]), "new owner missing");

        address[] memory owners = wallet.getOwners();
        assertTrue(owners.length == 4, "owners length mismatch");
        assertTrue(owners[3] == actorAddresses[3], "new owner should append");
    }

    function testAddOwnerRejectsZeroOwner() public {
        bytes memory data = abi.encodeCall(IMultisigWallet.addOwner, (address(0)));
        bytes memory signatures = _packedCurrentThresholdSignaturesForTransaction(wallet, address(wallet), 0, data);

        VM.expectRevert(IMultisigWallet.MultisigWalletZeroOwner.selector);
        wallet.executeTransaction(address(wallet), 0, data, signatures);

        assertTrue(wallet.ownerCount() == 3, "owner count should remain unchanged");
        assertTrue(wallet.nonce() == 0, "nonce should remain unchanged");
    }

    function testAddOwnerRejectsDuplicateOwner() public {
        bytes memory data = abi.encodeCall(IMultisigWallet.addOwner, (actorAddresses[0]));
        bytes memory signatures = _packedCurrentThresholdSignaturesForTransaction(wallet, address(wallet), 0, data);

        VM.expectRevert(
            abi.encodeWithSelector(IMultisigWallet.MultisigWalletDuplicateOwner.selector, actorAddresses[0])
        );
        wallet.executeTransaction(address(wallet), 0, data, signatures);

        assertTrue(wallet.ownerCount() == 3, "owner count should remain unchanged");
        assertTrue(wallet.nonce() == 0, "nonce should remain unchanged");
    }

    function testSignedSelfCallCanRemoveOwnerAndSwapPop() public {
        _executeSelfTransaction(wallet, abi.encodeCall(IMultisigWallet.removeOwner, (actorAddresses[0])));

        assertTrue(wallet.ownerCount() == 2, "owner count mismatch");
        assertTrue(wallet.threshold() == 2, "threshold should remain unchanged");
        assertFalse(wallet.isOwner(actorAddresses[0]), "removed owner should be absent");
        assertTrue(wallet.isOwner(actorAddresses[1]), "second owner missing");
        assertTrue(wallet.isOwner(actorAddresses[2]), "third owner missing");

        address[] memory owners = wallet.getOwners();
        assertTrue(owners.length == 2, "owners length mismatch");
        assertTrue(owners[0] == actorAddresses[2], "swap-and-pop should move last owner into removed slot");
        assertTrue(owners[1] == actorAddresses[1], "middle owner should remain");
    }

    function testRemoveOwnerRejectsMissingOwner() public {
        bytes memory data = abi.encodeCall(IMultisigWallet.removeOwner, (actorAddresses[5]));
        bytes memory signatures = _packedCurrentThresholdSignaturesForTransaction(wallet, address(wallet), 0, data);

        VM.expectRevert(abi.encodeWithSelector(IMultisigWallet.MultisigWalletOwnerNotFound.selector, actorAddresses[5]));
        wallet.executeTransaction(address(wallet), 0, data, signatures);
    }

    function testRemoveOwnerRejectsLastOwner() public {
        address[] memory singleOwner = new address[](1);
        singleOwner[0] = actorAddresses[0];
        IMultisigWallet singleOwnerWallet =
            _deployInitializedWallet(keccak256("auralis.multisig.single-owner"), singleOwner, 1, defaultMultiSend);

        bytes memory data = abi.encodeCall(IMultisigWallet.removeOwner, (actorAddresses[0]));
        bytes memory signatures =
            _packedCurrentThresholdSignaturesForTransaction(singleOwnerWallet, address(singleOwnerWallet), 0, data);

        VM.expectRevert(IMultisigWallet.MultisigWalletCannotRemoveLastOwner.selector);
        singleOwnerWallet.executeTransaction(address(singleOwnerWallet), 0, data, signatures);

        assertTrue(singleOwnerWallet.ownerCount() == 1, "single-owner wallet should remain unchanged");
        assertTrue(singleOwnerWallet.nonce() == 0, "nonce should remain unchanged");
    }

    function testRemoveOwnerRejectsThresholdInvalidatingRemoval() public {
        address[] memory twoOwners = new address[](2);
        twoOwners[0] = actorAddresses[0];
        twoOwners[1] = actorAddresses[1];
        IMultisigWallet twoOwnerWallet =
            _deployInitializedWallet(keccak256("auralis.multisig.two-owner"), twoOwners, 2, defaultMultiSend);

        bytes memory data = abi.encodeCall(IMultisigWallet.removeOwner, (actorAddresses[0]));
        bytes memory signatures =
            _packedCurrentThresholdSignaturesForTransaction(twoOwnerWallet, address(twoOwnerWallet), 0, data);

        VM.expectRevert(
            abi.encodeWithSelector(IMultisigWallet.MultisigWalletRemovalInvalidatesThreshold.selector, 2, 1)
        );
        twoOwnerWallet.executeTransaction(address(twoOwnerWallet), 0, data, signatures);
    }

    function testSignedSelfCallCanReplaceOwner() public {
        _executeSelfTransaction(
            wallet, abi.encodeCall(IMultisigWallet.replaceOwner, (actorAddresses[0], actorAddresses[3]))
        );

        assertTrue(wallet.ownerCount() == 3, "owner count should remain unchanged");
        assertTrue(wallet.threshold() == 2, "threshold should remain unchanged");
        assertFalse(wallet.isOwner(actorAddresses[0]), "old owner should be absent");
        assertTrue(wallet.isOwner(actorAddresses[3]), "replacement owner missing");

        address[] memory owners = wallet.getOwners();
        assertTrue(owners[0] == actorAddresses[3], "replacement should preserve slot");
    }

    function testReplaceOwnerRejectsMissingOwner() public {
        bytes memory data = abi.encodeCall(IMultisigWallet.replaceOwner, (actorAddresses[5], actorAddresses[3]));
        bytes memory signatures = _packedCurrentThresholdSignaturesForTransaction(wallet, address(wallet), 0, data);

        VM.expectRevert(abi.encodeWithSelector(IMultisigWallet.MultisigWalletOwnerNotFound.selector, actorAddresses[5]));
        wallet.executeTransaction(address(wallet), 0, data, signatures);
    }

    function testReplaceOwnerRejectsZeroReplacement() public {
        bytes memory data = abi.encodeCall(IMultisigWallet.replaceOwner, (actorAddresses[0], address(0)));
        bytes memory signatures = _packedCurrentThresholdSignaturesForTransaction(wallet, address(wallet), 0, data);

        VM.expectRevert(IMultisigWallet.MultisigWalletZeroOwner.selector);
        wallet.executeTransaction(address(wallet), 0, data, signatures);
    }

    function testReplaceOwnerRejectsDuplicateReplacement() public {
        bytes memory data = abi.encodeCall(IMultisigWallet.replaceOwner, (actorAddresses[0], actorAddresses[1]));
        bytes memory signatures = _packedCurrentThresholdSignaturesForTransaction(wallet, address(wallet), 0, data);

        VM.expectRevert(
            abi.encodeWithSelector(IMultisigWallet.MultisigWalletDuplicateOwner.selector, actorAddresses[1])
        );
        wallet.executeTransaction(address(wallet), 0, data, signatures);
    }

    function testReplaceOwnerRejectsSameAddressNoop() public {
        bytes memory data = abi.encodeCall(IMultisigWallet.replaceOwner, (actorAddresses[0], actorAddresses[0]));
        bytes memory signatures = _packedCurrentThresholdSignaturesForTransaction(wallet, address(wallet), 0, data);

        VM.expectRevert(
            abi.encodeWithSelector(IMultisigWallet.MultisigWalletReplaceOwnerNoop.selector, actorAddresses[0])
        );
        wallet.executeTransaction(address(wallet), 0, data, signatures);
    }

    function testSignedSelfCallCanChangeThreshold() public {
        _executeSelfTransaction(wallet, abi.encodeCall(IMultisigWallet.changeThreshold, (3)));

        assertTrue(wallet.threshold() == 3, "threshold should update");
        assertTrue(wallet.ownerCount() == 3, "owner count should remain unchanged");
    }

    function testChangeThresholdRejectsZero() public {
        bytes memory data = abi.encodeCall(IMultisigWallet.changeThreshold, (0));
        bytes memory signatures = _packedCurrentThresholdSignaturesForTransaction(wallet, address(wallet), 0, data);

        VM.expectRevert(abi.encodeWithSelector(IMultisigWallet.MultisigWalletInvalidThreshold.selector, 0, 3));
        wallet.executeTransaction(address(wallet), 0, data, signatures);
    }

    function testChangeThresholdRejectsAboveOwnerCount() public {
        bytes memory data = abi.encodeCall(IMultisigWallet.changeThreshold, (4));
        bytes memory signatures = _packedCurrentThresholdSignaturesForTransaction(wallet, address(wallet), 0, data);

        VM.expectRevert(abi.encodeWithSelector(IMultisigWallet.MultisigWalletInvalidThreshold.selector, 4, 3));
        wallet.executeTransaction(address(wallet), 0, data, signatures);
    }

    function testBatchChangeThresholdAndRemoveOwnerWorks() public {
        IMultisigWallet threeOfThreeWallet = _deployInitializedWallet(
            keccak256("auralis.multisig.three-of-three"), _initialOwners(), 3, defaultMultiSend
        );

        bytes memory transactions = bytes.concat(
            _encodeBatchEntry(address(threeOfThreeWallet), 0, abi.encodeCall(IMultisigWallet.changeThreshold, (2))),
            _encodeBatchEntry(
                address(threeOfThreeWallet), 0, abi.encodeCall(IMultisigWallet.removeOwner, (actorAddresses[0]))
            )
        );

        _executeSelfBatch(threeOfThreeWallet, transactions);

        assertTrue(threeOfThreeWallet.threshold() == 2, "threshold mismatch");
        assertTrue(threeOfThreeWallet.ownerCount() == 2, "owner count mismatch");
        assertFalse(threeOfThreeWallet.isOwner(actorAddresses[0]), "removed owner should be absent");
        assertTrue(threeOfThreeWallet.nonce() == 1, "batch should consume exactly one nonce");
    }
}
