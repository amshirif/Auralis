// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title LibAccessControlTimeStorage
/// @notice Time-window storage layout for AccessControl modules (diamond-ready).
library LibAccessControlTimeStorage {
    /// @dev Storage slot for time-window layout.
    bytes32 internal constant STORAGE_SLOT = keccak256("smart-contracts.access-control.time.storage");

    /// @notice Per-account role activation window.
    struct RoleWindow {
        uint64 start;
        uint64 end;
        bool exists;
    }

    /// @notice Time-window storage layout.
    struct Layout {
        mapping(bytes32 => mapping(address => RoleWindow)) roleWindows;
    }

    /// @notice Returns the storage layout for role time windows.
    /// @return l The storage layout pointer.
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
