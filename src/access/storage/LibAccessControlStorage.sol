// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title LibAccessControlStorage
/// @notice Storage layout for AccessControl modules (diamond-ready).
library LibAccessControlStorage {
    /// @dev Storage slot for the layout.
    bytes32 internal constant STORAGE_SLOT = keccak256("auralis.access-control.storage");

    /// @notice Role membership and admin role data.
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
        address[] memberList;
        mapping(address => uint256) memberIndex;
    }

    /// @notice Access control storage layout.
    struct Layout {
        bool initialized;
        mapping(bytes32 => RoleData) roles;
    }

    /// @notice Returns the storage layout for access control.
    /// @return l The storage layout pointer.
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
