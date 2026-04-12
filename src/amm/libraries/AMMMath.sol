// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title AMMMath
/// @notice Shared math helpers for the standalone AMM subsystem.
library AMMMath {
    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

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
