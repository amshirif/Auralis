// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IERC20Metadata} from "../src/interfaces/IERC20Metadata.sol";
import {IERC4626} from "../src/interfaces/IERC4626.sol";
import {IERC4626VaultControls} from "../src/interfaces/IERC4626VaultControls.sol";
import {IERC4626VaultControlsFacet} from "../src/interfaces/IERC4626VaultControlsFacet.sol";
import {IERC4626VaultFacet} from "../src/interfaces/IERC4626VaultFacet.sol";
import {IERC4626VaultIntegrationFacet} from "../src/interfaces/IERC4626VaultIntegrationFacet.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {LibDiamond} from "../src/diamond/libraries/LibDiamond.sol";
import {LibVaultFacetSelectors} from "../src/vault/libraries/LibVaultFacetSelectors.sol";
import {
    DiamondVaultHostHardeningFixture,
    IFacetVersionMarker
} from "./helpers/DiamondVaultHostHardeningTestHarness.sol";

contract DiamondVaultHostHardeningTest is DiamondVaultHostHardeningFixture {
    function testHostedVaultBootstrapRequiresDiamondOwnerBeforeSharedRbacExists() public {
        _installVaultHostFacets();

        VM.prank(eve);
        VM.expectRevert(abi.encodeWithSelector(LibDiamond.DiamondUnauthorized.selector, eve, admin));
        coreFacetInterface().initializeVault(address(asset), "Vault Share", "vSHARE", eve);

        VM.prank(admin);
        coreFacetInterface().initializeVault(address(asset), "Vault Share", "vSHARE", admin);

        assertTrue(coreFacetInterface().isVaultInitialized(), "vault host should initialize");
        assertTrue(
            controlsFacetInterface().hasRole(controlsFacetInterface().DEFAULT_ADMIN_ROLE(), admin),
            "vault owner should receive admin role"
        );
    }

    function testCoreFacetReplaceRemoveReAddPreservesState() public {
        _installAndSeedVaultHost();
        _injectStrategyProfit(STRATEGY_PROFIT_ASSETS);

        StrategyStateSnapshot memory initialState = _snapshotStrategyState();

        _replaceCoreFacet(address(coreReplacement));
        _addCoreReplacementMarker();

        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultAsyncHostCoreSelectors(), address(coreReplacement));
        assertTrue(
            IDiamondLoupe(address(diamond)).facetAddress(IFacetVersionMarker.facetVersion.selector)
                == address(coreMarker),
            "core marker owner mismatch"
        );
        assertTrue(IFacetVersionMarker(address(diamond)).facetVersion() == 2, "core replacement marker mismatch");
        assertTrue(coreFacetInterface().asset() == address(asset), "core asset mismatch after replace");
        assertTrue(
            keccak256(bytes(IERC20Metadata(address(diamond)).name())) == keccak256(bytes("Vault Share")),
            "core name mismatch after replace"
        );
        assertTrue(
            keccak256(bytes(IERC20Metadata(address(diamond)).symbol())) == keccak256(bytes("vSHARE")),
            "core symbol mismatch after replace"
        );
        assertTrue(coreFacetInterface().balanceOf(bob) == BOB_DEPOSIT, "bob balance mismatch");
        assertTrue(coreFacetInterface().balanceOf(carol) == CAROL_DEPOSIT, "carol balance mismatch");
        assertTrue(coreFacetInterface().allowance(bob, eve) == SHARE_ALLOWANCE, "share allowance mismatch");
        _assertStrategyState(initialState);
        assertTrue(
            IERC165(address(diamond)).supportsInterface(type(IERC4626VaultFacet).interfaceId),
            "core interface missing after replace"
        );

        _removeCoreFacetWithMarker();

        _assertMissingSelector(abi.encodeWithSelector(IERC4626.asset.selector), "core asset selector should be missing");
        _assertMissingSelector(
            abi.encodeWithSelector(IERC20Metadata.name.selector), "core metadata selector should be missing"
        );
        assertTrue(
            !IERC165(address(diamond)).supportsInterface(type(IERC4626VaultFacet).interfaceId),
            "core interface should be absent when selectors removed"
        );
        (,, address feeRecipient) = controlsFacetInterface().feeConfig();
        assertTrue(feeRecipient == feeSink, "controls should still route after core removal");
        assertTrue(
            integrationFacetInterface().oracleAdapter() == address(adapter),
            "integration should still route after core removal"
        );

        _reAddCoreFacetWithMarker(address(coreReplacement));

        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultAsyncHostCoreSelectors(), address(coreReplacement));
        assertTrue(IFacetVersionMarker(address(diamond)).facetVersion() == 2, "core marker mismatch after re-add");
        assertTrue(
            IERC165(address(diamond)).supportsInterface(type(IERC4626VaultFacet).interfaceId),
            "core interface missing after re-add"
        );
        assertTrue(coreFacetInterface().asset() == address(asset), "core asset mismatch after re-add");
        assertTrue(coreFacetInterface().balanceOf(bob) == BOB_DEPOSIT, "bob balance mismatch after re-add");
        assertTrue(coreFacetInterface().balanceOf(carol) == CAROL_DEPOSIT, "carol balance mismatch after re-add");
        assertTrue(coreFacetInterface().allowance(bob, eve) == SHARE_ALLOWANCE, "allowance mismatch after re-add");
        _assertStrategyState(initialState);
    }

    function testControlsFacetReplaceRemoveReAddPreservesControlState() public {
        _installAndSeedVaultHost();
        _pauseVault();

        StrategyStateSnapshot memory initialState = _snapshotStrategyState();

        _replaceControlsFacet(address(controlsReplacement));
        _addControlsReplacementMarker(address(controlsReplacement));

        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultControlsSelectors(), address(controlsReplacement));
        assertTrue(
            IDiamondLoupe(address(diamond)).facetAddress(IERC165.supportsInterface.selector)
                == address(controlsReplacement),
            "supportsInterface owner mismatch after controls replace"
        );
        assertTrue(IFacetVersionMarker(address(diamond)).facetVersion() == 2, "controls replacement marker mismatch");
        _assertControlsState();
        _assertStrategyState(initialState);
        assertTrue(controlsFacetInterface().paused(), "paused state should persist after replace");
        assertFalse(controlsFacetInterface().reentrancyGuardEntered(), "reentrancy should not be entered");

        _removeControlsFacetWithMarker();

        _assertMissingSelector(
            abi.encodeWithSelector(IERC4626VaultControls.feeConfig.selector),
            "controls fee config selector should be missing"
        );
        _assertMissingSelector(
            abi.encodeWithSelector(IERC165.supportsInterface.selector, type(IERC4626VaultFacet).interfaceId),
            "supportsInterface selector should be missing"
        );
        assertTrue(coreFacetInterface().asset() == address(asset), "core should still route after controls removal");
        assertTrue(
            integrationFacetInterface().strategyDebt() == initialState.strategyDebt,
            "integration should still route after controls removal"
        );

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        coreFacetInterface().deposit(1, bob);

        _reAddControlsFacetWithMarker(address(controlsReplacement));

        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultControlsSelectors(), address(controlsReplacement));
        assertTrue(IFacetVersionMarker(address(diamond)).facetVersion() == 2, "controls marker mismatch after re-add");
        _assertControlsState();
        _assertStrategyState(initialState);
        assertTrue(controlsFacetInterface().paused(), "paused state should persist after re-add");
        assertTrue(
            IERC165(address(diamond)).supportsInterface(type(IERC4626VaultFacet).interfaceId),
            "core interface should be reported after controls re-add"
        );
        _unpauseVault();

        _settleAndClaimDeposit(dave, 1);
        assertTrue(coreFacetInterface().balanceOf(dave) == 1, "dave should receive shares after unpause");
    }

    function testIntegrationFacetReplaceRemoveReAddPreservesIntegrationState() public {
        _installAndSeedVaultHost();

        StrategyStateSnapshot memory initialState = _snapshotStrategyState();

        _replaceIntegrationFacet(address(integrationReplacement));
        _addIntegrationReplacementMarker(address(integrationReplacement));

        _assertSelectorsOwnedByFacet(
            LibVaultFacetSelectors.vaultAsyncIntegrationSelectors(), address(integrationReplacement)
        );
        assertTrue(
            IDiamondLoupe(address(diamond)).facetAddress(IFacetVersionMarker.facetVersion.selector)
                == address(integrationReplacement),
            "integration marker owner mismatch"
        );
        assertTrue(IFacetVersionMarker(address(diamond)).facetVersion() == 2, "integration replacement marker mismatch");
        _assertStrategyState(initialState);
        assertTrue(
            IERC165(address(diamond)).supportsInterface(type(IERC4626VaultIntegrationFacet).interfaceId),
            "integration interface missing after replace"
        );

        _removeIntegrationFacetWithMarker();

        _assertMissingSelector(
            abi.encodeWithSelector(IERC4626VaultIntegrationFacet.oracleAdapter.selector),
            "integration oracle selector should be missing"
        );
        assertTrue(coreFacetInterface().asset() == address(asset), "core should still route after integration removal");
        assertTrue(
            controlsFacetInterface().hasRole(controlsFacetInterface().VAULT_MANAGER_ROLE(), eve),
            "controls should still route after integration removal"
        );
        assertTrue(
            !IERC165(address(diamond)).supportsInterface(type(IERC4626VaultIntegrationFacet).interfaceId),
            "integration interface should be absent when selectors removed"
        );

        uint256 expectedBobSharesBurned = coreFacetInterface().previewWithdraw(BOB_AUTO_PULL_WITHDRAW_ASSETS);
        VM.prank(bob);
        uint256 burnedShares = coreFacetInterface().withdraw(BOB_AUTO_PULL_WITHDRAW_ASSETS, bob, bob);
        assertTrue(
            burnedShares == expectedBobSharesBurned, "withdraw should use previewWithdraw semantics while removed"
        );

        uint256 expectedCarolAssetsReturned = coreFacetInterface().previewRedeem(CAROL_AUTO_PULL_REDEEM_SHARES);
        VM.prank(carol);
        uint256 returnedAssets = coreFacetInterface().redeem(CAROL_AUTO_PULL_REDEEM_SHARES, carol, carol);
        assertTrue(
            returnedAssets == expectedCarolAssetsReturned, "redeem should use previewRedeem semantics while removed"
        );

        uint256 expectedIdleAssets = asset.balanceOf(address(diamond));
        uint256 expectedLiveStrategyAssets = strategyContract.totalAssets();
        uint256 expectedTotalManagedAssets = coreFacetInterface().totalManagedAssets();
        uint256 expectedTotalAssets = coreFacetInterface().totalAssets();
        uint256 expectedBobBalance = coreFacetInterface().balanceOf(bob);
        uint256 expectedCarolBalance = coreFacetInterface().balanceOf(carol);

        _reAddIntegrationFacetWithMarker(address(integrationReplacement));

        _assertSelectorsOwnedByFacet(
            LibVaultFacetSelectors.vaultAsyncIntegrationSelectors(), address(integrationReplacement)
        );
        assertTrue(
            IFacetVersionMarker(address(diamond)).facetVersion() == 2, "integration marker mismatch after re-add"
        );
        assertTrue(
            IERC165(address(diamond)).supportsInterface(type(IERC4626VaultIntegrationFacet).interfaceId),
            "integration interface missing after re-add"
        );
        assertTrue(
            integrationFacetInterface().strategy() == address(strategyContract), "strategy mismatch after re-add"
        );
        assertTrue(
            integrationFacetInterface().strategyDebt() == expectedTotalManagedAssets - expectedIdleAssets,
            "strategy debt mismatch after re-add"
        );
        assertTrue(
            integrationFacetInterface().liveStrategyAssets() == expectedLiveStrategyAssets,
            "live strategy assets mismatch after re-add"
        );
        assertTrue(integrationFacetInterface().idleAssets() == expectedIdleAssets, "idle assets mismatch after re-add");
        assertFalse(integrationFacetInterface().strategyEmergencyExit(), "emergency exit should stay inactive");
        assertTrue(
            coreFacetInterface().totalManagedAssets() == expectedTotalManagedAssets, "book value mismatch after re-add"
        );
        assertTrue(coreFacetInterface().totalAssets() == expectedTotalAssets, "total assets mismatch after re-add");
        assertTrue(coreFacetInterface().balanceOf(bob) == expectedBobBalance, "bob balance mismatch after re-add");
        assertTrue(coreFacetInterface().balanceOf(carol) == expectedCarolBalance, "carol balance mismatch after re-add");
    }

    function testIntegrationEmergencyExitStatePersistsAcrossFacetChurn() public {
        _installAndSeedVaultHost();

        VM.prank(admin);
        uint256 emergencyAssets = integrationFacetInterface().emergencyExitStrategy();
        assertTrue(emergencyAssets == STRATEGY_DEPLOYED_ASSETS, "emergency exit should unwind deployed assets");

        _replaceIntegrationFacet(address(integrationReplacement));
        _addIntegrationReplacementMarker(address(integrationReplacement));
        _removeIntegrationFacetWithMarker();
        _reAddIntegrationFacetWithMarker(address(integrationReplacement));

        assertTrue(
            IFacetVersionMarker(address(diamond)).facetVersion() == 2,
            "integration marker mismatch after emergency re-add"
        );
        assertTrue(integrationFacetInterface().strategy() == address(strategyContract), "strategy mismatch after churn");
        assertTrue(integrationFacetInterface().strategyEmergencyExit(), "emergency exit should persist after churn");
        assertTrue(integrationFacetInterface().strategyDebt() == 0, "strategy debt should remain zero after churn");
        assertTrue(integrationFacetInterface().liveStrategyAssets() == 0, "live strategy assets should remain zero");
        assertTrue(integrationFacetInterface().idleAssets() == BOB_DEPOSIT + CAROL_DEPOSIT, "idle assets mismatch");

        VM.expectRevert(IERC4626VaultIntegrationFacet.ERC4626VaultStrategyEmergencyExitActive.selector);
        VM.prank(admin);
        integrationFacetInterface().deployToStrategy(1);

        VM.prank(admin);
        integrationFacetInterface().setStrategy(address(0));
        VM.prank(admin);
        integrationFacetInterface().setStrategy(address(strategyContract));

        assertFalse(integrationFacetInterface().strategyEmergencyExit(), "emergency exit should clear on rebind");

        VM.prank(admin);
        integrationFacetInterface().deployToStrategy(1);
        assertTrue(integrationFacetInterface().strategyDebt() == 1, "deploy should work after strategy rebind");
    }

    function testFullAsyncHostedVaultTracksInterleavedPendingAndClaimableRequestAccounting() public {
        _installAndSeedFullyAsyncVaultHost();

        _requestDeposit(dave, 40_000);
        _requestDeposit(eve, 30_000);
        _requestRedeem(bob, 60_000);
        _requestRedeem(carol, 50_000);

        _settleDepositRequest(dave, 15_000);
        _settleDepositRequest(eve, 10_000);
        _settleRedeemRequest(bob, 25_000);
        _settleRedeemRequest(carol, 20_000);

        assertTrue(_pendingDepositRequestAssets(dave) == 25_000, "dave pending deposit mismatch");
        assertTrue(_claimableDepositRequestAssets(dave) == 15_000, "dave claimable deposit mismatch");
        assertTrue(_pendingDepositRequestAssets(eve) == 20_000, "eve pending deposit mismatch");
        assertTrue(_claimableDepositRequestAssets(eve) == 10_000, "eve claimable deposit mismatch");
        assertTrue(_pendingRedeemRequestShares(bob) == 35_000, "bob pending redeem mismatch");
        assertTrue(_claimableRedeemRequestShares(bob) == 25_000, "bob claimable redeem mismatch");
        assertTrue(_pendingRedeemRequestShares(carol) == 30_000, "carol pending redeem mismatch");
        assertTrue(_claimableRedeemRequestShares(carol) == 20_000, "carol claimable redeem mismatch");

        assertTrue(_sumPendingDepositRequestAssets() == 45_000, "pending deposit total mismatch");
        assertTrue(_sumClaimableDepositRequestAssets() == 25_000, "claimable deposit total mismatch");
        assertTrue(_sumPendingRedeemRequestShares() == 65_000, "pending redeem total mismatch");
        assertTrue(_sumClaimableRedeemRequestShares() == 45_000, "claimable redeem total mismatch");
        assertTrue(coreFacetInterface().balanceOf(address(diamond)) == 110_000, "escrowed share total mismatch");

        uint256 claimedDepositShares = _claimDeposit(dave, 10_000, dave);
        uint256 claimedRedeemAssets = _claimRedeem(bob, 10_000, bob);

        assertTrue(claimedDepositShares == 9_900, "claimed deposit shares mismatch");
        assertTrue(claimedRedeemAssets == 9_950, "claimed redeem assets mismatch");

        assertTrue(_pendingDepositRequestAssets(dave) == 25_000, "dave pending deposit should remain");
        assertTrue(_claimableDepositRequestAssets(dave) == 5_000, "dave remaining claimable deposit mismatch");
        assertTrue(_pendingDepositRequestAssets(eve) == 20_000, "eve pending deposit should remain");
        assertTrue(_claimableDepositRequestAssets(eve) == 10_000, "eve claimable deposit should remain");
        assertTrue(_pendingRedeemRequestShares(bob) == 35_000, "bob pending redeem should remain");
        assertTrue(_claimableRedeemRequestShares(bob) == 15_000, "bob remaining claimable redeem mismatch");
        assertTrue(_pendingRedeemRequestShares(carol) == 30_000, "carol pending redeem should remain");
        assertTrue(_claimableRedeemRequestShares(carol) == 20_000, "carol claimable redeem should remain");

        assertTrue(_sumPendingDepositRequestAssets() == 45_000, "pending deposit total should remain");
        assertTrue(_sumClaimableDepositRequestAssets() == 15_000, "claimable deposit total mismatch after claim");
        assertTrue(_sumPendingRedeemRequestShares() == 65_000, "pending redeem total should remain");
        assertTrue(_sumClaimableRedeemRequestShares() == 35_000, "claimable redeem total mismatch after claim");
        assertTrue(
            coreFacetInterface().balanceOf(address(diamond)) == 100_000,
            "escrowed shares should match remaining requests"
        );
        assertTrue(
            asset.balanceOf(address(diamond))
                == _bookIdleAssets() + _sumPendingDepositRequestAssets() + _sumClaimableDepositRequestAssets(),
            "vault raw balance should equal book idle plus remaining deposit requests"
        );
    }

    function testFullAsyncRedeemClaimsPreservePendingDepositLiquidityAccounting() public {
        _installAndSeedFullyAsyncVaultHost();

        _requestDeposit(dave, 40_000);

        uint256 deployableIdle = _availableIdleAssetsForStrategyDeploy();
        assertTrue(deployableIdle == 125_000, "deployable idle mismatch");
        assertTrue(
            asset.balanceOf(address(diamond)) == deployableIdle + 40_000, "pending deposit should sit in raw idle"
        );

        VM.expectRevert(
            abi.encodeWithSelector(
                IERC4626VaultIntegrationFacet.ERC4626VaultStrategyInsufficientIdleAssets.selector,
                deployableIdle + 1,
                deployableIdle
            )
        );
        VM.prank(admin);
        integrationFacetInterface().deployToStrategy(deployableIdle + 1);

        _requestRedeem(bob, 180_000);
        _settleRedeemRequest(bob, 180_000);

        uint256 bobAssetsBefore = asset.balanceOf(bob);
        uint256 redeemedAssets = _claimRedeem(bob, 180_000, bob);

        assertTrue(redeemedAssets == 179_100, "redeemed assets mismatch");
        assertTrue(asset.balanceOf(bob) == bobAssetsBefore + redeemedAssets, "bob asset balance mismatch");
        assertTrue(integrationFacetInterface().strategyDebt() == 170_000, "strategy debt mismatch after redeem");
        assertTrue(coreFacetInterface().totalManagedAssets() == 170_000, "managed assets mismatch after redeem");
        assertTrue(_bookIdleAssets() == 0, "book idle should stay zero after redeem");
        assertTrue(_pendingDepositRequestAssets(dave) == 40_000, "pending deposit should remain reserved");
        assertTrue(_claimableDepositRequestAssets(dave) == 0, "claimable deposit should stay zero before settlement");
        assertTrue(asset.balanceOf(address(diamond)) == 40_000, "pending deposit liquidity should remain in the vault");

        _settleDepositRequest(dave, 40_000);
        uint256 claimedDepositShares = _claimDeposit(dave, 40_000, dave);

        assertTrue(claimedDepositShares == 39_600, "claimed deposit shares mismatch");
        assertTrue(_pendingDepositRequestAssets(dave) == 0, "pending deposit should clear after settlement");
        assertTrue(_claimableDepositRequestAssets(dave) == 0, "claimable deposit should clear after claim");
        assertTrue(integrationFacetInterface().strategyDebt() == 170_000, "strategy debt should stay reconciled");
        assertTrue(coreFacetInterface().totalManagedAssets() == 209_600, "managed assets mismatch after deposit claim");
        assertTrue(_bookIdleAssets() == 39_600, "book idle should match post-claim managed idle");
        assertTrue(asset.balanceOf(address(diamond)) == 39_600, "vault balance should match post-claim book idle");
    }

    function _assertSelectorsOwnedByFacet(bytes4[] memory selectors, address expectedFacet) internal view {
        for (uint256 i = 0; i < selectors.length; i++) {
            assertTrue(
                IDiamondLoupe(address(diamond)).facetAddress(selectors[i]) == expectedFacet, "selector owner mismatch"
            );
        }
    }

    function _assertControlsState() internal view {
        bytes32 managerRole = controlsFacetInterface().VAULT_MANAGER_ROLE();
        (uint16 depositFeeBps, uint16 withdrawFeeBps, address feeRecipient) = controlsFacetInterface().feeConfig();
        (uint128 maxTotalAssets, uint128 maxDeposit, uint128 maxMint, uint128 maxWithdraw, uint128 maxRedeem) =
            controlsFacetInterface().limitConfig();
        (uint64 start, uint64 end, bool exists) = controlsFacetInterface().getRoleWindow(managerRole, dave);

        assertTrue(depositFeeBps == 100, "deposit fee mismatch");
        assertTrue(withdrawFeeBps == 50, "withdraw fee mismatch");
        assertTrue(feeRecipient == feeSink, "fee recipient mismatch");
        assertTrue(maxTotalAssets == 900_000, "max total assets mismatch");
        assertTrue(maxDeposit == 300_000, "max deposit mismatch");
        assertTrue(maxMint == 300_000, "max mint mismatch");
        assertTrue(maxWithdraw == 250_000, "max withdraw mismatch");
        assertTrue(maxRedeem == 250_000, "max redeem mismatch");
        assertTrue(controlsFacetInterface().hasRole(managerRole, eve), "eve manager role mismatch");
        assertTrue(start == uint64(currentTime - 100), "role window start mismatch");
        assertTrue(end == uint64(currentTime + 1_000), "role window end mismatch");
        assertTrue(exists, "role window should exist");
        assertTrue(controlsFacetInterface().hasActiveRole(managerRole, dave), "dave active manager role mismatch");
    }
}
