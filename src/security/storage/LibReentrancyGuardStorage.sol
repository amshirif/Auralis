// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title LibReentrancyGuardStorage
/// @notice Storage layout for reentrancy guard modules (diamond-ready).
library LibReentrancyGuardStorage {
    /// @dev Unique namespaced storage slot; do not reuse or rename without migration review.
    bytes32 internal constant STORAGE_SLOT = keccak256("auralis.reentrancy-guard.storage");

    /// @notice Reentrancy guard storage layout.
    struct Layout {
        bool initialized;
        uint256 status;
    }

    /// @notice Returns the storage layout for reentrancy guard state.
    /// @return l The storage layout pointer.
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
