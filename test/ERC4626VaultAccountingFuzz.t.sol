// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC4626VaultAccountingFixture} from "./helpers/ERC4626VaultAccountingTestHarness.sol";

contract ERC4626VaultAccountingFuzzTest is ERC4626VaultAccountingFixture {
    function testFuzzPreviewDepositMatchesExecutedDeposit(uint8 actorSeed, uint96 assetsRaw) public {
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
        uint256 mintedShares = vault.deposit(assets, actor);
        assertTrue(mintedShares == previewShares, "deposit shares should match preview");
    }

    function testFuzzPreviewMintMatchesExecutedMint(uint8 actorSeed, uint96 sharesRaw) public {
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

        uint256 previewAssets = vault.previewMint(shares);
        if (previewAssets > availableAssets) {
            return;
        }

        VM.prank(actor);
        uint256 usedAssets = vault.mint(shares, actor);
        assertTrue(usedAssets == previewAssets, "mint assets should match preview");
    }

    function testFuzzPreviewFunctionsRespectRoundingConventions(
        uint96 seedSharesRaw,
        uint96 seedAssetsRaw,
        uint96 probeRaw
    ) public {
        uint256 seedShares = uint256(seedSharesRaw % 1e18) + 1;
        uint256 seedAssets = uint256(seedAssetsRaw % 1e18) + 1;
        uint256 probe = uint256(probeRaw % 1e18) + 1;

        vault.seedPosition(admin, seedShares, seedAssets);
        asset.mint(address(vault), seedAssets);

        assertTrue(vault.previewDeposit(probe) == vault.convertToShares(probe), "deposit preview should round down");
        assertTrue(vault.previewMint(probe) >= vault.convertToAssets(probe), "mint preview should round up");
        assertTrue(vault.previewWithdraw(probe) >= vault.convertToShares(probe), "withdraw preview should round up");
        assertTrue(vault.previewRedeem(probe) <= vault.convertToAssets(probe), "redeem preview should round down");
    }

    function testFuzzLowLiquidityDepositRedeemRoundTripLossBounded(uint96 assetsRaw) public {
        _seedLowLiquidityState();

        uint256 assetsIn = uint256(assetsRaw % 1_000_000) + 1;
        VM.prank(bob);
        uint256 mintedShares = vault.deposit(assetsIn, bob);

        if (vault.previewRedeem(mintedShares) == 0) {
            return;
        }

        VM.prank(bob);
        uint256 assetsOut = vault.redeem(mintedShares, bob, bob);

        assertTrue(assetsOut <= assetsIn, "roundtrip cannot output more than input");
        assertTrue(assetsIn - assetsOut <= 1, "roundtrip loss should be <= 1 asset");
    }

    function testLowLiquidityPreviewBoundaries() public {
        _seedLowLiquidityState();

        assertTrue(vault.previewWithdraw(1) == 2, "previewWithdraw should round up to 2 shares");
        assertTrue(vault.previewRedeem(1) == 0, "previewRedeem should round down to 0 assets");
    }
}
