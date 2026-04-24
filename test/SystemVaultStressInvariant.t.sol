// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IPausable} from "../src/interfaces/IPausable.sol";
import {ERC4626VaultControlsHarness} from "./helpers/ERC4626VaultControlsTestHarness.sol";
import {SystemVaultStressFixture} from "./helpers/SystemVaultStressTestHarness.sol";

contract SystemVaultStressInvariantTest is SystemVaultStressFixture {
    function targetContracts() external view returns (address[] memory contracts) {
        contracts = new address[](1);
        contracts[0] = address(this);
    }

    function actionDeposit(uint8 actorSeed, uint96 assetsRaw) external {
        address actor = _actor(actorSeed);
        uint256 maxAssets = _min(vault.maxDeposit(actor), asset.balanceOf(actor));
        uint256 assets = _boundAmount(assetsRaw, maxAssets);
        if (assets == 0 || vault.previewDeposit(assets) == 0) {
            return;
        }

        VM.prank(actor);
        vault.deposit(assets, actor);

        _assertCoreAccountingAligned();
    }

    function actionMint(uint8 actorSeed, uint96 sharesRaw) external {
        address actor = _actor(actorSeed);
        uint256 feasibleShares = vault.previewDeposit(asset.balanceOf(actor));
        uint256 maxShares = _min(vault.maxMint(actor), feasibleShares);
        uint256 shares = _boundAmount(sharesRaw, maxShares);
        if (shares == 0) {
            return;
        }

        uint256 requiredAssets = vault.previewMint(shares);
        if (requiredAssets == 0 || requiredAssets > asset.balanceOf(actor)) {
            return;
        }

        VM.prank(actor);
        vault.mint(shares, actor);

        _assertCoreAccountingAligned();
    }

    function actionWithdraw(uint8 actorSeed, uint96 assetsRaw) external {
        address actor = _actor(actorSeed);
        uint256 assets = _boundAmount(assetsRaw, vault.maxWithdraw(actor));
        if (assets == 0) {
            return;
        }

        VM.prank(actor);
        vault.withdraw(assets, actor, actor);

        _assertCoreAccountingAligned();
    }

    function actionRedeem(uint8 actorSeed, uint96 sharesRaw) external {
        address actor = _actor(actorSeed);
        uint256 shares = _boundAmount(sharesRaw, vault.maxRedeem(actor));
        if (shares == 0 || vault.previewRedeem(shares) == 0) {
            return;
        }

        VM.prank(actor);
        vault.redeem(shares, actor, actor);

        _assertCoreAccountingAligned();
    }

    function actionPauseToggle(bool shouldPause) external {
        if (shouldPause) {
            _pauseIfNeeded();
        } else {
            _unpauseIfNeeded();
        }

        _assertCoreAccountingAligned();
    }

    function actionSetFeeConfig(uint16 depositFeeRaw, uint16 withdrawFeeRaw) external {
        AccountingSnapshot memory beforeSnapshot = _snapshotAccounting();

        uint16 depositFeeBps = uint16(uint256(depositFeeRaw) % 2_001);
        uint16 withdrawFeeBps = uint16(uint256(withdrawFeeRaw) % 2_001);

        VM.prank(admin);
        vault.setFeeConfig(depositFeeBps, withdrawFeeBps, feeSink);

        _assertAccountingUnchanged(beforeSnapshot, "fee config updates should not mutate accounting state");
        _assertCoreAccountingAligned();
    }

    function actionSetLimitConfig(
        uint96 totalCapRaw,
        uint96 depositRaw,
        uint96 mintRaw,
        uint96 withdrawRaw,
        uint96 redeemRaw
    ) external {
        AccountingSnapshot memory beforeSnapshot = _snapshotAccounting();

        uint256 currentAssets = vault.totalAssets();
        uint128 maxTotalAssets;
        if (totalCapRaw % 4 != 0) {
            uint256 boundedTotalCap = currentAssets + (uint256(totalCapRaw) % INITIAL_ASSET_SUPPLY) + 1;
            // casting to uint128 is safe because this bounded cap stays below the fixture's initial supply envelope.
            // forge-lint: disable-next-line(unsafe-typecast)
            maxTotalAssets = uint128(boundedTotalCap);
        }
        uint128 maxDeposit = depositRaw % 4 == 0 ? 0 : uint128((uint256(depositRaw) % INITIAL_ASSETS) + 1);
        uint128 maxMint = mintRaw % 4 == 0 ? 0 : uint128((uint256(mintRaw) % INITIAL_ASSETS) + 1);
        uint128 maxWithdraw = withdrawRaw % 4 == 0 ? 0 : uint128((uint256(withdrawRaw) % INITIAL_ASSETS) + 1);
        uint128 maxRedeem = redeemRaw % 4 == 0 ? 0 : uint128((uint256(redeemRaw) % INITIAL_ASSETS) + 1);

        VM.prank(admin);
        vault.setLimitConfig(maxTotalAssets, maxDeposit, maxMint, maxWithdraw, maxRedeem);

        _assertAccountingUnchanged(beforeSnapshot, "limit config updates should not mutate accounting state");
        _assertCoreAccountingAligned();
    }

    function actionPausedDepositAttempt(uint8 actorSeed, uint96 assetsRaw) external {
        address actor = _actor(actorSeed);
        uint256 assets = _boundAmount(assetsRaw, asset.balanceOf(actor));
        if (assets == 0) {
            return;
        }

        _pauseIfNeeded();
        AccountingSnapshot memory beforeSnapshot = _snapshotAccounting();

        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        VM.prank(actor);
        vault.deposit(assets, actor);

        _assertAccountingUnchanged(beforeSnapshot, "paused deposit attempts must not mutate accounting");
        _assertCoreAccountingAligned();
    }

    function actionPausedWithdrawAttempt(uint8 actorSeed, uint96 assetsRaw) external {
        address actor = _actor(actorSeed);
        uint256 actorShares = vault.balanceOf(actor);
        if (actorShares == 0) {
            return;
        }

        uint256 withdrawAssets = _boundAmount(assetsRaw, vault.previewRedeem(actorShares));
        if (withdrawAssets == 0) {
            return;
        }

        _pauseIfNeeded();
        AccountingSnapshot memory beforeSnapshot = _snapshotAccounting();

        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        VM.prank(actor);
        vault.withdraw(withdrawAssets, actor, actor);

        _assertAccountingUnchanged(beforeSnapshot, "paused withdraw attempts must not mutate accounting");
        _assertCoreAccountingAligned();
    }

    function actionReentrantDepositAttempt(uint8 actorSeed, uint96 assetsRaw) external {
        if (vault.paused()) {
            return;
        }

        address actor = _actor(actorSeed);
        uint256 maxAssets = _min(vault.maxDeposit(actor), asset.balanceOf(actor));
        uint256 assets = _boundAmount(assetsRaw, maxAssets);
        if (assets == 0 || vault.previewDeposit(assets) == 0) {
            return;
        }

        asset.configureReentry(address(vault), abi.encodeCall(ERC4626VaultControlsHarness.probeNonReentrant, ()), true);

        VM.prank(actor);
        vault.deposit(assets, actor);

        assertTrue(asset.reentryAttemptBlocked(), "reentrant callback should be blocked during deposit");
        assertFalse(vault.reentrancyGuardEntered(), "reentrancy guard should exit cleanly after deposit");

        asset.configureReentry(address(0), new bytes(0), false);

        _assertCoreAccountingAligned();
    }

    function invariantManagedAssetsTrackUnderlyingBalance() public view {
        assertTrue(
            vault.totalAssets() == asset.balanceOf(address(vault)),
            "managed assets should match vault-held underlying after every successful action"
        );
    }

    function invariantShareSupplyMatchesTrackedActorBalances() public view {
        assertTrue(
            vault.totalSupply() == _sumActorShareBalances(),
            "total share supply should remain equal to tracked actor balances"
        );
    }

    function invariantTrackedUnderlyingRemainsConserved() public view {
        assertTrue(
            _trackedUnderlyingTotal() == INITIAL_ASSET_SUPPLY,
            "underlying balance should remain conserved across actors, vault, and fee sink"
        );
    }

    function invariantPausedStateZeroesMutatingMaxFunctions() public view {
        if (!vault.paused()) {
            return;
        }

        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            address actor = actors[i];
            assertTrue(vault.maxDeposit(actor) == 0, "paused vault should expose zero maxDeposit");
            assertTrue(vault.maxMint(actor) == 0, "paused vault should expose zero maxMint");
            assertTrue(vault.maxWithdraw(actor) == 0, "paused vault should expose zero maxWithdraw");
            assertTrue(vault.maxRedeem(actor) == 0, "paused vault should expose zero maxRedeem");
        }
    }

    function invariantConfiguredCapIsNotExceeded() public view {
        (uint128 maxTotalAssets,,,,) = vault.limitConfig();
        if (maxTotalAssets == 0) {
            return;
        }

        assertTrue(vault.totalAssets() <= maxTotalAssets, "configured total-assets cap should not be exceeded");
    }
}
