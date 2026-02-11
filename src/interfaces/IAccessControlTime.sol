// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "./IERC165.sol";

/// @title IAccessControlTime
/// @notice Interface for optional time-gated role behavior.
interface IAccessControlTime is IERC165 {
    /// @notice Emitted when a role time window is set.
    event RoleWindowSet(
        bytes32 indexed role, address indexed account, uint64 start, uint64 end, address indexed sender
    );
    /// @notice Emitted when a role time window is cleared.
    event RoleWindowCleared(bytes32 indexed role, address indexed account, address indexed sender);

    /// @notice Thrown when a role time window is invalid.
    error AccessControlInvalidRoleWindow(uint64 start, uint64 end);
    /// @notice Thrown when an account is outside its role time window.
    error AccessControlRoleNotActive(address account, bytes32 role);

    /// @notice Grants `role` to `account` and sets an active time window.
    /// @dev `end` equal to `0` means no expiry.
    /// @param role The role to grant and schedule.
    /// @param account The account to grant the role to.
    /// @param start Activation timestamp (inclusive).
    /// @param end Expiration timestamp (exclusive), or `0` for no expiry.
    function grantRoleWithWindow(bytes32 role, address account, uint64 start, uint64 end) external;

    /// @notice Sets the active time window for `account` on `role`.
    /// @dev `end` equal to `0` means no expiry.
    /// @param role The role to schedule.
    /// @param account The account to schedule.
    /// @param start Activation timestamp (inclusive).
    /// @param end Expiration timestamp (exclusive), or `0` for no expiry.
    function setRoleWindow(bytes32 role, address account, uint64 start, uint64 end) external;

    /// @notice Clears the active time window for `account` on `role`.
    /// @param role The role to clear.
    /// @param account The account to clear.
    function clearRoleWindow(bytes32 role, address account) external;

    /// @notice Returns the configured time window for `account` on `role`.
    /// @param role The role to query.
    /// @param account The account to query.
    /// @return start Activation timestamp (inclusive).
    /// @return end Expiration timestamp (exclusive), or `0` for no expiry.
    /// @return exists True if a window is configured.
    function getRoleWindow(bytes32 role, address account) external view returns (uint64 start, uint64 end, bool exists);

    /// @notice Returns whether `account` currently has an active time-gated `role`.
    /// @dev Returns false when no role window is configured.
    /// @param role The role to query.
    /// @param account The account to query.
    /// @return True when account has role and its window is currently active.
    function hasActiveRole(bytes32 role, address account) external view returns (bool);
}
