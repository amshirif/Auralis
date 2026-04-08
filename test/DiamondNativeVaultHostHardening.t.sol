// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IERC20Metadata} from "../src/interfaces/IERC20Metadata.sol";
import {IERC4626} from "../src/interfaces/IERC4626.sol";
import {IERC4626VaultControls} from "../src/interfaces/IERC4626VaultControls.sol";
import {IERC4626VaultFacet} from "../src/interfaces/IERC4626VaultFacet.sol";
import {IERC4626VaultIntegrationFacet} from "../src/interfaces/IERC4626VaultIntegrationFacet.sol";
import {IERC7535VaultFacet} from "../src/interfaces/IERC7535VaultFacet.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {LibVaultAsset} from "../src/vault/libraries/LibVaultAsset.sol";
import {LibVaultFacetSelectors} from "../src/vault/libraries/LibVaultFacetSelectors.sol";
import {DiamondNativeVaultHostHardeningFixture} from "./helpers/DiamondNativeVaultHostHardeningTestHarness.sol";
import {IFacetVersionMarker} from "./helpers/DiamondVaultHostHardeningTestHarness.sol";

contract DiamondNativeVaultHostHardeningTest is DiamondNativeVaultHostHardeningFixture {
    function testNativeCoreFacetReplaceRemoveReAddPreservesState() public {
        _installAndSeedNativeVaultHost();
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
        assertTrue(coreFacetInterface().asset() == LibVaultAsset.NATIVE_ASSET_SENTINEL, "core asset mismatch");
        assertTrue(
            keccak256(bytes(IERC20Metadata(address(diamond)).name())) == keccak256(bytes("Native Vault Share")),
            "core name mismatch after replace"
        );
        assertTrue(
            keccak256(bytes(IERC20Metadata(address(diamond)).symbol())) == keccak256(bytes("nvSHARE")),
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
        assertTrue(coreFacetInterface().asset() == LibVaultAsset.NATIVE_ASSET_SENTINEL, "core asset mismatch");
        assertTrue(coreFacetInterface().balanceOf(bob) == BOB_DEPOSIT, "bob balance mismatch after re-add");
        assertTrue(coreFacetInterface().balanceOf(carol) == CAROL_DEPOSIT, "carol balance mismatch after re-add");
        assertTrue(coreFacetInterface().allowance(bob, eve) == SHARE_ALLOWANCE, "allowance mismatch after re-add");
        _assertStrategyState(initialState);
    }

    function testNativeFacetReplaceRemoveReAddPreservesState() public {
        _installAndSeedNativeVaultHost();

        StrategyStateSnapshot memory initialState = _snapshotStrategyState();

        _replaceNativeFacet(address(nativeReplacement));
        _addNativeReplacementMarker(address(nativeReplacement));

        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultNativeSelectors(), address(nativeReplacement));
        assertTrue(
            IDiamondLoupe(address(diamond)).facetAddress(IFacetVersionMarker.facetVersion.selector)
                == address(nativeReplacement),
            "native marker owner mismatch"
        );
        assertTrue(IFacetVersionMarker(address(diamond)).facetVersion() == 2, "native replacement marker mismatch");
        _assertStrategyState(initialState);
        assertTrue(
            IERC165(address(diamond)).supportsInterface(type(IERC7535VaultFacet).interfaceId),
            "native interface missing after replace"
        );

        _removeNativeFacetWithMarker();

        _assertMissingSelector(
            abi.encodeWithSelector(IERC7535VaultFacet.depositNative.selector, bob),
            "native deposit selector should be missing"
        );
        assertTrue(coreFacetInterface().asset() == LibVaultAsset.NATIVE_ASSET_SENTINEL, "core should still route");
        assertTrue(
            !IERC165(address(diamond)).supportsInterface(type(IERC7535VaultFacet).interfaceId),
            "native interface should be absent when selectors removed"
        );

        _reAddNativeFacetWithMarker(address(nativeReplacement));

        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultNativeSelectors(), address(nativeReplacement));
        assertTrue(IFacetVersionMarker(address(diamond)).facetVersion() == 2, "native marker mismatch after re-add");
        assertTrue(
            IERC165(address(diamond)).supportsInterface(type(IERC7535VaultFacet).interfaceId),
            "native interface missing after re-add"
        );
        _assertStrategyState(initialState);
    }

    function testNativeControlsFacetReplaceRemoveReAddPreservesControlState() public {
        _installAndSeedNativeVaultHost();
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
        assertTrue(
            coreFacetInterface().asset() == LibVaultAsset.NATIVE_ASSET_SENTINEL,
            "core should still route after controls removal"
        );
        assertTrue(
            integrationFacetInterface().strategyDebt() == initialState.strategyDebt,
            "integration should still route after controls removal"
        );

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        IERC7535VaultFacet(address(diamond)).depositNative{value: 1 ether}(bob);

        _reAddControlsFacetWithMarker(address(controlsReplacement));

        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultControlsSelectors(), address(controlsReplacement));
        assertTrue(IFacetVersionMarker(address(diamond)).facetVersion() == 2, "controls marker mismatch after re-add");
        _assertControlsState();
        _assertStrategyState(initialState);
        assertTrue(controlsFacetInterface().paused(), "paused state should persist after re-add");
        assertTrue(
            IERC165(address(diamond)).supportsInterface(type(IERC7535VaultFacet).interfaceId),
            "native interface should be reported after controls re-add"
        );
        _unpauseVault();

        uint256 expectedShares = coreFacetInterface().previewDeposit(1 ether);
        VM.prank(dave);
        uint256 mintedShares = IERC7535VaultFacet(address(diamond)).depositNative{value: 1 ether}(dave);
        assertTrue(mintedShares == expectedShares, "dave should receive previewed shares after unpause");
    }

    function testNativeIntegrationFacetReplaceRemoveReAddPreservesIntegrationState() public {
        _installAndSeedNativeVaultHost();

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
        assertTrue(
            coreFacetInterface().asset() == LibVaultAsset.NATIVE_ASSET_SENTINEL,
            "core should still route after integration removal"
        );
        assertTrue(
            controlsFacetInterface().hasRole(controlsFacetInterface().VAULT_MANAGER_ROLE(), eve),
            "controls should still route after integration removal"
        );
        assertTrue(
            !IERC165(address(diamond)).supportsInterface(type(IERC4626VaultIntegrationFacet).interfaceId),
            "integration interface should be absent when selectors removed"
        );

        uint256 expectedBobSharesBurned = coreFacetInterface().previewWithdraw(BOB_AUTO_PULL_WITHDRAW_ASSETS);
        uint256 bobBalanceBefore = bob.balance;
        VM.prank(bob);
        uint256 burnedShares = coreFacetInterface().withdraw(BOB_AUTO_PULL_WITHDRAW_ASSETS, bob, bob);
        assertTrue(
            burnedShares == expectedBobSharesBurned, "withdraw should use previewWithdraw semantics while removed"
        );
        assertTrue(bob.balance == bobBalanceBefore + BOB_AUTO_PULL_WITHDRAW_ASSETS, "bob native payout mismatch");

        uint256 expectedCarolAssetsReturned = coreFacetInterface().previewRedeem(CAROL_AUTO_PULL_REDEEM_SHARES);
        uint256 carolBalanceBefore = carol.balance;
        VM.prank(carol);
        uint256 returnedAssets = coreFacetInterface().redeem(CAROL_AUTO_PULL_REDEEM_SHARES, carol, carol);
        assertTrue(
            returnedAssets == expectedCarolAssetsReturned, "redeem should use previewRedeem semantics while removed"
        );
        assertTrue(carol.balance == carolBalanceBefore + expectedCarolAssetsReturned, "carol native payout mismatch");

        uint256 expectedIdleAssets = address(diamond).balance;
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

    function testNativeIntegrationEmergencyExitStatePersistsAcrossFacetChurnAndRebind() public {
        _installAndSeedNativeVaultHost();

        VM.prank(admin);
        uint256 emergencyAssets = integrationFacetInterface().emergencyExitStrategy();
        assertTrue(emergencyAssets == STRATEGY_DEPLOYED_ASSETS, "emergency exit should unwind deployed assets");

        _replaceIntegrationFacet(address(integrationReplacement));
        _addIntegrationReplacementMarker(address(integrationReplacement));
        _replaceNativeFacet(address(nativeReplacement));
        _removeIntegrationFacetWithMarker();
        _removeSelectors(LibVaultFacetSelectors.vaultNativeSelectors());
        _reAddIntegrationFacetWithMarker(address(integrationReplacement));
        _addFacet(address(nativeReplacement), LibVaultFacetSelectors.vaultNativeSelectors());

        assertTrue(
            IFacetVersionMarker(address(diamond)).facetVersion() == 2,
            "replacement marker mismatch after emergency re-add"
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
        integrationFacetInterface().setStrategy(address(replacementStrategyContract));

        assertFalse(integrationFacetInterface().strategyEmergencyExit(), "emergency exit should clear on rebind");

        VM.prank(admin);
        integrationFacetInterface().deployToStrategy(1 ether);
        assertTrue(integrationFacetInterface().strategyDebt() == 1 ether, "deploy should work after strategy rebind");
        assertTrue(
            integrationFacetInterface().strategy() == address(replacementStrategyContract),
            "replacement strategy should bind"
        );
    }

    function testForceSentNativeAssetsDoNotChangeAccountingOrMaxFunctions() public {
        _installAndSeedNativeVaultHost();
        _injectStrategyProfit(STRATEGY_PROFIT_ASSETS);

        StrategyStateSnapshot memory beforeState = _snapshotStrategyState();
        uint256 expectedVaultBalance = address(diamond).balance + 3 ether;
        uint256 expectedStrategyBalance = address(strategyContract).balance + 2 ether;

        _forceSendToVault(3 ether);
        _forceSendToStrategy(2 ether);

        assertTrue(address(diamond).balance == expectedVaultBalance, "vault force-send balance mismatch");
        assertTrue(address(strategyContract).balance == expectedStrategyBalance, "strategy force-send balance mismatch");
        assertTrue(coreFacetInterface().totalManagedAssets() == beforeState.totalManagedAssets, "book assets changed");
        assertTrue(coreFacetInterface().totalAssets() == beforeState.totalAssets, "pricing assets changed");
        assertTrue(coreFacetInterface().maxWithdraw(bob) == beforeState.bobMaxWithdraw, "maxWithdraw changed");
        assertTrue(coreFacetInterface().maxRedeem(bob) == beforeState.bobMaxRedeem, "maxRedeem changed");
        assertTrue(
            integrationFacetInterface().liveStrategyAssets() == beforeState.liveStrategyAssets, "live assets changed"
        );
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
        assertTrue(maxTotalAssets == 90 ether, "max total assets mismatch");
        assertTrue(maxDeposit == 30 ether, "max deposit mismatch");
        assertTrue(maxMint == 30 ether, "max mint mismatch");
        assertTrue(maxWithdraw == 25 ether, "max withdraw mismatch");
        assertTrue(maxRedeem == 25 ether, "max redeem mismatch");
        assertTrue(controlsFacetInterface().hasRole(managerRole, eve), "eve manager role mismatch");
        assertTrue(start == uint64(currentTime - 100), "role window start mismatch");
        assertTrue(end == uint64(currentTime + 1_000), "role window end mismatch");
        assertTrue(exists, "role window should exist");
        assertTrue(controlsFacetInterface().hasActiveRole(managerRole, dave), "dave active manager role mismatch");
    }
}
