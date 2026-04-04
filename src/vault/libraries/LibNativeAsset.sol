// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title LibNativeAsset
/// @notice Shared native-asset sentinel helpers for hosted vault flows.
library LibNativeAsset {
    address internal constant NATIVE_ASSET_SENTINEL = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function isNativeAsset(address asset_) internal pure returns (bool) {
        return asset_ == NATIVE_ASSET_SENTINEL;
    }
}
