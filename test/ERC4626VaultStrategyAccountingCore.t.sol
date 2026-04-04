// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626VaultControls} from "../src/interfaces/IERC4626VaultControls.sol";
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

    function testDirectStrategyProfitMakesPricingMarkToMarketAndExtendsLiquidity() public {
        _initializeDirectVault();
        _approveAsset(bob, address(facet), DEPOSIT_ASSETS);

        VM.prank(bob);
        facet.deposit(DEPOSIT_ASSETS, bob);

        facet.setStrategyStateForTest(address(directProfitStrategy), STRATEGY_DEBT);
        _simulateStrategyDeployment(address(facet), directProfitStrategy, STRATEGY_DEBT);
        directProfitStrategy.injectProfit(20);

        assertTrue(facet.totalManagedAssets() == DEPOSIT_ASSETS, "book value should remain unchanged");
        assertTrue(facet.totalAssets() == 120, "mark-to-market assets mismatch");
        assertTrue(facet.convertToShares(12) == 10, "convertToShares profit mismatch");
        assertTrue(facet.convertToAssets(10) == 12, "convertToAssets profit mismatch");
        assertTrue(facet.previewDeposit(12) == 10, "previewDeposit profit mismatch");
        assertTrue(facet.previewMint(10) == 12, "previewMint profit mismatch");
        assertTrue(facet.previewWithdraw(12) == 10, "previewWithdraw profit mismatch");
        assertTrue(facet.previewRedeem(10) == 12, "previewRedeem profit mismatch");
        assertTrue(facet.maxWithdraw(bob) == 120, "maxWithdraw should include strategy liquidity");
        assertTrue(facet.maxRedeem(bob) == 100, "maxRedeem should include strategy liquidity");
    }

    function testDirectStrategyLossMovesPricingDownwardAndCapsLiquidityByWithdrawableAssets() public {
        _initializeDirectVault();
        _approveAsset(bob, address(facet), DEPOSIT_ASSETS);

        VM.prank(bob);
        facet.deposit(DEPOSIT_ASSETS, bob);

        facet.setStrategyStateForTest(address(directLossStrategy), STRATEGY_DEBT);
        _simulateStrategyDeployment(address(facet), directLossStrategy, STRATEGY_DEBT);
        directLossStrategy.applyLoss(30, 10);

        assertTrue(facet.totalManagedAssets() == DEPOSIT_ASSETS, "book value should remain unchanged");
        assertTrue(facet.totalAssets() == 70, "loss should reduce mark-to-market assets");
        assertTrue(facet.convertToShares(12) == 17, "convertToShares loss mismatch");
        assertTrue(facet.convertToAssets(10) == 7, "convertToAssets loss mismatch");
        assertTrue(facet.previewDeposit(12) == 17, "previewDeposit loss mismatch");
        assertTrue(facet.previewMint(10) == 7, "previewMint loss mismatch");
        assertTrue(facet.previewWithdraw(12) == 18, "previewWithdraw loss mismatch");
        assertTrue(facet.previewRedeem(10) == 7, "previewRedeem loss mismatch");
        assertTrue(facet.maxWithdraw(bob) == 50, "maxWithdraw should cap to idle plus withdrawable strategy assets");
        assertTrue(facet.maxRedeem(bob) == 71, "maxRedeem should cap to immediate liquidity");
    }

    function testDirectWithdrawAutoPullsFromStrategyLiquidity() public {
        _initializeDirectVault();
        _approveAsset(bob, address(facet), DEPOSIT_ASSETS);

        VM.prank(bob);
        facet.deposit(DEPOSIT_ASSETS, bob);

        facet.setStrategyStateForTest(address(directProfitStrategy), STRATEGY_DEBT);
        _simulateStrategyDeployment(address(facet), directProfitStrategy, STRATEGY_DEBT);

        VM.prank(bob);
        uint256 burnedShares = facet.withdraw(80, bob, bob);

        assertTrue(burnedShares == 80, "withdraw should burn shares at current price");
        assertTrue(facet.balanceOf(bob) == 20, "remaining shares mismatch");
        assertTrue(facet.totalManagedAssets() == 20, "book value mismatch after withdraw");
        assertTrue(facet.totalAssets() == 20, "total assets mismatch after withdraw");
        assertTrue(facet.maxWithdraw(bob) == 20, "remaining withdraw capacity mismatch");
        assertTrue(facet.maxRedeem(bob) == 20, "remaining redeem capacity mismatch");
        assertTrue(asset.balanceOf(address(facet)) == 0, "vault idle balance should be exhausted");
        assertTrue(directProfitStrategy.totalAssets() == 20, "strategy live assets mismatch");
        assertTrue(asset.balanceOf(bob) == INITIAL_ASSETS - 20, "underlying balance mismatch after withdraw");
    }

    function testDirectRedeemAutoPullsAndReturnsCurrentShareValue() public {
        _initializeDirectVault();
        _approveAsset(bob, address(facet), DEPOSIT_ASSETS);

        VM.prank(bob);
        facet.deposit(DEPOSIT_ASSETS, bob);

        facet.setStrategyStateForTest(address(directProfitStrategy), STRATEGY_DEBT);
        _simulateStrategyDeployment(address(facet), directProfitStrategy, STRATEGY_DEBT);
        directProfitStrategy.injectProfit(20);

        VM.prank(bob);
        uint256 returnedAssets = facet.redeem(50, bob, bob);

        assertTrue(returnedAssets == 60, "redeem should return current share value");
        assertTrue(facet.balanceOf(bob) == 50, "remaining shares mismatch after redeem");
        assertTrue(facet.totalManagedAssets() == 60, "book value mismatch after redeem");
        assertTrue(facet.totalAssets() == 60, "total assets mismatch after redeem");
        assertTrue(asset.balanceOf(address(facet)) == 0, "vault idle balance should be exhausted after redeem");
        assertTrue(directProfitStrategy.totalAssets() == 60, "remaining strategy assets mismatch");
        assertTrue(asset.balanceOf(bob) == INITIAL_ASSETS - 40, "underlying balance mismatch after redeem");
    }

    function testDirectWithdrawRevertsWhenStrategyLiquidityCannotCoverExactAssets() public {
        _initializeDirectVault();
        _approveAsset(bob, address(facet), DEPOSIT_ASSETS);

        VM.prank(bob);
        facet.deposit(DEPOSIT_ASSETS, bob);

        facet.setStrategyStateForTest(address(directLossStrategy), STRATEGY_DEBT);
        _simulateStrategyDeployment(address(facet), directLossStrategy, STRATEGY_DEBT);
        directLossStrategy.applyLoss(20, 10);

        VM.expectRevert(
            abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultWithdrawLimitExceeded.selector, 70, 50)
        );
        VM.prank(bob);
        facet.withdraw(70, bob, bob);
    }

    function testDiamondHostedVaultStrategyAccountingUsesRealLifecycleAndAutoPull() public {
        _installHostedVaultFacetsToDiamond();
        _initializeDiamondVault();
        _approveAsset(bob, address(diamond), DEPOSIT_ASSETS);

        VM.prank(bob);
        IERC4626VaultFacet(address(diamond)).deposit(DEPOSIT_ASSETS, bob);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setStrategy(address(diamondProfitStrategy));
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).deployToStrategy(60);
        diamondProfitStrategy.injectProfit(20);

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
            IERC4626VaultFacet(address(diamond)).maxWithdraw(bob) == 120,
            "maxWithdraw should include strategy liquidity"
        );
        assertTrue(
            IERC4626VaultFacet(address(diamond)).maxRedeem(bob) == 100, "maxRedeem should include strategy liquidity"
        );

        VM.prank(bob);
        uint256 burnedShares = IERC4626VaultFacet(address(diamond)).withdraw(80, bob, bob);

        assertTrue(burnedShares == 67, "diamond withdraw should burn shares at updated price");
        assertTrue(IERC4626VaultIntegrationFacet(address(diamond)).idleAssets() == 0, "idle assets should be zero");
        assertTrue(IERC4626VaultIntegrationFacet(address(diamond)).strategyDebt() == 40, "strategy debt mismatch");
        assertTrue(
            IERC4626VaultIntegrationFacet(address(diamond)).liveStrategyAssets() == 40, "live strategy assets mismatch"
        );
        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 40, "managed assets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == 40, "post-withdraw totalAssets mismatch");
    }
}
