// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626} from "../src/interfaces/IERC4626.sol";
import {IERC4626VaultControls} from "../src/interfaces/IERC4626VaultControls.sol";
import {IERC4626VaultControlsFacet} from "../src/interfaces/IERC4626VaultControlsFacet.sol";
import {IERC4626VaultFacet} from "../src/interfaces/IERC4626VaultFacet.sol";
import {IERC7540Deposit} from "../src/interfaces/IERC7540Deposit.sol";
import {ERC4626Vault} from "../src/vault/ERC4626Vault.sol";
import {ERC4626VaultFacet} from "../src/vault/facets/ERC4626VaultFacet.sol";
import {
    ERC4626VaultFacetFixture,
    ERC4626VaultFacetHarness
} from "./helpers/ERC4626VaultFacetTestHarness.sol";

contract ERC7540VaultDepositCoreTest is ERC4626VaultFacetFixture {
    function testRequestDepositLocksAssetsWithoutChangingManagedAssets() public {
        _initializeHostedVault(address(facet));
        facet.harnessSetAsyncDepositMode(true);
        _approveAsset(bob, address(facet), 100);

        VM.prank(bob);
        uint256 requestId = facet.requestDeposit(40, bob, bob);

        assertTrue(requestId == 0, "request id mismatch");
        assertTrue(facet.pendingDepositRequest(0, bob) == 40, "pending deposit mismatch");
        assertTrue(facet.claimableDepositRequest(0, bob) == 0, "claimable deposit should stay zero");
        assertTrue(facet.totalAssets() == 0, "managed assets should stay unchanged");
        assertTrue(facet.totalManagedAssets() == 0, "book assets should stay unchanged");
        assertTrue(asset.balanceOf(address(facet)) == 40, "vault balance mismatch");
    }

    function testAsyncDepositPreviewHelpersRevertAndMaxHelpersTrackClaimableAssets() public {
        _initializeHostedVault(address(facet));
        facet.harnessSetAsyncDepositMode(true);
        _approveAsset(bob, address(facet), 100);

        VM.prank(bob);
        facet.requestDeposit(40, bob, bob);
        facet.harnessSettleDepositRequest(bob, 25);

        VM.expectRevert(abi.encodeWithSelector(ERC4626VaultFacet.ERC7540VaultAsyncDepositPreviewUnsupported.selector));
        facet.previewDeposit(1);

        VM.expectRevert(abi.encodeWithSelector(ERC4626VaultFacet.ERC7540VaultAsyncDepositPreviewUnsupported.selector));
        facet.previewMint(1);

        VM.prank(bob);
        uint256 maxAssets = facet.maxDeposit(bob);
        VM.prank(bob);
        uint256 maxShares = facet.maxMint(bob);

        assertTrue(maxAssets == 25, "max deposit should match claimable assets");
        assertTrue(maxShares == 25, "max mint should match current share quote");
    }

    function testAsyncDepositClaimConsumesClaimableAssetsAndMintsShares() public {
        _initializeHostedVault(address(facet));
        facet.harnessSetAsyncDepositMode(true);
        _approveAsset(bob, address(facet), 100);

        VM.prank(bob);
        facet.requestDeposit(40, bob, bob);
        facet.harnessSettleDepositRequest(bob, 40);

        VM.prank(bob);
        uint256 shares = facet.deposit(25, eve);

        assertTrue(shares == 25, "claimed shares mismatch");
        assertTrue(facet.claimableDepositRequest(0, bob) == 15, "remaining claimable mismatch");
        assertTrue(facet.pendingDepositRequest(0, bob) == 0, "pending deposit should be empty");
        assertTrue(facet.totalManagedAssets() == 25, "managed assets mismatch");
        assertTrue(facet.totalAssets() == 25, "total assets mismatch");
        assertTrue(facet.balanceOf(eve) == 25, "receiver share balance mismatch");
        assertTrue(asset.balanceOf(address(facet)) == 40, "vault balance should keep locked assets");
    }

    function testOperatorCanSubmitRequestForOwnerAndClaimForController() public {
        _initializeHostedVault(address(facet));
        facet.harnessSetAsyncDepositMode(true);
        _approveAsset(bob, address(facet), 100);

        VM.prank(bob);
        bool approved = facet.setOperator(eve, true);
        assertTrue(approved, "operator approval should succeed");

        VM.prank(eve);
        facet.requestDeposit(30, bob, bob);
        facet.harnessSettleDepositRequest(bob, 30);

        VM.prank(eve);
        uint256 assets = facet.mint(10, admin, bob);

        assertTrue(assets == 10, "claimed assets mismatch");
        assertTrue(facet.balanceOf(admin) == 10, "receiver share balance mismatch");
        assertTrue(facet.claimableDepositRequest(0, bob) == 20, "remaining claimable mismatch");
        assertTrue(facet.totalManagedAssets() == 10, "managed assets mismatch");
    }

    function testUnauthorizedRequestAndClaimActorsRevert() public {
        _initializeHostedVault(address(facet));
        facet.harnessSetAsyncDepositMode(true);
        _approveAsset(bob, address(facet), 100);

        VM.prank(eve);
        VM.expectRevert(
            abi.encodeWithSelector(ERC4626VaultFacet.ERC7540VaultUnauthorizedOperator.selector, bob, eve)
        );
        facet.requestDeposit(10, bob, bob);

        VM.prank(bob);
        facet.requestDeposit(10, bob, bob);
        facet.harnessSettleDepositRequest(bob, 10);

        VM.prank(eve);
        VM.expectRevert(
            abi.encodeWithSelector(ERC4626VaultFacet.ERC7540VaultUnauthorizedOperator.selector, bob, eve)
        );
        facet.deposit(10, eve, bob);
    }

    function testDiamondAsyncRequestDepositRespectsRequestLimitConfig() public {
        _installHostedVaultAsyncDepositFacetsToDiamond();

        VM.prank(admin);
        IERC4626VaultFacet(address(diamond)).initializeVault(address(asset), "Vault Share", "vSHARE", admin);

        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).setLimitConfig(0, 25, 0, 0, 0);

        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultDepositLimitExceeded.selector, 30, 25)
        );
        IERC7540Deposit(address(diamond)).requestDeposit(30, bob, bob);
    }

    function testDiamondAsyncDepositClaimUsesStandardDepositEntrypoint() public {
        _installHostedVaultAsyncDepositFacetsToDiamond();
        _installVaultAsyncDepositTestSelectorToDiamond();

        VM.prank(admin);
        IERC4626VaultFacet(address(diamond)).initializeVault(address(asset), "Vault Share", "vSHARE", admin);

        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        IERC7540Deposit(address(diamond)).requestDeposit(35, bob, bob);
        ERC4626VaultFacetHarness(address(diamond)).harnessSettleDepositRequest(bob, 35);

        VM.prank(bob);
        uint256 shares = IERC4626(address(diamond)).deposit(20, eve);

        assertTrue(shares == 20, "diamond claimed shares mismatch");
        assertTrue(IERC7540Deposit(address(diamond)).claimableDepositRequest(0, bob) == 15, "remaining claimable mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 20, "managed assets mismatch");
        assertTrue(IERC4626(address(diamond)).balanceOf(eve) == 20, "receiver shares mismatch");
    }
}
