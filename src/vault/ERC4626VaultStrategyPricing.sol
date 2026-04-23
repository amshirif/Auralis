// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626VaultStrategy} from "../interfaces/IERC4626VaultStrategy.sol";
import {ERC4626VaultControlledCore} from "./ERC4626VaultControlLogic.sol";
import {LibERC4626VaultStorage} from "./storage/LibERC4626VaultStorage.sol";

/// @title ERC4626VaultStrategyPricing
/// @notice Shared hosted-vault live strategy pricing hooks.
abstract contract ERC4626VaultStrategyPricing is ERC4626VaultControlledCore {
    function _managedAssetsForPricing() internal view virtual override returns (uint256) {
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        if (layout.strategyDebt == 0) {
            return layout.totalManagedAssets;
        }

        // Native asset-in selectors live on ERC7535VaultFacet, so hosted pricing stays shared here
        // to keep native and ERC-20 deposits aligned when strategy debt is active. Hosted pricing also
        // intentionally trusts the bound strategy's live assets and does not fall back to stored debt
        // when the strategy quote reverts.
        uint256 idleBookAssets = layout.totalManagedAssets - layout.strategyDebt;
        uint256 liveStrategyAssets = IERC4626VaultStrategy(layout.strategy).totalAssets();
        return idleBookAssets + liveStrategyAssets;
    }

    function _withdrawLiquidityCapAssets() internal view virtual override returns (uint256) {
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        if (layout.strategyDebt == 0) {
            return type(uint256).max;
        }

        return _trackedIdleAssetBalance() + _strategyWithdrawableAssets();
    }
}
