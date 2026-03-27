// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626VaultControls} from "../src/interfaces/IERC4626VaultControls.sol";
import {IERC4626VaultIntegrationFacet} from "../src/interfaces/IERC4626VaultIntegrationFacet.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {DiamondVaultHostHardeningFixture} from "./helpers/DiamondVaultHostHardeningTestHarness.sol";

contract DiamondVaultHostInvariantTest is DiamondVaultHostHardeningFixture {
    uint256 internal constant EXPECTED_INITIAL_ASSET_SUPPLY = INITIAL_ASSETS * ACTOR_COUNT;

    function setUp() public override {
        super.setUp();
        _installVaultHostFacets();
        _initializeVaultHost();
        _wireOracleAdapter();

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

        _assertAccountingUnchanged(snapshot, "fee config updates should not mutate core accounting");
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

        _assertAccountingUnchanged(snapshot, "limit config updates should not mutate core accounting");
    }

    function actionSetOracleAdapter(bool configured) external {
        AccountingSnapshot memory snapshot = _snapshotAccounting();

        VM.prank(admin);
        integrationFacetInterface().setOracleAdapter(configured ? address(adapter) : address(0));

        _assertAccountingUnchanged(snapshot, "oracle adapter updates should not mutate core accounting");
    }

    function actionSetStrategy(bool configured) external {
        AccountingSnapshot memory snapshot = _snapshotAccounting();

        VM.prank(admin);
        integrationFacetInterface().setStrategy(configured ? strategyReporter : address(0));

        _assertAccountingUnchanged(snapshot, "strategy updates should not mutate core accounting");
    }

    function actionReportStrategyAssets(uint96 assetsRaw, bool asStrategyReporter) external {
        AccountingSnapshot memory snapshot = _snapshotAccounting();
        uint256 assets_ = uint256(assetsRaw);
        address configuredStrategy = integrationFacetInterface().strategy();
        address caller = asStrategyReporter && configuredStrategy != address(0) ? strategyReporter : admin;

        VM.prank(caller);
        integrationFacetInterface().reportStrategyAssets(assets_);

        _assertAccountingUnchanged(snapshot, "strategy reports should not mutate core accounting");
    }

    function invariantManagedAssetsTrackUnderlyingBalance() public view {
        assertTrue(
            coreFacetInterface().totalAssets() == asset.balanceOf(address(diamond)),
            "managed assets should match vault-held underlying"
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
            "tracked underlying should remain conserved across actors, vault, and fee sink"
        );
    }

    function invariantEstimatedManagedAssetsReflectIdlePlusReported() public view {
        assertTrue(
            integrationFacetInterface().estimatedTotalManagedAssets()
                == integrationFacetInterface().idleAssets() + integrationFacetInterface().strategyReportedAssets(),
            "estimated assets should equal idle plus reported strategy assets"
        );
        assertTrue(
            integrationFacetInterface().estimatedTotalManagedAssets() >= coreFacetInterface().totalManagedAssets(),
            "estimated managed assets should not be less than managed assets"
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
}
