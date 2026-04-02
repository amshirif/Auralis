// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626VaultControls} from "../src/interfaces/IERC4626VaultControls.sol";
import {IERC4626VaultIntegrationFacet} from "../src/interfaces/IERC4626VaultIntegrationFacet.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {DiamondVaultHostHardeningFixture} from "./helpers/DiamondVaultHostHardeningTestHarness.sol";

contract DiamondVaultHostInvariantTest is DiamondVaultHostHardeningFixture {
    uint256 internal constant EXPECTED_INITIAL_ASSET_SUPPLY = INITIAL_ASSETS * ACTOR_COUNT + STRATEGY_PROFIT_RESERVE;

    function setUp() public override {
        super.setUp();
        _installVaultHostFacets();
        _initializeVaultHost();
        _wireOracleAdapter();
        _wireStrategy();

        VM.prank(admin);
        controlsFacetInterface().setFeeConfig(0, 0, feeSink);
    }

    function targetContracts() external view returns (address[] memory contracts) {
        contracts = new address[](1);
        contracts[0] = address(this);
    }

    function actionDeposit(uint8 actorSeed, uint96 assetsRaw) external {
        address actor = _actor(actorSeed);
        uint256 maxAssets = _min(coreFacetInterface().maxDeposit(actor), asset.balanceOf(actor));
        uint256 assets_ = _boundAmount(assetsRaw, maxAssets);
        if (assets_ == 0 || coreFacetInterface().previewDeposit(assets_) == 0) {
            return;
        }

        if (controlsFacetInterface().paused()) {
            VM.startPrank(actor);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
            coreFacetInterface().deposit(assets_, actor);
            VM.stopPrank();
            return;
        }

        VM.prank(actor);
        coreFacetInterface().deposit(assets_, actor);
    }

    function actionMint(uint8 actorSeed, uint96 sharesRaw) external {
        address actor = _actor(actorSeed);
        uint256 feasibleShares = coreFacetInterface().previewDeposit(asset.balanceOf(actor));
        uint256 maxShares = _min(coreFacetInterface().maxMint(actor), feasibleShares);
        uint256 shares = _boundAmount(sharesRaw, maxShares);
        if (shares == 0) {
            return;
        }

        uint256 requiredAssets = coreFacetInterface().previewMint(shares);
        if (requiredAssets == 0 || requiredAssets > asset.balanceOf(actor)) {
            return;
        }

        if (controlsFacetInterface().paused()) {
            VM.startPrank(actor);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
            coreFacetInterface().mint(shares, actor);
            VM.stopPrank();
            return;
        }

        VM.prank(actor);
        coreFacetInterface().mint(shares, actor);
    }

    function actionWithdraw(uint8 actorSeed, uint96 assetsRaw) external {
        address actor = _actor(actorSeed);
        uint256 assets_ = _boundAmount(assetsRaw, coreFacetInterface().maxWithdraw(actor));
        if (assets_ == 0) {
            return;
        }

        if (controlsFacetInterface().paused()) {
            VM.startPrank(actor);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
            coreFacetInterface().withdraw(assets_, actor, actor);
            VM.stopPrank();
            return;
        }

        VM.prank(actor);
        coreFacetInterface().withdraw(assets_, actor, actor);
    }

    function actionRedeem(uint8 actorSeed, uint96 sharesRaw) external {
        address actor = _actor(actorSeed);
        uint256 shares = _boundAmount(sharesRaw, coreFacetInterface().maxRedeem(actor));
        if (shares == 0 || coreFacetInterface().previewRedeem(shares) == 0) {
            return;
        }

        if (controlsFacetInterface().paused()) {
            VM.startPrank(actor);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
            coreFacetInterface().redeem(shares, actor, actor);
            VM.stopPrank();
            return;
        }

        VM.prank(actor);
        coreFacetInterface().redeem(shares, actor, actor);
    }

    function actionApprove(uint8 ownerSeed, uint8 spenderSeed, uint96 sharesRaw) external {
        address owner = _actor(ownerSeed);
        address spender = _actorExcluding(owner, spenderSeed);

        VM.prank(owner);
        coreFacetInterface().approve(spender, uint256(sharesRaw));
    }

    function actionTransfer(uint8 fromSeed, uint8 toSeed, uint96 sharesRaw) external {
        address from = _actor(fromSeed);
        address to = _actorExcluding(from, toSeed);
        uint256 shares = _boundAmount(sharesRaw, coreFacetInterface().balanceOf(from));
        if (shares == 0) {
            return;
        }

        VM.prank(from);
        coreFacetInterface().transfer(to, shares);
    }

    function actionTransferFrom(uint8 spenderSeed, uint8 ownerSeed, uint8 toSeed, uint96 sharesRaw) external {
        address spender = _actor(spenderSeed);
        address owner = _actor(ownerSeed);
        if (spender == owner) {
            return;
        }

        address to = _actorExcluding(owner, toSeed);
        uint256 allowance = coreFacetInterface().allowance(owner, spender);
        uint256 balance = coreFacetInterface().balanceOf(owner);
        uint256 shares = _boundAmount(sharesRaw, allowance < balance ? allowance : balance);
        if (shares == 0) {
            return;
        }

        VM.prank(spender);
        coreFacetInterface().transferFrom(owner, to, shares);
    }

    function actionPauseToggle(bool shouldPause) external {
        bool isPaused = controlsFacetInterface().paused();
        if (shouldPause && !isPaused) {
            _pauseVault();
        } else if (!shouldPause && isPaused) {
            _unpauseVault();
        }
    }

    function actionSetFeeConfig(uint16 depositFeeRaw, uint16 withdrawFeeRaw) external {
        AccountingSnapshot memory snapshot = _snapshotAccounting();
        uint16 depositFeeBps = uint16(uint256(depositFeeRaw) % 2_001);
        uint16 withdrawFeeBps = uint16(uint256(withdrawFeeRaw) % 2_001);

        VM.prank(admin);
        controlsFacetInterface().setFeeConfig(depositFeeBps, withdrawFeeBps, feeSink);

        _assertAccountingUnchanged(snapshot, "fee config updates should not mutate accounting");
    }

    function actionSetLimitConfig(
        uint96 totalCapRaw,
        uint96 depositRaw,
        uint96 mintRaw,
        uint96 withdrawRaw,
        uint96 redeemRaw
    ) external {
        AccountingSnapshot memory snapshot = _snapshotAccounting();

        uint256 currentAssets = coreFacetInterface().totalAssets();
        uint128 maxTotalAssets = totalCapRaw % 4 == 0
            ? 0
            : uint128(currentAssets + (uint256(totalCapRaw) % EXPECTED_INITIAL_ASSET_SUPPLY) + 1);
        uint128 maxDeposit = depositRaw % 4 == 0 ? 0 : uint128((uint256(depositRaw) % INITIAL_ASSETS) + 1);
        uint128 maxMint = mintRaw % 4 == 0 ? 0 : uint128((uint256(mintRaw) % INITIAL_ASSETS) + 1);
        uint128 maxWithdraw = withdrawRaw % 4 == 0 ? 0 : uint128((uint256(withdrawRaw) % INITIAL_ASSETS) + 1);
        uint128 maxRedeem = redeemRaw % 4 == 0 ? 0 : uint128((uint256(redeemRaw) % INITIAL_ASSETS) + 1);

        VM.prank(admin);
        controlsFacetInterface().setLimitConfig(maxTotalAssets, maxDeposit, maxMint, maxWithdraw, maxRedeem);

        _assertAccountingUnchanged(snapshot, "limit config updates should not mutate accounting");
    }

    function actionSetOracleAdapter(bool configured) external {
        AccountingSnapshot memory snapshot = _snapshotAccounting();

        VM.prank(admin);
        integrationFacetInterface().setOracleAdapter(configured ? address(adapter) : address(0));

        _assertAccountingUnchanged(snapshot, "oracle adapter updates should not mutate accounting");
    }

    function actionSetStrategy(bool configured) external {
        if (integrationFacetInterface().strategyDebt() != 0) {
            return;
        }

        AccountingSnapshot memory snapshot = _snapshotAccounting();

        if (!configured && integrationFacetInterface().strategy() != address(0)) {
            VM.prank(admin);
            integrationFacetInterface().setStrategy(address(0));
            _assertAccountingUnchanged(snapshot, "strategy clear should not mutate accounting");
            return;
        }

        if (configured && integrationFacetInterface().strategy() == address(0)) {
            strategyContract.setWithdrawAllReverts(false);
            VM.prank(admin);
            integrationFacetInterface().setStrategy(address(strategyContract));
            _assertAccountingUnchanged(snapshot, "strategy rebind should not mutate accounting");
        }
    }

    function actionDeployToStrategy(uint96 assetsRaw) external {
        if (integrationFacetInterface().strategy() != address(strategyContract)) {
            return;
        }

        uint256 assets_ = _boundAmount(assetsRaw, integrationFacetInterface().idleAssets());
        if (assets_ == 0) {
            return;
        }

        if (integrationFacetInterface().strategyEmergencyExit()) {
            VM.expectRevert(IERC4626VaultIntegrationFacet.ERC4626VaultStrategyEmergencyExitActive.selector);
            VM.prank(admin);
            integrationFacetInterface().deployToStrategy(assets_);
            return;
        }

        VM.prank(admin);
        integrationFacetInterface().deployToStrategy(assets_);
    }

    function actionWithdrawFromStrategy(uint96 assetsRaw) external {
        if (integrationFacetInterface().strategy() != address(strategyContract)) {
            return;
        }

        uint256 strategyDebt = integrationFacetInterface().strategyDebt();
        uint256 assets_ = _boundAmount(assetsRaw, strategyDebt);
        if (assets_ == 0) {
            return;
        }

        VM.prank(admin);
        integrationFacetInterface().withdrawFromStrategy(assets_);
    }

    function actionSyncStrategyAssets() external {
        if (integrationFacetInterface().strategy() != address(strategyContract)) {
            return;
        }

        VM.prank(admin);
        integrationFacetInterface().syncStrategyAssets();
    }

    function actionEmergencyExitStrategy(bool forceFailure) external {
        if (integrationFacetInterface().strategy() != address(strategyContract)) {
            return;
        }

        strategyContract.setWithdrawAllReverts(forceFailure && integrationFacetInterface().strategyDebt() != 0);

        VM.prank(admin);
        integrationFacetInterface().emergencyExitStrategy();
    }

    function actionInjectStrategyProfit(uint96 assetsRaw) external {
        if (integrationFacetInterface().strategy() != address(strategyContract)) {
            return;
        }
        if (integrationFacetInterface().strategyDebt() == 0 || integrationFacetInterface().strategyEmergencyExit()) {
            return;
        }

        uint256 available = _min(asset.balanceOf(profitSource), INITIAL_ASSETS);
        uint256 assets_ = _boundAmount(assetsRaw, available);
        if (assets_ == 0) {
            return;
        }

        strategyContract.injectProfit(assets_);
    }

    function actionApplyStrategyLoss(uint96 lossRaw, uint96 withdrawableRaw) external {
        if (integrationFacetInterface().strategy() != address(strategyContract)) {
            return;
        }
        if (integrationFacetInterface().strategyEmergencyExit()) {
            return;
        }

        uint256 liveAssets = integrationFacetInterface().liveStrategyAssets();
        if (liveAssets == 0) {
            return;
        }

        uint256 lossAssets = _boundAmount(lossRaw, _min(liveAssets, INITIAL_ASSETS));
        uint256 remainingLiveAssets = liveAssets - lossAssets;
        uint256 withdrawableAssets = remainingLiveAssets == 0 ? 0 : uint256(withdrawableRaw) % (remainingLiveAssets + 1);

        strategyContract.applyLoss(lossAssets, withdrawableAssets);
    }

    function actionWithdrawBeyondImmediateLiquidityAttempt(uint8 actorSeed, uint96 extraRaw) external {
        if (controlsFacetInterface().paused()) {
            return;
        }

        address actor = _actor(actorSeed);
        uint256 ownerShares = coreFacetInterface().balanceOf(actor);
        if (ownerShares == 0) {
            return;
        }

        uint256 maxWithdraw = coreFacetInterface().maxWithdraw(actor);
        uint256 grossEntitlement = coreFacetInterface().previewRedeem(ownerShares);
        if (grossEntitlement <= maxWithdraw) {
            return;
        }

        uint256 attemptAssets = maxWithdraw + _boundAmount(extraRaw, grossEntitlement - maxWithdraw);

        VM.startPrank(actor);
        VM.expectRevert(
            abi.encodeWithSelector(
                IERC4626VaultControls.ERC4626VaultWithdrawLimitExceeded.selector, attemptAssets, maxWithdraw
            )
        );
        coreFacetInterface().withdraw(attemptAssets, actor, actor);
        VM.stopPrank();
    }

    function invariantIdleAssetsMatchVaultBalance() public view {
        assertTrue(
            integrationFacetInterface().idleAssets() == asset.balanceOf(address(diamond)),
            "idle assets should match vault-held underlying"
        );
    }

    function invariantBookAccountingMatchesIdlePlusStrategyDebt() public view {
        assertTrue(
            coreFacetInterface().totalManagedAssets()
                == integrationFacetInterface().idleAssets() + integrationFacetInterface().strategyDebt(),
            "book accounting should equal idle assets plus strategy debt"
        );
    }

    function invariantLiveAccountingMatchesIdlePlusStrategyAssets() public view {
        assertTrue(
            coreFacetInterface().totalAssets()
                == integrationFacetInterface().idleAssets() + integrationFacetInterface().liveStrategyAssets(),
            "live accounting should equal idle assets plus live strategy assets"
        );
    }

    function invariantShareSupplyMatchesTrackedActorBalances() public view {
        assertTrue(
            coreFacetInterface().totalSupply() == _sumTrackedShareBalances(),
            "share supply should remain equal to tracked balances"
        );
    }

    function invariantTrackedUnderlyingRemainsConserved() public view {
        assertTrue(
            _sumTrackedUnderlying() == EXPECTED_INITIAL_ASSET_SUPPLY,
            "tracked underlying should remain conserved across actors, vault, fee sink, strategy, and reserves"
        );
    }

    function invariantPausedStateZeroesMutatingMaxFunctions() public view {
        if (!controlsFacetInterface().paused()) {
            return;
        }

        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            address actor = actors[i];
            assertTrue(coreFacetInterface().maxDeposit(actor) == 0, "paused vault should expose zero maxDeposit");
            assertTrue(coreFacetInterface().maxMint(actor) == 0, "paused vault should expose zero maxMint");
            assertTrue(coreFacetInterface().maxWithdraw(actor) == 0, "paused vault should expose zero maxWithdraw");
            assertTrue(coreFacetInterface().maxRedeem(actor) == 0, "paused vault should expose zero maxRedeem");
        }
    }

    function invariantMaxWithdrawBoundedByImmediateLiquidity() public view {
        uint256 immediateLiquidity = _immediateLiquidity();

        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            address actor = actors[i];
            uint256 actorBalance = coreFacetInterface().balanceOf(actor);
            uint256 grossEntitlement = actorBalance == 0 ? 0 : coreFacetInterface().previewRedeem(actorBalance);
            uint256 maxWithdraw = coreFacetInterface().maxWithdraw(actor);

            assertTrue(maxWithdraw <= immediateLiquidity, "maxWithdraw should stay within immediate liquidity");
            assertTrue(maxWithdraw <= grossEntitlement, "maxWithdraw should stay within live-priced entitlement");
        }
    }

    function invariantPreviewRedeemOfMaxRedeemBoundedByImmediateLiquidity() public view {
        uint256 immediateLiquidity = _immediateLiquidity();

        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            address actor = actors[i];
            uint256 maxRedeem = coreFacetInterface().maxRedeem(actor);
            assertTrue(
                coreFacetInterface().previewRedeem(maxRedeem) <= immediateLiquidity,
                "previewRedeem(maxRedeem) should stay within immediate liquidity"
            );
        }
    }

    function _immediateLiquidity() internal view returns (uint256) {
        if (integrationFacetInterface().strategyDebt() == 0) {
            return coreFacetInterface().totalAssets();
        }

        uint256 liquidity = integrationFacetInterface().idleAssets();
        if (integrationFacetInterface().strategy() == address(strategyContract)) {
            liquidity += strategyContract.maxWithdrawableAssets();
        }
        return liquidity;
    }


}
