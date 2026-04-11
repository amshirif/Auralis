// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IMultisigWallet} from "../src/interfaces/IMultisigWallet.sol";
import {MultisigWalletFixture} from "./helpers/MultisigWalletTestHarness.sol";

contract MultisigWalletInvariantTest is MultisigWalletFixture {
    uint256 internal successfulExecutions;

    function setUp() public override {
        super.setUp();
        successfulExecutions = wallet.nonce();
    }

    function targetContracts() external view returns (address[] memory contracts) {
        contracts = new address[](1);
        contracts[0] = address(this);
    }

    function actionAddOwner(uint8 candidateSeed) external {
        address candidate = actorAddresses[uint256(candidateSeed) % actorAddresses.length];
        if (wallet.isOwner(candidate)) {
            return;
        }

        _executeSelfTransaction(wallet, abi.encodeCall(IMultisigWallet.addOwner, (candidate)));
        successfulExecutions++;
    }

    function actionRemoveOwner(uint8 ownerSeed) external {
        address[] memory owners = wallet.getOwners();
        uint256 ownerCount_ = owners.length;
        if (ownerCount_ <= 1 || wallet.threshold() > ownerCount_ - 1) {
            return;
        }

        address owner = owners[uint256(ownerSeed) % ownerCount_];
        _executeSelfTransaction(wallet, abi.encodeCall(IMultisigWallet.removeOwner, (owner)));
        successfulExecutions++;
    }

    function actionReplaceOwner(uint8 ownerSeed, uint8 candidateSeed) external {
        address[] memory owners = wallet.getOwners();
        uint256 ownerCount_ = owners.length;
        if (ownerCount_ == 0) {
            return;
        }

        address oldOwner = owners[uint256(ownerSeed) % ownerCount_];
        address newOwner = actorAddresses[uint256(candidateSeed) % actorAddresses.length];
        if (newOwner == oldOwner || wallet.isOwner(newOwner)) {
            return;
        }

        _executeSelfTransaction(wallet, abi.encodeCall(IMultisigWallet.replaceOwner, (oldOwner, newOwner)));
        successfulExecutions++;
    }

    function actionChangeThreshold(uint8 thresholdSeed) external {
        uint256 ownerCount_ = wallet.ownerCount();
        uint256 newThreshold = (uint256(thresholdSeed) % ownerCount_) + 1;
        if (newThreshold == wallet.threshold()) {
            return;
        }

        _executeSelfTransaction(wallet, abi.encodeCall(IMultisigWallet.changeThreshold, (newThreshold)));
        successfulExecutions++;
    }

    function actionBatchChangeThresholdAndRemoveOwner(uint8 ownerSeed, uint8 thresholdSeed) external {
        address[] memory owners = wallet.getOwners();
        uint256 ownerCount_ = owners.length;
        if (ownerCount_ <= 1) {
            return;
        }

        uint256 newOwnerCount = ownerCount_ - 1;
        uint256 newThreshold = (uint256(thresholdSeed) % newOwnerCount) + 1;
        if (wallet.threshold() <= newOwnerCount && newThreshold == wallet.threshold()) {
            return;
        }

        address owner = owners[uint256(ownerSeed) % ownerCount_];
        bytes memory transactions = bytes.concat(
            _encodeBatchEntry(address(wallet), 0, abi.encodeCall(IMultisigWallet.changeThreshold, (newThreshold))),
            _encodeBatchEntry(address(wallet), 0, abi.encodeCall(IMultisigWallet.removeOwner, (owner)))
        );

        _executeSelfBatch(wallet, transactions);
        successfulExecutions++;
    }

    function actionUnauthorizedMutationAttempt(uint8 methodSeed, uint8 actorSeed) external {
        uint256 beforeThreshold = wallet.threshold();
        uint256 beforeOwnerCount = wallet.ownerCount();
        bool[] memory beforeFlags = new bool[](actorAddresses.length);
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            beforeFlags[i] = wallet.isOwner(actorAddresses[i]);
        }

        uint256 method = uint256(methodSeed) % 4;
        address actor = actorAddresses[uint256(actorSeed) % actorAddresses.length];
        VM.expectRevert(IMultisigWallet.MultisigWalletCallerNotSelf.selector);
        if (method == 0) {
            wallet.addOwner(actor);
        } else if (method == 1) {
            wallet.removeOwner(actor);
        } else if (method == 2) {
            wallet.replaceOwner(actorAddresses[0], actor);
        } else {
            wallet.changeThreshold((uint256(actorSeed) % 6) + 1);
        }

        assertTrue(wallet.threshold() == beforeThreshold, "unauthorized attempt changed threshold");
        assertTrue(wallet.ownerCount() == beforeOwnerCount, "unauthorized attempt changed owner count");
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            assertTrue(wallet.isOwner(actorAddresses[i]) == beforeFlags[i], "unauthorized attempt changed ownership");
        }
    }

    function invariantThresholdWithinOwnerCount() public view {
        uint256 ownerCount_ = wallet.ownerCount();
        uint256 threshold_ = wallet.threshold();

        assertTrue(ownerCount_ >= 1, "owner count must stay positive");
        assertTrue(threshold_ >= 1, "threshold must stay positive");
        assertTrue(threshold_ <= ownerCount_, "threshold must not exceed owner count");
    }

    function invariantOwnersRemainUniqueAndNonZero() public view {
        address[] memory owners = wallet.getOwners();
        for (uint256 i = 0; i < owners.length; i++) {
            assertTrue(owners[i] != address(0), "owner must be nonzero");
            for (uint256 j = i + 1; j < owners.length; j++) {
                assertTrue(owners[i] != owners[j], "owners must remain unique");
            }
        }
    }

    function invariantOwnerViewsRemainConsistent() public view {
        address[] memory owners = wallet.getOwners();
        assertTrue(owners.length == wallet.ownerCount(), "owner count must match owners array");

        uint256 actorOwnerCount;
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            if (wallet.isOwner(actorAddresses[i])) {
                actorOwnerCount++;
            }
        }

        assertTrue(actorOwnerCount == owners.length, "isOwner view must match owner set");
        for (uint256 i = 0; i < owners.length; i++) {
            assertTrue(wallet.isOwner(owners[i]), "owner list entries must report as owners");
        }
    }

    function invariantNonceTracksSuccessfulWalletExecutions() public view {
        assertTrue(wallet.nonce() == successfulExecutions, "nonce must track successful wallet executions");
    }
}
