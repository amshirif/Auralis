// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title LibPausableStorage
/// @notice Storage layout for pausability modules (diamond-ready).
library LibPausableStorage {
    /// @dev Unique namespaced storage slot; do not reuse or rename without migration review.
    bytes32 internal constant STORAGE_SLOT = keccak256("auralis.pausable.storage");

    /// @notice Pausable storage layout.
    struct Layout {
        bool initialized;
        bool paused;
        mapping(bytes32 => bool) pausedScopes;
    }

    /// @notice Returns the storage layout for pausable state.
    /// @return l The storage layout pointer.
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
