// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626VaultControlsFacet} from "../src/interfaces/IERC4626VaultControlsFacet.sol";
import {IERC4626VaultFacet} from "../src/interfaces/IERC4626VaultFacet.sol";
import {IERC4626VaultIntegrationFacet} from "../src/interfaces/IERC4626VaultIntegrationFacet.sol";
import {ERC4626VaultStrategyAccountingFixture} from "./helpers/ERC4626VaultStrategyAccountingTestHarness.sol";

contract ERC4626VaultStrategyAccountingCoreTest is ERC4626VaultStrategyAccountingFixture {
    function testDirectHostedVaultWithoutStrategyMatchesBaselineAccounting() public {
        _initializeDirectVault();
        _approveAsset(bob, address(facet), DEPOSIT_ASSETS);

        VM.prank(bob);
        uint256 mintedShares = facet.deposit(DEPOSIT_ASSETS, bob);

        assertTrue(mintedShares == DEPOSIT_ASSETS, "deposit shares mismatch");
        assertTrue(facet.totalManagedAssets() == DEPOSIT_ASSETS, "book value mismatch");
        assertTrue(facet.totalAssets() == DEPOSIT_ASSETS, "total assets mismatch");
        assertTrue(facet.previewDeposit(10) == 10, "previewDeposit baseline mismatch");
        assertTrue(facet.previewMint(10) == 10, "previewMint baseline mismatch");
        assertTrue(facet.previewWithdraw(10) == 10, "previewWithdraw baseline mismatch");
        assertTrue(facet.previewRedeem(10) == 10, "previewRedeem baseline mismatch");
        assertTrue(facet.maxWithdraw(bob) == DEPOSIT_ASSETS, "maxWithdraw baseline mismatch");
        assertTrue(facet.maxRedeem(bob) == DEPOSIT_ASSETS, "maxRedeem baseline mismatch");
    }

    function testDirectStrategyProfitMakesPricingMarkToMarketAndCapsLiquidity() public {
        _initializeDirectVault();
        _approveAsset(bob, address(facet), DEPOSIT_ASSETS);

        VM.prank(bob);
        facet.deposit(DEPOSIT_ASSETS, bob);

        facet.setStrategyStateForTest(address(directProfitStrategy), STRATEGY_DEBT);
        _simulateStrategyDeployment(address(facet), directProfitStrategy, STRATEGY_DEBT);
        directProfitStrategy.injectProfit(20);

        assertTrue(facet.strategyDebtForTest() == STRATEGY_DEBT, "strategy debt mismatch");
        assertTrue(facet.totalManagedAssets() == DEPOSIT_ASSETS, "book value should remain unchanged");
        assertTrue(facet.totalAssets() == 120, "mark-to-market assets mismatch");
        assertTrue(facet.convertToShares(12) == 10, "convertToShares profit mismatch");
        assertTrue(facet.convertToAssets(10) == 12, "convertToAssets profit mismatch");
        assertTrue(facet.previewDeposit(12) == 10, "previewDeposit profit mismatch");
        assertTrue(facet.previewMint(10) == 12, "previewMint profit mismatch");
        assertTrue(facet.previewWithdraw(12) == 10, "previewWithdraw profit mismatch");
        assertTrue(facet.previewRedeem(10) == 12, "previewRedeem profit mismatch");
        assertTrue(facet.maxWithdraw(bob) == 40, "maxWithdraw should cap to idle liquidity");
        assertTrue(facet.maxRedeem(bob) == 33, "maxRedeem should cap to idle liquidity");
    }

    function testDirectStrategyLossMovesPricingDownward() public {
        _initializeDirectVault();
        _approveAsset(bob, address(facet), DEPOSIT_ASSETS);

        VM.prank(bob);
        facet.deposit(DEPOSIT_ASSETS, bob);

        facet.setStrategyStateForTest(address(directLossStrategy), STRATEGY_DEBT);
        _simulateStrategyDeployment(address(facet), directLossStrategy, STRATEGY_DEBT);
        directLossStrategy.applyLoss(30, 30);

        assertTrue(facet.totalManagedAssets() == DEPOSIT_ASSETS, "book value should remain unchanged");
        assertTrue(facet.totalAssets() == 70, "loss should reduce mark-to-market assets");
        assertTrue(facet.convertToShares(12) == 17, "convertToShares loss mismatch");
        assertTrue(facet.convertToAssets(10) == 7, "convertToAssets loss mismatch");
        assertTrue(facet.previewDeposit(12) == 17, "previewDeposit loss mismatch");
        assertTrue(facet.previewMint(10) == 7, "previewMint loss mismatch");
        assertTrue(facet.previewWithdraw(12) == 18, "previewWithdraw loss mismatch");
        assertTrue(facet.previewRedeem(10) == 7, "previewRedeem loss mismatch");
        assertTrue(facet.maxWithdraw(bob) == 40, "maxWithdraw should remain idle-capped");
        assertTrue(facet.maxRedeem(bob) == 57, "maxRedeem loss cap mismatch");
    }

    function testConfiguredStrategyWithZeroDebtKeepsHostedPricingBaseline() public {
        _initializeDirectVault();
        _approveAsset(bob, address(facet), DEPOSIT_ASSETS);

        VM.prank(bob);
        facet.deposit(DEPOSIT_ASSETS, bob);

        facet.setStrategyStateForTest(address(directProfitStrategy), 0);
        directProfitStrategy.injectProfit(20);

        assertTrue(facet.totalManagedAssets() == DEPOSIT_ASSETS, "book value mismatch");
        assertTrue(facet.totalAssets() == DEPOSIT_ASSETS, "zero debt strategy should not affect pricing");
        assertTrue(facet.previewDeposit(10) == 10, "previewDeposit should ignore zero-debt strategy");
        assertTrue(facet.maxWithdraw(bob) == DEPOSIT_ASSETS, "maxWithdraw should ignore zero-debt strategy");
    }

    function testDiamondHostedVaultStrategyAccountingUsesLiveStrategyAssetsAndKeepsAdvisoryReportsSeparate() public {
        _installHostedVaultFacetsToDiamond();
        _initializeDiamondVault();
        _approveAsset(bob, address(diamond), DEPOSIT_ASSETS);

        VM.prank(bob);
        IERC4626VaultFacet(address(diamond)).deposit(DEPOSIT_ASSETS, bob);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setStrategy(address(diamondProfitStrategy));
        _seedDiamondStrategyState(address(diamondProfitStrategy), STRATEGY_DEBT);
        _simulateStrategyDeployment(address(diamond), diamondProfitStrategy, STRATEGY_DEBT);
        diamondProfitStrategy.injectProfit(20);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).reportStrategyAssets(25);
        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).setLimitConfig(125, 0, 0, 0, 0);

        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == DEPOSIT_ASSETS, "book value mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == 120, "diamond totalAssets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).previewDeposit(12) == 10, "diamond previewDeposit mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).previewMint(10) == 12, "diamond previewMint mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).previewWithdraw(12) == 10, "diamond previewWithdraw mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).previewRedeem(10) == 12, "diamond previewRedeem mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).maxDeposit(bob) == 5, "maxDeposit should use live totalAssets");
        assertTrue(IERC4626VaultFacet(address(diamond)).maxMint(bob) == 4, "maxMint should use live totalAssets");
        assertTrue(
            IERC4626VaultFacet(address(diamond)).maxWithdraw(bob) == 40, "maxWithdraw should cap to idle liquidity"
        );
        assertTrue(IERC4626VaultFacet(address(diamond)).maxRedeem(bob) == 33, "maxRedeem should cap to idle liquidity");
        assertTrue(IERC4626VaultIntegrationFacet(address(diamond)).idleAssets() == 40, "idle assets mismatch");
        assertTrue(
            IERC4626VaultIntegrationFacet(address(diamond)).strategyReportedAssets() == 25, "reported assets mismatch"
        );
        assertTrue(
            IERC4626VaultIntegrationFacet(address(diamond)).estimatedTotalManagedAssets() == 65,
            "estimated assets should remain advisory"
        );
    }
}
