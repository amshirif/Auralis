// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626} from "../src/interfaces/IERC4626.sol";
import {IERC4626VaultBase} from "../src/interfaces/IERC4626VaultBase.sol";
import {IERC4626VaultControls} from "../src/interfaces/IERC4626VaultControls.sol";
import {IERC4626VaultControlsFacet} from "../src/interfaces/IERC4626VaultControlsFacet.sol";
import {IERC4626VaultFacet} from "../src/interfaces/IERC4626VaultFacet.sol";
import {IERC7540Deposit} from "../src/interfaces/IERC7540Deposit.sol";
import {IERC7540Operators} from "../src/interfaces/IERC7540Operators.sol";
import {IERC7540Redeem} from "../src/interfaces/IERC7540Redeem.sol";
import {ERC7540VaultDepositFacetHarness} from "./helpers/ERC7540VaultDepositFacetTestHarness.sol";
import {ERC7540VaultRedeemFacetHarness} from "./helpers/ERC7540VaultRedeemFacetTestHarness.sol";
import {ERC7540VaultRedeemFacet} from "../src/vault/facets/ERC7540VaultRedeemFacet.sol";
import {ERC4626VaultFacetFixture} from "./helpers/ERC4626VaultFacetTestHarness.sol";

contract ERC7540VaultRedeemCoreTest is ERC4626VaultFacetFixture {
    function _initializeDiamondFullAsyncVault() internal {
        _installHostedVaultFullyAsyncFacetsToDiamond();
        _installVaultAsyncDepositTestSelectorToDiamond();
        _installVaultAsyncRedeemTestSelectorToDiamond();

        VM.prank(admin);
        IERC4626VaultFacet(address(diamond)).initializeVault(address(asset), "Vault Share", "vSHARE", admin);
    }

    function _seedClaimedShares(address controller, uint256 assets) internal {
        _approveAsset(controller, address(diamond), assets);

        VM.prank(controller);
        IERC7540Deposit(address(diamond)).requestDeposit(assets, controller, controller);
        ERC7540VaultDepositFacetHarness(address(diamond)).harnessSettleDepositRequest(controller, assets);

        VM.prank(controller);
        IERC4626(address(diamond)).deposit(assets, controller);
    }

    function testRequestRedeemLocksSharesWithoutChangingManagedAssets() public {
        _initializeDiamondFullAsyncVault();
        _seedClaimedShares(bob, 80);

        VM.prank(bob);
        uint256 requestId = IERC7540Redeem(address(diamond)).requestRedeem(30, bob, bob);

        assertTrue(requestId == 0, "request id mismatch");
        assertTrue(IERC7540Redeem(address(diamond)).pendingRedeemRequest(0, bob) == 30, "pending redeem mismatch");
        assertTrue(
            IERC7540Redeem(address(diamond)).claimableRedeemRequest(0, bob) == 0, "claimable redeem should stay zero"
        );
        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == 80, "managed assets should stay unchanged");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 80, "book assets should stay unchanged");
        assertTrue(IERC4626(address(diamond)).balanceOf(bob) == 50, "owner share balance mismatch");
        assertTrue(IERC4626(address(diamond)).balanceOf(address(diamond)) == 30, "vault escrow balance mismatch");
        assertTrue(IERC4626(address(diamond)).totalSupply() == 80, "share supply should stay unchanged");
    }

    function testAsyncRedeemPreviewHelpersRevertAndMaxHelpersTrackClaimableShares() public {
        _initializeDiamondFullAsyncVault();
        _seedClaimedShares(bob, 80);

        VM.prank(bob);
        IERC7540Redeem(address(diamond)).requestRedeem(40, bob, bob);
        ERC7540VaultRedeemFacetHarness(address(diamond)).harnessSettleRedeemRequest(bob, 25);

        VM.expectRevert(
            abi.encodeWithSelector(ERC7540VaultRedeemFacet.ERC7540VaultAsyncRedeemPreviewUnsupported.selector)
        );
        IERC4626(address(diamond)).previewWithdraw(1);

        VM.expectRevert(
            abi.encodeWithSelector(ERC7540VaultRedeemFacet.ERC7540VaultAsyncRedeemPreviewUnsupported.selector)
        );
        IERC4626(address(diamond)).previewRedeem(1);

        uint256 maxAssets = IERC4626(address(diamond)).maxWithdraw(bob);
        uint256 maxShares = IERC4626(address(diamond)).maxRedeem(bob);

        assertTrue(maxAssets == 25, "max withdraw should match claimable assets");
        assertTrue(maxShares == 25, "max redeem should match claimable shares");
    }

    function testAsyncRedeemClaimConsumesEscrowedSharesAndReturnsAssets() public {
        _initializeDiamondFullAsyncVault();
        _seedClaimedShares(bob, 80);

        VM.prank(bob);
        IERC7540Redeem(address(diamond)).requestRedeem(40, bob, bob);
        ERC7540VaultRedeemFacetHarness(address(diamond)).harnessSettleRedeemRequest(bob, 40);

        uint256 eveAssetsBefore = asset.balanceOf(eve);

        VM.prank(bob);
        uint256 assets = IERC4626(address(diamond)).redeem(25, eve, bob);

        assertTrue(assets == 25, "claimed assets mismatch");
        assertTrue(
            IERC7540Redeem(address(diamond)).claimableRedeemRequest(0, bob) == 15, "remaining claimable mismatch"
        );
        assertTrue(IERC7540Redeem(address(diamond)).pendingRedeemRequest(0, bob) == 0, "pending redeem should be empty");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 55, "managed assets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == 55, "total assets mismatch");
        assertTrue(IERC4626(address(diamond)).balanceOf(bob) == 40, "owner balance should stay escrow-adjusted");
        assertTrue(IERC4626(address(diamond)).balanceOf(address(diamond)) == 15, "escrow share balance mismatch");
        assertTrue(IERC4626(address(diamond)).totalSupply() == 55, "share supply mismatch");
        assertTrue(asset.balanceOf(eve) == eveAssetsBefore + 25, "receiver asset balance mismatch");
    }

    function testRequestOwnerCanAssignSeparateControllerAndControllerCanClaim() public {
        _initializeDiamondFullAsyncVault();
        _seedClaimedShares(bob, 30);

        VM.prank(bob);
        IERC7540Redeem(address(diamond)).requestRedeem(10, eve, bob);
        ERC7540VaultRedeemFacetHarness(address(diamond)).harnessSettleRedeemRequest(eve, 10);

        uint256 eveAssetsBefore = asset.balanceOf(eve);

        VM.prank(eve);
        uint256 assets = IERC4626(address(diamond)).redeem(10, eve, eve);

        assertTrue(assets == 10, "controller claim assets mismatch");
        assertTrue(IERC4626(address(diamond)).balanceOf(bob) == 20, "owner share balance mismatch");
        assertTrue(IERC7540Redeem(address(diamond)).claimableRedeemRequest(0, eve) == 0, "claimable should clear");
        assertTrue(asset.balanceOf(eve) == eveAssetsBefore + 10, "controller receiver balance mismatch");
    }

    function testAllowanceHolderCanSubmitRedeemRequestForOwner() public {
        _initializeDiamondFullAsyncVault();
        _seedClaimedShares(bob, 20);

        VM.prank(bob);
        IERC4626VaultFacet(address(diamond)).approve(eve, 10);

        VM.prank(eve);
        IERC7540Redeem(address(diamond)).requestRedeem(10, bob, bob);

        assertTrue(IERC4626(address(diamond)).allowance(bob, eve) == 0, "allowance should be spent");
        assertTrue(IERC4626(address(diamond)).balanceOf(bob) == 10, "owner share balance mismatch");
        assertTrue(IERC4626(address(diamond)).balanceOf(address(diamond)) == 10, "vault escrow balance mismatch");
        assertTrue(IERC7540Redeem(address(diamond)).pendingRedeemRequest(0, bob) == 10, "pending redeem mismatch");
    }

    function testUnauthorizedRequestAndClaimActorsRevert() public {
        _initializeDiamondFullAsyncVault();
        _seedClaimedShares(bob, 30);

        VM.prank(eve);
        VM.expectRevert(
            abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultInsufficientAllowance.selector, bob, eve, 0, 10)
        );
        IERC7540Redeem(address(diamond)).requestRedeem(10, bob, bob);

        VM.prank(bob);
        IERC7540Redeem(address(diamond)).requestRedeem(10, bob, bob);
        ERC7540VaultRedeemFacetHarness(address(diamond)).harnessSettleRedeemRequest(bob, 10);

        VM.prank(eve);
        VM.expectRevert(
            abi.encodeWithSelector(ERC7540VaultRedeemFacet.ERC7540VaultUnauthorizedOperator.selector, bob, eve)
        );
        IERC4626(address(diamond)).redeem(10, eve, bob);
    }

    function testDiamondAsyncRequestRedeemRespectsRequestLimitConfig() public {
        _initializeDiamondFullAsyncVault();
        _seedClaimedShares(bob, 40);

        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).setLimitConfig(0, 0, 0, 0, 25);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultRedeemLimitExceeded.selector, 30, 25));
        IERC7540Redeem(address(diamond)).requestRedeem(30, bob, bob);
    }

    function testDiamondAsyncRedeemClaimUsesStandardWithdrawEntrypoint() public {
        _initializeDiamondFullAsyncVault();
        _seedClaimedShares(bob, 35);

        VM.prank(bob);
        IERC7540Redeem(address(diamond)).requestRedeem(35, bob, bob);
        ERC7540VaultRedeemFacetHarness(address(diamond)).harnessSettleRedeemRequest(bob, 35);

        uint256 eveAssetsBefore = asset.balanceOf(eve);

        VM.prank(bob);
        uint256 shares = IERC4626(address(diamond)).withdraw(20, eve, bob);

        assertTrue(shares == 20, "claimed shares mismatch");
        assertTrue(
            IERC7540Redeem(address(diamond)).claimableRedeemRequest(0, bob) == 15, "remaining claimable mismatch"
        );
        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 15, "managed assets mismatch");
        assertTrue(IERC4626(address(diamond)).balanceOf(address(diamond)) == 15, "remaining escrow mismatch");
        assertTrue(asset.balanceOf(eve) == eveAssetsBefore + 20, "receiver assets mismatch");
    }

    function testControllerOperatorCanClaimRedeemRequest() public {
        _initializeDiamondFullAsyncVault();
        _seedClaimedShares(bob, 25);

        VM.prank(bob);
        IERC7540Redeem(address(diamond)).requestRedeem(10, bob, bob);
        ERC7540VaultRedeemFacetHarness(address(diamond)).harnessSettleRedeemRequest(bob, 10);

        VM.prank(bob);
        bool approved = IERC7540Operators(address(diamond)).setOperator(eve, true);
        assertTrue(approved, "operator approval should succeed");

        uint256 eveAssetsBefore = asset.balanceOf(eve);

        VM.prank(eve);
        uint256 assets = IERC4626(address(diamond)).redeem(10, eve, bob);

        assertTrue(assets == 10, "operator claim assets mismatch");
        assertTrue(asset.balanceOf(eve) == eveAssetsBefore + 10, "operator receiver balance mismatch");
        assertTrue(IERC7540Redeem(address(diamond)).claimableRedeemRequest(0, bob) == 0, "claimable should clear");
    }
}
