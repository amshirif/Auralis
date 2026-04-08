// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "../../interfaces/IERC20.sol";

/// @title LibVaultAsset
/// @notice Shared asset-mode helpers for hosted vault token and native flows.
library LibVaultAsset {
    address internal constant NATIVE_ASSET_SENTINEL = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function isNativeAsset(address asset_) internal pure returns (bool) {
        return asset_ == NATIVE_ASSET_SENTINEL;
    }

    function balanceOfSelf(address asset_) internal view returns (uint256) {
        if (isNativeAsset(asset_)) {
            return address(this).balance;
        }

        return IERC20(asset_).balanceOf(address(this));
    }

    function transferOut(address asset_, address to, uint256 value) internal returns (bool) {
        if (isNativeAsset(asset_)) {
            (bool nativeSuccess,) = payable(to).call{value: value}("");
            return nativeSuccess;
        }

        (bool success, bytes memory data) = asset_.call(abi.encodeCall(IERC20.transfer, (to, value)));
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }

    function transferIn(address asset_, address from, address to, uint256 value) internal returns (bool) {
        if (isNativeAsset(asset_)) {
            return false;
        }

        (bool success, bytes memory data) = asset_.call(abi.encodeCall(IERC20.transferFrom, (from, to, value)));
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }
}
