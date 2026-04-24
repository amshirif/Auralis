// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626} from "../src/interfaces/IERC4626.sol";
import {IERC7540Deposit} from "../src/interfaces/IERC7540Deposit.sol";
import {IERC7540Redeem} from "../src/interfaces/IERC7540Redeem.sol";
import {IERC7540VaultSettlementFacet} from "../src/interfaces/IERC7540VaultSettlementFacet.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {IERC4626VaultControlsFacet} from "../src/interfaces/IERC4626VaultControlsFacet.sol";
import {ERC4626VaultFacetFixture} from "./helpers/ERC4626VaultFacetTestHarness.sol";

contract ERC7540VaultRequestTimeTest is ERC4626VaultFacetFixture {
    function setUp() public override {
        super.setUp();
        _installHostedVaultFullyAsyncFacetsToDiamond();

        VM.prank(admin);
        _initializeHostedVault(address(diamond));
    }

    function testElapsedTimeAloneDoesNotSettleDepositRequests() public {
        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        IERC7540Deposit(address(diamond)).requestDeposit(60, bob, bob);

        VM.warp(block.timestamp + 30 days);

        assertTrue(IERC7540Deposit(address(diamond)).pendingDepositRequest(0, bob) == 60, "pending should remain");
        assertTrue(IERC7540Deposit(address(diamond)).claimableDepositRequest(0, bob) == 0, "claimable should stay zero");
        assertTrue(IERC7540Deposit(address(diamond)).pendingDepositRequest(1, bob) == 0, "nonzero id should be zero");
        assertTrue(IERC7540Deposit(address(diamond)).claimableDepositRequest(1, bob) == 0, "nonzero id should be zero");
    }

    function testElapsedTimeAloneDoesNotSettleRedeemRequests() public {
        _seedClaimedShares(bob, 80);

        VM.prank(bob);
        IERC7540Redeem(address(diamond)).requestRedeem(50, bob, bob);

        VM.warp(block.timestamp + 30 days);

        assertTrue(IERC7540Redeem(address(diamond)).pendingRedeemRequest(0, bob) == 50, "pending should remain");
        assertTrue(IERC7540Redeem(address(diamond)).claimableRedeemRequest(0, bob) == 0, "claimable should stay zero");
        assertTrue(IERC7540Redeem(address(diamond)).pendingRedeemRequest(1, bob) == 0, "nonzero id should be zero");
        assertTrue(IERC7540Redeem(address(diamond)).claimableRedeemRequest(1, bob) == 0, "nonzero id should be zero");
    }

    function testOnlyManagerSettlementMovesDepositPendingToClaimableAcrossWarps() public {
        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        IERC7540Deposit(address(diamond)).requestDeposit(60, bob, bob);

        VM.warp(block.timestamp + 7 days);

        VM.prank(admin);
        IERC7540VaultSettlementFacet(address(diamond)).settleDepositRequest(bob, 25);

        assertTrue(IERC7540Deposit(address(diamond)).pendingDepositRequest(0, bob) == 35, "pending mismatch");
        assertTrue(IERC7540Deposit(address(diamond)).claimableDepositRequest(0, bob) == 25, "claimable mismatch");
    }

    function testOnlyManagerSettlementMovesRedeemPendingToClaimableAcrossWarps() public {
        _seedClaimedShares(bob, 80);

        VM.prank(bob);
        IERC7540Redeem(address(diamond)).requestRedeem(50, bob, bob);

        VM.warp(block.timestamp + 7 days);

        VM.prank(admin);
        IERC7540VaultSettlementFacet(address(diamond)).settleRedeemRequest(bob, 25);

        assertTrue(IERC7540Redeem(address(diamond)).pendingRedeemRequest(0, bob) == 25, "pending mismatch");
        assertTrue(IERC7540Redeem(address(diamond)).claimableRedeemRequest(0, bob) == 25, "claimable mismatch");
    }

    function testSettlementPauseBlocksSettlementAcrossWarpsButExistingClaimsRemainClaimable() public {
        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        IERC7540Deposit(address(diamond)).requestDeposit(60, bob, bob);

        VM.prank(admin);
        IERC7540VaultSettlementFacet(address(diamond)).settleDepositRequest(bob, 20);

        bytes32 settlementScope = IERC7540VaultSettlementFacet(address(diamond)).ASYNC_SETTLEMENT_SCOPE();

        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).pauseScope(settlementScope);

        VM.warp(block.timestamp + 14 days);

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, settlementScope));
        IERC7540VaultSettlementFacet(address(diamond)).settleDepositRequest(bob, 10);

        assertTrue(IERC7540Deposit(address(diamond)).claimableDepositRequest(0, bob) == 20, "claimable should remain");

        VM.prank(bob);
        uint256 shares = IERC4626(address(diamond)).deposit(20, bob);

        assertTrue(shares == 20, "claim should still succeed");
        assertTrue(IERC7540Deposit(address(diamond)).claimableDepositRequest(0, bob) == 0, "claimable should clear");
        assertTrue(IERC7540Deposit(address(diamond)).pendingDepositRequest(0, bob) == 40, "pending should remain");
    }

    function testSettlementPauseBlocksRedeemSettlementAcrossWarpsButExistingClaimsRemainClaimable() public {
        _seedClaimedShares(bob, 80);

        VM.prank(bob);
        IERC7540Redeem(address(diamond)).requestRedeem(50, bob, bob);

        VM.prank(admin);
        IERC7540VaultSettlementFacet(address(diamond)).settleRedeemRequest(bob, 20);

        bytes32 settlementScope = IERC7540VaultSettlementFacet(address(diamond)).ASYNC_SETTLEMENT_SCOPE();

        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).pauseScope(settlementScope);

        VM.warp(block.timestamp + 14 days);

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, settlementScope));
        IERC7540VaultSettlementFacet(address(diamond)).settleRedeemRequest(bob, 10);

        assertTrue(IERC7540Redeem(address(diamond)).claimableRedeemRequest(0, bob) == 20, "claimable should remain");

        uint256 bobAssetsBefore = asset.balanceOf(bob);

        VM.prank(bob);
        uint256 assets = IERC4626(address(diamond)).redeem(20, bob, bob);

        assertTrue(assets == 20, "claim should still succeed");
        assertTrue(asset.balanceOf(bob) == bobAssetsBefore + 20, "receiver assets mismatch");
        assertTrue(IERC7540Redeem(address(diamond)).claimableRedeemRequest(0, bob) == 0, "claimable should clear");
        assertTrue(IERC7540Redeem(address(diamond)).pendingRedeemRequest(0, bob) == 30, "pending should remain");
    }

    function _seedClaimedShares(address controller, uint256 assets) internal {
        _approveAsset(controller, address(diamond), assets);

        VM.prank(controller);
        IERC7540Deposit(address(diamond)).requestDeposit(assets, controller, controller);

        VM.prank(admin);
        IERC7540VaultSettlementFacet(address(diamond)).settleDepositRequest(controller, assets);

        VM.prank(controller);
        IERC4626(address(diamond)).deposit(assets, controller);
    }
}
