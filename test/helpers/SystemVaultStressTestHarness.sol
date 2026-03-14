// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IPausable} from "../../src/interfaces/IPausable.sol";
import {ReentrantMockVaultAsset, ERC4626VaultControlsHarness} from "./ERC4626VaultControlsTestHarness.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

abstract contract SystemVaultStressFixture is TestBase {
    struct AccountingSnapshot {
        uint256 totalAssets;
        uint256 totalSupply;
        uint256 vaultUnderlyingBalance;
        uint256 feeSinkBalance;
        uint256 actorUnderlyingBalanceSum;
        uint256 actorShareBalanceSum;
    }

    uint256 internal constant INITIAL_ASSETS = 1_000_000;
    uint256 internal constant ACTOR_COUNT = 3;
    uint256 internal constant INITIAL_ASSET_SUPPLY = INITIAL_ASSETS * ACTOR_COUNT;

    address internal admin = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA11);
    address internal dave = address(0xD0D);
    address internal feeSink = address(0xFEE);

    ReentrantMockVaultAsset internal asset;
    ERC4626VaultControlsHarness internal vault;
    address[ACTOR_COUNT] internal actors;

    function setUp() public virtual {
        asset = new ReentrantMockVaultAsset();
        vault = new ERC4626VaultControlsHarness(admin, address(asset), "Vault Share", "vSHARE");

        actors[0] = bob;
        actors[1] = carol;
        actors[2] = dave;

        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            address actor = actors[i];
            asset.mint(actor, INITIAL_ASSETS);
            VM.prank(actor);
            asset.approve(address(vault), type(uint256).max);
        }

        VM.prank(admin);
        vault.setFeeConfig(0, 0, feeSink);
    }

    function _actor(uint8 seed) internal view returns (address) {
        return actors[uint256(seed) % ACTOR_COUNT];
    }

    function _boundAmount(uint256 raw, uint256 max) internal pure returns (uint256) {
        if (max == 0) {
            return 0;
        }
        return (raw % max) + 1;
    }

    function _min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

    function _sumActorShareBalances() internal view returns (uint256 sum) {
        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            sum += vault.balanceOf(actors[i]);
        }
    }

    function _sumActorAssetBalances() internal view returns (uint256 sum) {
        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            sum += asset.balanceOf(actors[i]);
        }
    }

    function _trackedUnderlyingTotal() internal view returns (uint256) {
        return _sumActorAssetBalances() + asset.balanceOf(address(vault)) + asset.balanceOf(feeSink);
    }

    function _snapshotAccounting() internal view returns (AccountingSnapshot memory snapshot) {
        snapshot.totalAssets = vault.totalAssets();
        snapshot.totalSupply = vault.totalSupply();
        snapshot.vaultUnderlyingBalance = asset.balanceOf(address(vault));
        snapshot.feeSinkBalance = asset.balanceOf(feeSink);
        snapshot.actorUnderlyingBalanceSum = _sumActorAssetBalances();
        snapshot.actorShareBalanceSum = _sumActorShareBalances();
    }

    function _assertAccountingUnchanged(AccountingSnapshot memory beforeSnapshot, string memory reason) internal view {
        AccountingSnapshot memory afterSnapshot = _snapshotAccounting();
        assertTrue(afterSnapshot.totalAssets == beforeSnapshot.totalAssets, reason);
        assertTrue(afterSnapshot.totalSupply == beforeSnapshot.totalSupply, reason);
        assertTrue(afterSnapshot.vaultUnderlyingBalance == beforeSnapshot.vaultUnderlyingBalance, reason);
        assertTrue(afterSnapshot.feeSinkBalance == beforeSnapshot.feeSinkBalance, reason);
        assertTrue(afterSnapshot.actorUnderlyingBalanceSum == beforeSnapshot.actorUnderlyingBalanceSum, reason);
        assertTrue(afterSnapshot.actorShareBalanceSum == beforeSnapshot.actorShareBalanceSum, reason);
    }

    function _assertCoreAccountingAligned() internal view {
        assertTrue(
            vault.totalAssets() == asset.balanceOf(address(vault)),
            "managed assets and vault-held underlying should remain aligned"
        );
        assertTrue(
            vault.totalSupply() == _sumActorShareBalances(),
            "share supply should remain equal to tracked actor balances"
        );
        assertTrue(
            _trackedUnderlyingTotal() == INITIAL_ASSET_SUPPLY,
            "tracked underlying should remain conserved across actors, vault, and fee sink"
        );
    }

    function _pauseIfNeeded() internal {
        if (!vault.paused()) {
            VM.prank(admin);
            vault.pause();
        }
    }

    function _unpauseIfNeeded() internal {
        if (vault.paused()) {
            VM.prank(admin);
            vault.unpause();
        }
    }
}
