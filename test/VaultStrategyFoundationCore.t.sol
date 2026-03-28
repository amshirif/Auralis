// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626VaultStrategy} from "../src/interfaces/IERC4626VaultStrategy.sol";
import {
    ERC4626VaultStrategyFixture,
    MockVaultStrategyForcedRevert
} from "./helpers/ERC4626VaultStrategyTestHarness.sol";

contract VaultStrategyFoundationCoreTest is ERC4626VaultStrategyFixture {
    function testStorageDefaultsAfterHostedVaultInit() public view {
        assertTrue(storageHarness.strategy() == address(0), "strategy should default to zero");
        assertTrue(storageHarness.strategyReportedAssets() == 0, "reported assets should default to zero");
        assertTrue(storageHarness.strategyDebtForTest() == 0, "strategy debt should default to zero");
        assertFalse(storageHarness.strategyEmergencyExitForTest(), "emergency exit should default to false");
    }

    function testMockStrategiesBindVaultAndAsset() public view {
        _assertBinding(profitStrategy);
        _assertBinding(lossStrategy);
        _assertBinding(revertingStrategy);
        _assertBinding(unwindStrategy);
    }

    function testOnlyVaultCanOperateStrategyLifecycle() public {
        _assertOnlyVault(profitStrategy);
        _assertOnlyVault(lossStrategy);
        _assertOnlyVault(revertingStrategy);
        _assertOnlyVault(unwindStrategy);
    }

    function testProfitMockReportsHigherAssetsAfterProfitInjection() public {
        VM.prank(vault);
        profitStrategy.deployFunds(100);

        profitStrategy.injectProfit(25);

        assertTrue(profitStrategy.totalAssets() == 125, "profit should increase tracked assets");
        assertTrue(profitStrategy.maxWithdrawableAssets() == 125, "profit should increase withdrawable assets");
    }

    function testLossShortfallMockReturnsLessThanRequestedAndShrinksAssets() public {
        VM.prank(vault);
        lossStrategy.deployFunds(100);

        lossStrategy.applyLoss(40, 35);

        assertTrue(lossStrategy.totalAssets() == 60, "loss should reduce tracked assets");
        assertTrue(lossStrategy.maxWithdrawableAssets() == 35, "shortfall should cap withdrawable assets");

        VM.prank(vault);
        uint256 returnedAssets = lossStrategy.withdrawToVault(50);

        assertTrue(returnedAssets == 35, "withdraw should return available assets only");
        assertTrue(lossStrategy.totalAssets() == 25, "tracked assets should reduce by returned amount");
        assertTrue(lossStrategy.maxWithdrawableAssets() == 0, "withdrawable assets should be depleted");
    }

    function testRevertingMockRevertsOnConfiguredCalls() public {
        revertingStrategy.setRevertModes(true, true, true, true);

        VM.expectRevert(
            abi.encodeWithSelector(MockVaultStrategyForcedRevert.selector, revertingStrategy.totalAssets.selector)
        );
        revertingStrategy.totalAssets();

        VM.expectRevert(
            abi.encodeWithSelector(MockVaultStrategyForcedRevert.selector, revertingStrategy.deployFunds.selector)
        );
        VM.prank(vault);
        revertingStrategy.deployFunds(100);

        VM.expectRevert(
            abi.encodeWithSelector(MockVaultStrategyForcedRevert.selector, revertingStrategy.withdrawToVault.selector)
        );
        VM.prank(vault);
        revertingStrategy.withdrawToVault(100);

        VM.expectRevert(
            abi.encodeWithSelector(
                MockVaultStrategyForcedRevert.selector, revertingStrategy.withdrawAllToVault.selector
            )
        );
        VM.prank(vault);
        revertingStrategy.withdrawAllToVault();
    }

    function testEmergencyUnwindMockReturnsAllAssetsAndClearsState() public {
        VM.prank(vault);
        unwindStrategy.deployFunds(100);

        unwindStrategy.setWithdrawableAssets(40);

        VM.prank(vault);
        uint256 returnedAssets = unwindStrategy.withdrawAllToVault();

        assertTrue(returnedAssets == 100, "emergency unwind should return all tracked assets");
        assertTrue(unwindStrategy.totalAssets() == 0, "tracked assets should clear on unwind");
        assertTrue(unwindStrategy.maxWithdrawableAssets() == 0, "withdrawable assets should clear on unwind");
    }

    function _assertBinding(IERC4626VaultStrategy strategy_) internal view {
        assertTrue(strategy_.vault() == vault, "vault binding mismatch");
        assertTrue(strategy_.asset() == address(asset), "asset binding mismatch");
    }

    function _assertOnlyVault(IERC4626VaultStrategy strategy_) internal {
        VM.expectRevert(
            abi.encodeWithSelector(IERC4626VaultStrategy.ERC4626VaultStrategyOnlyVault.selector, outsider, vault)
        );
        VM.prank(outsider);
        strategy_.deployFunds(1);

        VM.expectRevert(
            abi.encodeWithSelector(IERC4626VaultStrategy.ERC4626VaultStrategyOnlyVault.selector, outsider, vault)
        );
        VM.prank(outsider);
        strategy_.withdrawToVault(1);

        VM.expectRevert(
            abi.encodeWithSelector(IERC4626VaultStrategy.ERC4626VaultStrategyOnlyVault.selector, outsider, vault)
        );
        VM.prank(outsider);
        strategy_.withdrawAllToVault();
    }
}
