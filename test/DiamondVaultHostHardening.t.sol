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
import {LibVaultFacetSelectors} from "../src/vault/libraries/LibVaultFacetSelectors.sol";
import {
    DiamondVaultHostHardeningFixture,
    IFacetVersionMarker
} from "./helpers/DiamondVaultHostHardeningTestHarness.sol";

contract DiamondVaultHostHardeningTest is DiamondVaultHostHardeningFixture {
    function testCoreFacetReplaceRemoveReAddPreservesState() public {
        _installAndSeedVaultHost();
        _injectStrategyProfit(STRATEGY_PROFIT_ASSETS);

        StrategyStateSnapshot memory initialState = _snapshotStrategyState();

        _replaceCoreFacet(address(coreReplacement));
        _addCoreReplacementMarker(address(coreReplacement));

        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultCoreSelectors(), address(coreReplacement));
        assertTrue(
            IDiamondLoupe(address(diamond)).facetAddress(IFacetVersionMarker.facetVersion.selector)
                == address(coreReplacement),
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

        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultCoreSelectors(), address(coreReplacement));
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

        VM.prank(dave);
        coreFacetInterface().deposit(1, dave);
        assertTrue(coreFacetInterface().balanceOf(dave) == 1, "dave should receive shares after unpause");
    }

    function testIntegrationFacetReplaceRemoveReAddPreservesIntegrationState() public {
        _installAndSeedVaultHost();

        StrategyStateSnapshot memory initialState = _snapshotStrategyState();

        _replaceIntegrationFacet(address(integrationReplacement));
        _addIntegrationReplacementMarker(address(integrationReplacement));

        _assertSelectorsOwnedByFacet(
            LibVaultFacetSelectors.vaultIntegrationSelectors(), address(integrationReplacement)
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
            LibVaultFacetSelectors.vaultIntegrationSelectors(), address(integrationReplacement)
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
