// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC4626VaultAccountingFixture} from "./helpers/ERC4626VaultAccountingTestHarness.sol";

contract ERC4626VaultAccountingInvariantTest is ERC4626VaultAccountingFixture {
    uint256 internal constant INITIAL_ASSET_SUPPLY = INITIAL_ASSETS * ACTOR_COUNT;

    function targetContracts() external view returns (address[] memory contracts) {
        contracts = new address[](1);
        contracts[0] = address(this);
    }

    function actionDeposit(uint8 actorSeed, uint96 assetsRaw) external {
        address actor = _actor(actorSeed);
        uint256 maxAssets = _min(vault.maxDeposit(actor), asset.balanceOf(actor));
        uint256 assets = _boundAmount(assetsRaw, maxAssets);
        if (assets == 0) {
            return;
        }

        uint256 previewShares = vault.previewDeposit(assets);
        if (previewShares == 0) {
            return;
        }

        VM.prank(actor);
        vault.deposit(assets, actor);
    }

    function actionMint(uint8 actorSeed, uint96 sharesRaw) external {
        address actor = _actor(actorSeed);
        uint256 availableAssets = asset.balanceOf(actor);
        if (availableAssets == 0) {
            return;
        }

        uint256 maxSharesByAssets = vault.convertToShares(availableAssets);
        uint256 maxShares = _min(vault.maxMint(actor), maxSharesByAssets);
        uint256 shares = _boundAmount(sharesRaw, maxShares);
        if (shares == 0) {
            return;
        }

        uint256 requiredAssets = vault.previewMint(shares);
        if (requiredAssets > availableAssets) {
            return;
        }

        VM.prank(actor);
        vault.mint(shares, actor);
    }

    function actionWithdraw(uint8 actorSeed, uint96 assetsRaw) external {
        address actor = _actor(actorSeed);
        uint256 maxAssets = vault.maxWithdraw(actor);
        uint256 assets = _boundAmount(assetsRaw, maxAssets);
        if (assets == 0) {
            return;
        }

        VM.prank(actor);
        vault.withdraw(assets, actor, actor);
    }

    function actionRedeem(uint8 actorSeed, uint96 sharesRaw) external {
        address actor = _actor(actorSeed);
        uint256 maxShares = vault.maxRedeem(actor);
        uint256 shares = _boundAmount(sharesRaw, maxShares);
        if (shares == 0) {
            return;
        }

        if (vault.previewRedeem(shares) == 0) {
            return;
        }

        VM.prank(actor);
        vault.redeem(shares, actor, actor);
    }

    function actionTransferShares(uint8 fromSeed, uint8 toSeed, uint96 sharesRaw) external {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        if (from == to) {
            return;
        }

        uint256 maxShares = vault.balanceOf(from);
        uint256 shares = _boundAmount(sharesRaw, maxShares);
        if (shares == 0) {
            return;
        }

        VM.prank(from);
        assertTrue(vault.transfer(to, shares), "share transfer should succeed");
    }

    function invariantManagedAssetsMatchUnderlyingBalance() public view {
        assertTrue(
            vault.totalAssets() == asset.balanceOf(address(vault)), "managed assets and underlying balance must match"
        );
    }

    function invariantShareSupplyConservedAcrossTrackedActors() public view {
        assertTrue(
            vault.totalSupply() == _sumActorShareBalances(), "total supply must equal tracked actor share balances"
        );
    }

    function invariantUnderlyingAssetConservedAcrossTrackedActorsAndVault() public view {
        assertTrue(
            _sumActorAssetBalances() + asset.balanceOf(address(vault)) == INITIAL_ASSET_SUPPLY,
            "underlying assets should be conserved"
        );
    }
}
