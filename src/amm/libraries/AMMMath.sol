// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title AMMMath
/// @notice Shared math helpers for the standalone AMM subsystem.
library AMMMath {
    /// @notice Returns the smaller of two unsigned integers.
    /// @param x First value.
    /// @param y Second value.
    /// @return The minimum of `x` and `y`.
    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

    /// @notice Returns the integer square root of `y` using the Babylonian method.
    /// @param y Value to square-root.
    /// @return z Floor of the square root.
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y == 0) {
            return 0;
        }
        if (y <= 3) {
            return 1;
        }

        z = y;
        uint256 x = (y / 2) + 1;
        while (x < z) {
            z = x;
            x = ((y / x) + x) / 2;
        }
    }
}
