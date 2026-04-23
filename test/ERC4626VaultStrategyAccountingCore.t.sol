// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626VaultControls} from "../src/interfaces/IERC4626VaultControls.sol";
import {IERC4626VaultControlsFacet} from "../src/interfaces/IERC4626VaultControlsFacet.sol";
import {IERC4626VaultFacet} from "../src/interfaces/IERC4626VaultFacet.sol";
import {IERC4626VaultIntegrationFacet} from "../src/interfaces/IERC4626VaultIntegrationFacet.sol";
import {IERC7535VaultFacet} from "../src/interfaces/IERC7535VaultFacet.sol";
import {ERC4626Vault} from "../src/vault/ERC4626Vault.sol";
import {MockVaultStrategyForcedRevert} from "./helpers/ERC4626VaultStrategyTestHarness.sol";
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

        _setDirectStrategy(directProfitStrategy, STRATEGY_DEBT);
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

        _setDirectStrategy(directLossStrategy, STRATEGY_DEBT);
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

        _setDirectStrategy(directProfitStrategy, STRATEGY_DEBT);

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

        _setDirectStrategy(directProfitStrategy, STRATEGY_DEBT);
        directProfitStrategy.injectProfit(20);

        uint256 expectedAssets = facet.previewRedeem(50);

        VM.prank(bob);
        uint256 returnedAssets = facet.redeem(50, bob, bob);

        assertTrue(expectedAssets == 60, "profit fixture should expose non-1:1 redeem pricing");
        assertTrue(returnedAssets == expectedAssets, "redeem should match no-loss pre-call quote");
        assertTrue(returnedAssets == 60, "redeem should return current share value");
        assertTrue(facet.balanceOf(bob) == 50, "remaining shares mismatch after redeem");
        assertTrue(facet.totalManagedAssets() == 60, "book value mismatch after redeem");
        assertTrue(facet.totalAssets() == 60, "total assets mismatch after redeem");
        assertTrue(asset.balanceOf(address(facet)) == 0, "vault idle balance should be exhausted after redeem");
        assertTrue(directProfitStrategy.totalAssets() == 60, "remaining strategy assets mismatch");
        assertTrue(asset.balanceOf(bob) == INITIAL_ASSETS - 40, "underlying balance mismatch after redeem");
    }

    function testDirectRedeemRepricesAfterWithdrawalTimeLoss() public {
        _initializeDirectVault();
        _approveAsset(bob, address(facet), DEPOSIT_ASSETS);

        VM.prank(bob);
        facet.deposit(DEPOSIT_ASSETS, bob);

        _setDirectStrategy(directLossOnWithdrawStrategy, STRATEGY_DEBT);
        directLossOnWithdrawStrategy.setLossOnNextWithdraw(20);

        VM.prank(bob);
        uint256 returnedAssets = facet.redeem(50, bob, bob);

        assertTrue(returnedAssets == 40, "redeem should settle at post-loss share value");
        assertTrue(facet.balanceOf(bob) == 50, "remaining shares mismatch");
        assertTrue(facet.totalManagedAssets() == 40, "managed assets should reflect loss and exit");
        assertTrue(facet.totalAssets() == 40, "total assets mismatch after post-loss redeem");
        assertTrue(asset.balanceOf(bob) == INITIAL_ASSETS - 60, "receiver assets mismatch");
    }

    function testDirectWithdrawBurnsPostSourcingSharesAfterWithdrawalTimeLoss() public {
        _initializeDirectVault();
        _approveAsset(bob, address(facet), DEPOSIT_ASSETS);

        VM.prank(bob);
        facet.deposit(DEPOSIT_ASSETS, bob);

        _setDirectStrategy(directLossOnWithdrawStrategy, STRATEGY_DEBT);
        directLossOnWithdrawStrategy.setLossOnNextWithdraw(20);

        VM.prank(bob);
        uint256 burnedShares = facet.withdraw(50, bob, bob);

        assertTrue(burnedShares == 63, "withdraw should burn post-loss priced shares");
        assertTrue(burnedShares > 50, "withdraw should burn more than stale pre-loss pricing");
        assertTrue(facet.balanceOf(bob) == 37, "remaining shares mismatch");
        assertTrue(facet.totalManagedAssets() == 30, "managed assets should reflect loss and exit");
        assertTrue(facet.totalAssets() == 30, "total assets mismatch after post-loss withdraw");
        assertTrue(asset.balanceOf(bob) == INITIAL_ASSETS - 50, "receiver assets mismatch");
    }

    function testDirectRedeemSucceedsWhenWithdrawalTimeLossMakesInitialGrossAssetsStale() public {
        _initializeDirectVault();
        _approveAsset(bob, address(facet), DEPOSIT_ASSETS);

        VM.prank(bob);
        facet.deposit(DEPOSIT_ASSETS, bob);

        _setDirectStrategy(directLossOnWithdrawStrategy, STRATEGY_DEBT);
        directLossOnWithdrawStrategy.setLossOnNextWithdraw(55);

        VM.prank(bob);
        uint256 returnedAssets = facet.redeem(50, bob, bob);

        assertTrue(returnedAssets == 22, "redeem should recompute below stale gross assets");
        assertTrue(facet.balanceOf(bob) == 50, "remaining shares mismatch");
        assertTrue(facet.totalManagedAssets() == 23, "managed assets should preserve remaining post-loss value");
        assertTrue(facet.totalAssets() == 23, "total assets mismatch after partial-liquidity redeem");
        assertTrue(asset.balanceOf(address(facet)) == 23, "idle assets mismatch");
    }

    function testDirectWithdrawRevertsWhenStrategyLiquidityCannotCoverExactAssets() public {
        _initializeDirectVault();
        _approveAsset(bob, address(facet), DEPOSIT_ASSETS);

        VM.prank(bob);
        facet.deposit(DEPOSIT_ASSETS, bob);

        _setDirectStrategy(directLossStrategy, STRATEGY_DEBT);
        directLossStrategy.applyLoss(20, 10);

        VM.expectRevert(
            abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultWithdrawLimitExceeded.selector, 70, 50)
        );
        VM.prank(bob);
        facet.withdraw(70, bob, bob);
    }

    function testDirectRevertingStrategyMakesLiveSyncPricingReadsRevert() public {
        _initializeDirectVault();
        _approveAsset(bob, address(facet), DEPOSIT_ASSETS);

        VM.prank(bob);
        facet.deposit(DEPOSIT_ASSETS, bob);

        _setDirectStrategy(directRevertingStrategy, STRATEGY_DEBT);
        directRevertingStrategy.setRevertModes(true, false, false, false);

        VM.expectRevert(
            abi.encodeWithSelector(MockVaultStrategyForcedRevert.selector, directRevertingStrategy.totalAssets.selector)
        );
        facet.totalAssets();

        VM.expectRevert(
            abi.encodeWithSelector(MockVaultStrategyForcedRevert.selector, directRevertingStrategy.totalAssets.selector)
        );
        facet.previewDeposit(10);

        VM.expectRevert(
            abi.encodeWithSelector(MockVaultStrategyForcedRevert.selector, directRevertingStrategy.totalAssets.selector)
        );
        facet.previewMint(10);

        VM.expectRevert(
            abi.encodeWithSelector(MockVaultStrategyForcedRevert.selector, directRevertingStrategy.totalAssets.selector)
        );
        facet.previewWithdraw(10);

        VM.expectRevert(
            abi.encodeWithSelector(MockVaultStrategyForcedRevert.selector, directRevertingStrategy.totalAssets.selector)
        );
        facet.previewRedeem(10);

        VM.expectRevert(
            abi.encodeWithSelector(MockVaultStrategyForcedRevert.selector, directRevertingStrategy.totalAssets.selector)
        );
        facet.maxWithdraw(bob);

        VM.expectRevert(
            abi.encodeWithSelector(MockVaultStrategyForcedRevert.selector, directRevertingStrategy.totalAssets.selector)
        );
        facet.maxRedeem(bob);
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

    function testDiamondRedeemRepricesAfterWithdrawalTimeLoss() public {
        _installHostedVaultFacetsToDiamond();
        _initializeDiamondVault();
        _approveAsset(bob, address(diamond), DEPOSIT_ASSETS);

        VM.prank(bob);
        IERC4626VaultFacet(address(diamond)).deposit(DEPOSIT_ASSETS, bob);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setStrategy(address(diamondLossOnWithdrawStrategy));
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).deployToStrategy(STRATEGY_DEBT);
        diamondLossOnWithdrawStrategy.setLossOnNextWithdraw(20);

        VM.prank(bob);
        uint256 returnedAssets = IERC4626VaultFacet(address(diamond)).redeem(50, bob, bob);

        assertTrue(returnedAssets == 40, "diamond redeem should settle at post-loss share value");
        assertTrue(IERC4626VaultFacet(address(diamond)).balanceOf(bob) == 50, "remaining shares mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 40, "managed assets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == 40, "total assets mismatch");
        assertTrue(asset.balanceOf(bob) == INITIAL_ASSETS - 60, "receiver assets mismatch");
    }

    function testDiamondHostedRevertingStrategyMakesLiveSyncPricingReadsRevert() public {
        _installHostedVaultFacetsToDiamond();
        _initializeDiamondVault();
        _approveAsset(bob, address(diamond), DEPOSIT_ASSETS);

        VM.prank(bob);
        IERC4626VaultFacet(address(diamond)).deposit(DEPOSIT_ASSETS, bob);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setStrategy(address(diamondRevertingStrategy));
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).deployToStrategy(STRATEGY_DEBT);
        diamondRevertingStrategy.setRevertModes(true, false, false, false);

        VM.expectRevert(
            abi.encodeWithSelector(
                MockVaultStrategyForcedRevert.selector, diamondRevertingStrategy.totalAssets.selector
            )
        );
        IERC4626VaultFacet(address(diamond)).totalAssets();

        VM.expectRevert(
            abi.encodeWithSelector(
                MockVaultStrategyForcedRevert.selector, diamondRevertingStrategy.totalAssets.selector
            )
        );
        IERC4626VaultFacet(address(diamond)).previewDeposit(10);

        VM.expectRevert(
            abi.encodeWithSelector(
                MockVaultStrategyForcedRevert.selector, diamondRevertingStrategy.totalAssets.selector
            )
        );
        IERC4626VaultFacet(address(diamond)).previewMint(10);

        VM.expectRevert(
            abi.encodeWithSelector(
                MockVaultStrategyForcedRevert.selector, diamondRevertingStrategy.totalAssets.selector
            )
        );
        IERC4626VaultFacet(address(diamond)).previewWithdraw(10);

        VM.expectRevert(
            abi.encodeWithSelector(
                MockVaultStrategyForcedRevert.selector, diamondRevertingStrategy.totalAssets.selector
            )
        );
        IERC4626VaultFacet(address(diamond)).previewRedeem(10);

        VM.expectRevert(
            abi.encodeWithSelector(
                MockVaultStrategyForcedRevert.selector, diamondRevertingStrategy.totalAssets.selector
            )
        );
        IERC4626VaultFacet(address(diamond)).maxWithdraw(bob);

        VM.expectRevert(
            abi.encodeWithSelector(
                MockVaultStrategyForcedRevert.selector, diamondRevertingStrategy.totalAssets.selector
            )
        );
        IERC4626VaultFacet(address(diamond)).maxRedeem(bob);
    }

    function testDiamondHostedConfiguredRevertingStrategyWithZeroDebtKeepsBookPricingAvailable() public {
        _installHostedVaultFacetsToDiamond();
        _initializeDiamondVault();
        _approveAsset(bob, address(diamond), DEPOSIT_ASSETS);

        VM.prank(bob);
        IERC4626VaultFacet(address(diamond)).deposit(DEPOSIT_ASSETS, bob);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setStrategy(address(diamondRevertingStrategy));
        diamondRevertingStrategy.setRevertModes(true, false, false, false);

        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == DEPOSIT_ASSETS, "book pricing mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).previewDeposit(10) == 10, "previewDeposit mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).previewMint(10) == 10, "previewMint mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).previewWithdraw(10) == 10, "previewWithdraw mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).previewRedeem(10) == 10, "previewRedeem mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).maxWithdraw(bob) == DEPOSIT_ASSETS, "maxWithdraw mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).maxRedeem(bob) == DEPOSIT_ASSETS, "maxRedeem mismatch");
    }

    function testDiamondNativeHostedVaultStrategyAccountingUsesRealLifecycleAndAutoPull() public {
        _installHostedVaultNativeFacetsToDiamond();
        _initializeDiamondNativeVault();
        VM.deal(bob, INITIAL_ASSETS);
        VM.deal(address(this), 20);

        VM.prank(bob);
        IERC7535VaultFacet(address(diamond)).depositNative{value: DEPOSIT_ASSETS}(bob);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setStrategy(address(diamondNativeProfitStrategy));
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).deployToStrategy(60);
        diamondNativeProfitStrategy.injectProfit{value: 20}();

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

        uint256 bobBalanceBeforeWithdraw = bob.balance;
        VM.prank(bob);
        uint256 burnedShares = IERC4626VaultFacet(address(diamond)).withdraw(80, bob, bob);

        assertTrue(burnedShares == 67, "diamond withdraw should burn shares at updated price");
        assertTrue(bob.balance == bobBalanceBeforeWithdraw + 80, "withdraw should pay raw native asset");
        assertTrue(IERC4626VaultIntegrationFacet(address(diamond)).idleAssets() == 0, "idle assets should be zero");
        assertTrue(IERC4626VaultIntegrationFacet(address(diamond)).strategyDebt() == 40, "strategy debt mismatch");
        assertTrue(
            IERC4626VaultIntegrationFacet(address(diamond)).liveStrategyAssets() == 40, "live strategy assets mismatch"
        );
        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 40, "managed assets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == 40, "post-withdraw totalAssets mismatch");
        assertTrue(address(diamond).balance == 0, "vault idle balance should be exhausted");
    }

    function testDiamondNativeDepositUsesLiveStrategyPricingAfterProfit() public {
        _installHostedVaultNativeFacetsToDiamond();
        _initializeDiamondNativeVault();
        VM.deal(bob, INITIAL_ASSETS);
        VM.deal(eve, INITIAL_ASSETS);
        VM.deal(address(this), 20);

        VM.prank(bob);
        IERC7535VaultFacet(address(diamond)).depositNative{value: DEPOSIT_ASSETS}(bob);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setStrategy(address(diamondNativeProfitStrategy));
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).deployToStrategy(60);
        diamondNativeProfitStrategy.injectProfit{value: 20}();

        uint256 depositAssets = 12;
        uint256 expectedShares = IERC4626VaultFacet(address(diamond)).previewDeposit(depositAssets);

        VM.prank(eve);
        uint256 mintedShares = IERC7535VaultFacet(address(diamond)).depositNative{value: depositAssets}(eve);

        assertTrue(expectedShares == 10, "fixture should expose non-1:1 live pricing");
        assertTrue(mintedShares == expectedShares, "native deposit should match live-priced previewDeposit");
    }

    function testDiamondNativeMintUsesLiveStrategyPricingAfterProfit() public {
        _installHostedVaultNativeFacetsToDiamond();
        _initializeDiamondNativeVault();
        VM.deal(bob, INITIAL_ASSETS);
        VM.deal(eve, INITIAL_ASSETS);
        VM.deal(address(this), 20);

        VM.prank(bob);
        IERC7535VaultFacet(address(diamond)).depositNative{value: DEPOSIT_ASSETS}(bob);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setStrategy(address(diamondNativeProfitStrategy));
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).deployToStrategy(60);
        diamondNativeProfitStrategy.injectProfit{value: 20}();

        uint256 mintShares = 10;
        uint256 expectedAssets = IERC4626VaultFacet(address(diamond)).previewMint(mintShares);

        VM.expectRevert(
            abi.encodeWithSelector(
                ERC4626Vault.ERC4626VaultInvalidNativeAssetValue.selector, expectedAssets - 1, expectedAssets
            )
        );
        VM.prank(eve);
        IERC7535VaultFacet(address(diamond)).mintNative{value: expectedAssets - 1}(mintShares, eve);

        VM.prank(eve);
        uint256 consumedAssets = IERC7535VaultFacet(address(diamond)).mintNative{value: expectedAssets}(mintShares, eve);

        assertTrue(expectedAssets == 12, "fixture should expose non-1:1 live pricing");
        assertTrue(consumedAssets == expectedAssets, "native mint should match live-priced previewMint");
    }

    function testDiamondNativeDepositAndMintUseLiveStrategyPricingAfterLoss() public {
        _installHostedVaultNativeFacetsToDiamond();
        _initializeDiamondNativeVault();
        VM.deal(bob, INITIAL_ASSETS);
        VM.deal(eve, INITIAL_ASSETS);

        VM.prank(bob);
        IERC7535VaultFacet(address(diamond)).depositNative{value: DEPOSIT_ASSETS}(bob);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setStrategy(address(diamondNativeLossStrategy));
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).deployToStrategy(60);
        diamondNativeLossStrategy.applyLoss(30, 10);

        uint256 depositAssets = 14;
        uint256 bookOnlyShares = depositAssets;
        uint256 expectedShares = IERC4626VaultFacet(address(diamond)).previewDeposit(depositAssets);

        VM.prank(eve);
        uint256 mintedShares = IERC7535VaultFacet(address(diamond)).depositNative{value: depositAssets}(eve);

        assertTrue(expectedShares > bookOnlyShares, "loss should increase shares per deposited asset");
        assertTrue(mintedShares == expectedShares, "native deposit should match loss-adjusted previewDeposit");

        uint256 mintShares = 10;
        uint256 bookOnlyAssets = mintShares;
        uint256 expectedAssets = IERC4626VaultFacet(address(diamond)).previewMint(mintShares);

        VM.prank(eve);
        uint256 consumedAssets = IERC7535VaultFacet(address(diamond)).mintNative{value: expectedAssets}(mintShares, eve);

        assertTrue(expectedAssets < bookOnlyAssets, "loss should reduce required assets per minted share");
        assertTrue(consumedAssets == expectedAssets, "native mint should match loss-adjusted previewMint");
    }

    function testDiamondNativeDepositAndMintRevertWhenLiveStrategyQuoteReverts() public {
        _installHostedVaultNativeFacetsToDiamond();
        _initializeDiamondNativeVault();
        VM.deal(bob, INITIAL_ASSETS);
        VM.deal(eve, INITIAL_ASSETS);

        VM.prank(bob);
        IERC7535VaultFacet(address(diamond)).depositNative{value: DEPOSIT_ASSETS}(bob);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setStrategy(address(diamondNativeRevertingStrategy));
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).deployToStrategy(STRATEGY_DEBT);
        diamondNativeRevertingStrategy.setRevertModes(true, false, false, false);

        VM.expectRevert(
            abi.encodeWithSelector(
                MockVaultStrategyForcedRevert.selector, diamondNativeRevertingStrategy.totalAssets.selector
            )
        );
        VM.prank(eve);
        IERC7535VaultFacet(address(diamond)).depositNative{value: 10}(eve);

        VM.expectRevert(
            abi.encodeWithSelector(
                MockVaultStrategyForcedRevert.selector, diamondNativeRevertingStrategy.totalAssets.selector
            )
        );
        VM.prank(eve);
        IERC7535VaultFacet(address(diamond)).mintNative{value: 10}(10, eve);
    }

    function testDiamondNativeDepositInternalCapUsesLiveStrategyPricing() public {
        _installHostedVaultNativeFacetsToDiamond();
        _initializeDiamondNativeVault();
        VM.deal(bob, INITIAL_ASSETS);
        VM.deal(eve, INITIAL_ASSETS);
        VM.deal(address(this), 20);

        VM.prank(bob);
        IERC7535VaultFacet(address(diamond)).depositNative{value: DEPOSIT_ASSETS}(bob);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setStrategy(address(diamondNativeProfitStrategy));
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).deployToStrategy(60);
        diamondNativeProfitStrategy.injectProfit{value: 20}();

        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).setLimitConfig(125, 0, 0, 0, 0);

        uint256 livePricedCap = IERC4626VaultFacet(address(diamond)).maxDeposit(eve);
        uint256 amountAboveCap = livePricedCap + 1;

        assertTrue(livePricedCap == 5, "external maxDeposit should use live strategy pricing");

        VM.expectRevert(
            abi.encodeWithSelector(
                IERC4626VaultControls.ERC4626VaultDepositLimitExceeded.selector, amountAboveCap, livePricedCap
            )
        );
        VM.prank(eve);
        IERC7535VaultFacet(address(diamond)).depositNative{value: amountAboveCap}(eve);
    }

    function testDiamondNativeHostedRevertingStrategyMakesLiveSyncPricingReadsRevert() public {
        _installHostedVaultNativeFacetsToDiamond();
        _initializeDiamondNativeVault();
        VM.deal(bob, INITIAL_ASSETS);

        VM.prank(bob);
        IERC7535VaultFacet(address(diamond)).depositNative{value: DEPOSIT_ASSETS}(bob);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setStrategy(address(diamondNativeRevertingStrategy));
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).deployToStrategy(STRATEGY_DEBT);
        diamondNativeRevertingStrategy.setRevertModes(true, false, false, false);

        VM.expectRevert(
            abi.encodeWithSelector(
                MockVaultStrategyForcedRevert.selector, diamondNativeRevertingStrategy.totalAssets.selector
            )
        );
        IERC4626VaultFacet(address(diamond)).totalAssets();

        VM.expectRevert(
            abi.encodeWithSelector(
                MockVaultStrategyForcedRevert.selector, diamondNativeRevertingStrategy.totalAssets.selector
            )
        );
        IERC4626VaultFacet(address(diamond)).previewDeposit(10);

        VM.expectRevert(
            abi.encodeWithSelector(
                MockVaultStrategyForcedRevert.selector, diamondNativeRevertingStrategy.totalAssets.selector
            )
        );
        IERC4626VaultFacet(address(diamond)).previewMint(10);

        VM.expectRevert(
            abi.encodeWithSelector(
                MockVaultStrategyForcedRevert.selector, diamondNativeRevertingStrategy.totalAssets.selector
            )
        );
        IERC4626VaultFacet(address(diamond)).previewWithdraw(10);

        VM.expectRevert(
            abi.encodeWithSelector(
                MockVaultStrategyForcedRevert.selector, diamondNativeRevertingStrategy.totalAssets.selector
            )
        );
        IERC4626VaultFacet(address(diamond)).previewRedeem(10);

        VM.expectRevert(
            abi.encodeWithSelector(
                MockVaultStrategyForcedRevert.selector, diamondNativeRevertingStrategy.totalAssets.selector
            )
        );
        IERC4626VaultFacet(address(diamond)).maxWithdraw(bob);

        VM.expectRevert(
            abi.encodeWithSelector(
                MockVaultStrategyForcedRevert.selector, diamondNativeRevertingStrategy.totalAssets.selector
            )
        );
        IERC4626VaultFacet(address(diamond)).maxRedeem(bob);
    }

    function testDiamondNativeRedeemAutoPullsAndReturnsCurrentShareValue() public {
        _installHostedVaultNativeFacetsToDiamond();
        _initializeDiamondNativeVault();
        VM.deal(bob, INITIAL_ASSETS);
        VM.deal(address(this), 20);

        VM.prank(bob);
        IERC7535VaultFacet(address(diamond)).depositNative{value: DEPOSIT_ASSETS}(bob);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setStrategy(address(diamondNativeProfitStrategy));
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).deployToStrategy(60);
        diamondNativeProfitStrategy.injectProfit{value: 20}();

        uint256 bobBalanceBeforeRedeem = bob.balance;
        VM.prank(bob);
        uint256 returnedAssets = IERC4626VaultFacet(address(diamond)).redeem(50, bob, bob);

        assertTrue(returnedAssets == 60, "redeem should return current share value");
        assertTrue(bob.balance == bobBalanceBeforeRedeem + 60, "redeem should pay raw native asset");
        assertTrue(IERC4626VaultFacet(address(diamond)).balanceOf(bob) == 50, "remaining shares mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 60, "book value mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == 60, "total assets mismatch");
        assertTrue(address(diamond).balance == 0, "vault idle balance should be exhausted after redeem");
        assertTrue(diamondNativeProfitStrategy.totalAssets() == 60, "remaining strategy assets mismatch");
    }

    function testDiamondNativeRedeemRepricesAfterWithdrawalTimeLoss() public {
        _installHostedVaultNativeFacetsToDiamond();
        _initializeDiamondNativeVault();
        VM.deal(bob, INITIAL_ASSETS);

        VM.prank(bob);
        IERC7535VaultFacet(address(diamond)).depositNative{value: DEPOSIT_ASSETS}(bob);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setStrategy(address(diamondNativeLossOnWithdrawStrategy));
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).deployToStrategy(STRATEGY_DEBT);
        diamondNativeLossOnWithdrawStrategy.setLossOnNextWithdraw(20);

        uint256 bobBalanceBefore = bob.balance;
        VM.prank(bob);
        uint256 returnedAssets = IERC4626VaultFacet(address(diamond)).redeem(50, bob, bob);

        assertTrue(returnedAssets == 40, "native redeem should settle at post-loss share value");
        assertTrue(bob.balance == bobBalanceBefore + 40, "native receiver balance mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).balanceOf(bob) == 50, "remaining shares mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 40, "managed assets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == 40, "total assets mismatch");
    }

    function testDiamondNativeWithdrawRevertsWhenStrategyLiquidityCannotCoverExactAssets() public {
        _installHostedVaultNativeFacetsToDiamond();
        _initializeDiamondNativeVault();
        VM.deal(bob, INITIAL_ASSETS);

        VM.prank(bob);
        IERC7535VaultFacet(address(diamond)).depositNative{value: DEPOSIT_ASSETS}(bob);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setStrategy(address(diamondNativeLossStrategy));
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).deployToStrategy(60);
        diamondNativeLossStrategy.applyLoss(20, 10);

        VM.expectRevert(
            abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultWithdrawLimitExceeded.selector, 70, 50)
        );
        VM.prank(bob);
        IERC4626VaultFacet(address(diamond)).withdraw(70, bob, bob);
    }
}
