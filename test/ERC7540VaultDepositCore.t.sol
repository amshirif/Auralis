// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IERC4626} from "../src/interfaces/IERC4626.sol";
import {IERC4626VaultControls} from "../src/interfaces/IERC4626VaultControls.sol";
import {IERC4626VaultControlsFacet} from "../src/interfaces/IERC4626VaultControlsFacet.sol";
import {IERC4626VaultFacet} from "../src/interfaces/IERC4626VaultFacet.sol";
import {IERC7540Deposit} from "../src/interfaces/IERC7540Deposit.sol";
import {IERC7540Operators} from "../src/interfaces/IERC7540Operators.sol";
import {IERC7540VaultSettlementFacet} from "../src/interfaces/IERC7540VaultSettlementFacet.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {ERC7540VaultDepositFacet} from "../src/vault/facets/ERC7540VaultDepositFacet.sol";
import {ERC4626VaultFacetFixture} from "./helpers/ERC4626VaultFacetTestHarness.sol";

contract ERC7540VaultDepositCoreTest is ERC4626VaultFacetFixture {
    function _initializeDiamondAsyncVault() internal {
        _installHostedVaultAsyncDepositFacetsToDiamond();

        VM.prank(admin);
        IERC4626VaultFacet(address(diamond)).initializeVault(address(asset), "Vault Share", "vSHARE", admin);
    }

    function _settleDeposit(address controller, uint256 assets) internal {
        VM.prank(admin);
        IERC7540VaultSettlementFacet(address(diamond)).settleDepositRequest(controller, assets);
    }

    function testRequestDepositLocksAssetsWithoutChangingManagedAssets() public {
        _initializeDiamondAsyncVault();
        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        uint256 requestId = IERC7540Deposit(address(diamond)).requestDeposit(40, bob, bob);

        assertTrue(requestId == 0, "request id mismatch");
        assertTrue(IERC7540Deposit(address(diamond)).pendingDepositRequest(0, bob) == 40, "pending deposit mismatch");
        assertTrue(
            IERC7540Deposit(address(diamond)).claimableDepositRequest(0, bob) == 0, "claimable deposit should stay zero"
        );
        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == 0, "managed assets should stay unchanged");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 0, "book assets should stay unchanged");
        assertTrue(asset.balanceOf(address(diamond)) == 40, "vault balance mismatch");
    }

    function testAsyncDepositPreviewHelpersRevertAndMaxHelpersTrackClaimableAssets() public {
        _initializeDiamondAsyncVault();
        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        IERC7540Deposit(address(diamond)).requestDeposit(40, bob, bob);
        _settleDeposit(bob, 10);
        _settleDeposit(bob, 15);

        VM.expectRevert(
            abi.encodeWithSelector(ERC7540VaultDepositFacet.ERC7540VaultAsyncDepositPreviewUnsupported.selector)
        );
        IERC4626(address(diamond)).previewDeposit(1);

        VM.expectRevert(
            abi.encodeWithSelector(ERC7540VaultDepositFacet.ERC7540VaultAsyncDepositPreviewUnsupported.selector)
        );
        IERC4626(address(diamond)).previewMint(1);

        VM.prank(bob);
        uint256 maxAssets = IERC4626(address(diamond)).maxDeposit(bob);
        VM.prank(bob);
        uint256 maxShares = IERC4626(address(diamond)).maxMint(bob);

        assertTrue(maxAssets == 25, "max deposit should match claimable assets");
        assertTrue(maxShares == 25, "max mint should match current share quote");
    }

    function testAsyncDepositClaimConsumesClaimableAssetsAndMintsShares() public {
        _initializeDiamondAsyncVault();
        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        IERC7540Deposit(address(diamond)).requestDeposit(40, bob, bob);
        _settleDeposit(bob, 40);

        VM.prank(bob);
        uint256 shares = IERC4626(address(diamond)).deposit(25, eve);

        assertTrue(shares == 25, "claimed shares mismatch");
        assertTrue(
            IERC7540Deposit(address(diamond)).claimableDepositRequest(0, bob) == 15, "remaining claimable mismatch"
        );
        assertTrue(
            IERC7540Deposit(address(diamond)).pendingDepositRequest(0, bob) == 0, "pending deposit should be empty"
        );
        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 25, "managed assets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == 25, "total assets mismatch");
        assertTrue(IERC4626(address(diamond)).balanceOf(eve) == 25, "receiver share balance mismatch");
        assertTrue(asset.balanceOf(address(diamond)) == 40, "vault balance should keep locked assets");
    }

    function testOnlyManagerCanSettleAsyncDepositRequests() public {
        _initializeDiamondAsyncVault();
        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        IERC7540Deposit(address(diamond)).requestDeposit(20, bob, bob);

        bytes32 managerRole = IERC4626VaultControls(address(diamond)).VAULT_MANAGER_ROLE();

        VM.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, eve, managerRole));
        VM.prank(eve);
        IERC7540VaultSettlementFacet(address(diamond)).settleDepositRequest(bob, 10);
    }

    function testOperatorCanSubmitRequestForOwnerAndClaimForController() public {
        _initializeDiamondAsyncVault();
        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        bool approved = IERC7540Operators(address(diamond)).setOperator(eve, true);
        assertTrue(approved, "operator approval should succeed");

        VM.prank(eve);
        IERC7540Deposit(address(diamond)).requestDeposit(30, bob, bob);
        _settleDeposit(bob, 30);

        VM.prank(eve);
        uint256 assets = IERC7540Deposit(address(diamond)).mint(10, admin, bob);

        assertTrue(assets == 10, "claimed assets mismatch");
        assertTrue(IERC4626(address(diamond)).balanceOf(admin) == 10, "receiver share balance mismatch");
        assertTrue(
            IERC7540Deposit(address(diamond)).claimableDepositRequest(0, bob) == 20, "remaining claimable mismatch"
        );
        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 10, "managed assets mismatch");
    }

    function testUnauthorizedRequestAndClaimActorsRevert() public {
        _initializeDiamondAsyncVault();
        _approveAsset(bob, address(diamond), 100);

        VM.prank(eve);
        VM.expectRevert(
            abi.encodeWithSelector(ERC7540VaultDepositFacet.ERC7540VaultUnauthorizedOperator.selector, bob, eve)
        );
        IERC7540Deposit(address(diamond)).requestDeposit(10, bob, bob);

        VM.prank(bob);
        IERC7540Deposit(address(diamond)).requestDeposit(10, bob, bob);
        _settleDeposit(bob, 10);

        VM.prank(eve);
        VM.expectRevert(
            abi.encodeWithSelector(ERC7540VaultDepositFacet.ERC7540VaultUnauthorizedOperator.selector, bob, eve)
        );
        IERC7540Deposit(address(diamond)).deposit(10, eve, bob);
    }

    function testControllerOperatorCannotSettleAsyncDepositRequest() public {
        _initializeDiamondAsyncVault();
        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        IERC7540Operators(address(diamond)).setOperator(eve, true);

        VM.prank(eve);
        IERC7540Deposit(address(diamond)).requestDeposit(30, bob, bob);

        bytes32 managerRole = IERC4626VaultControls(address(diamond)).VAULT_MANAGER_ROLE();

        VM.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, eve, managerRole));
        VM.prank(eve);
        IERC7540VaultSettlementFacet(address(diamond)).settleDepositRequest(bob, 10);
    }

    function testDiamondAsyncRequestDepositRespectsRequestLimitConfig() public {
        _initializeDiamondAsyncVault();

        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).setLimitConfig(0, 25, 0, 0, 0);

        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultDepositLimitExceeded.selector, 30, 25));
        IERC7540Deposit(address(diamond)).requestDeposit(30, bob, bob);
    }

    function testDiamondAsyncDepositClaimUsesStandardDepositEntrypoint() public {
        _initializeDiamondAsyncVault();

        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        IERC7540Deposit(address(diamond)).requestDeposit(35, bob, bob);
        _settleDeposit(bob, 35);

        VM.prank(bob);
        uint256 shares = IERC4626(address(diamond)).deposit(20, eve);

        assertTrue(shares == 20, "diamond claimed shares mismatch");
        assertTrue(
            IERC7540Deposit(address(diamond)).claimableDepositRequest(0, bob) == 15, "remaining claimable mismatch"
        );
        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 20, "managed assets mismatch");
        assertTrue(IERC4626(address(diamond)).balanceOf(eve) == 20, "receiver shares mismatch");
    }

    function testSettlementPauseBlocksSettlementButNotExistingDepositClaims() public {
        _initializeDiamondAsyncVault();
        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        IERC7540Deposit(address(diamond)).requestDeposit(40, bob, bob);
        _settleDeposit(bob, 20);

        bytes32 settlementScope = IERC7540VaultSettlementFacet(address(diamond)).ASYNC_SETTLEMENT_SCOPE();

        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).pauseScope(settlementScope);

        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, settlementScope));
        VM.prank(admin);
        IERC7540VaultSettlementFacet(address(diamond)).settleDepositRequest(bob, 10);

        VM.prank(bob);
        uint256 shares = IERC4626(address(diamond)).deposit(20, bob);

        assertTrue(shares == 20, "claim should still succeed while settlement is paused");
        assertTrue(IERC7540Deposit(address(diamond)).claimableDepositRequest(0, bob) == 0, "claimable should clear");
        assertTrue(IERC7540Deposit(address(diamond)).pendingDepositRequest(0, bob) == 20, "pending should remain");
    }
}
