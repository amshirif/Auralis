// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "./IERC165.sol";

/// @title IAccessControl
/// @notice Interface for minimal role-based access control with admin hierarchy.
interface IAccessControl is IERC165 {
    /// @notice Emitted when a role's admin is changed.
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    /// @notice Emitted when a role is granted.
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    /// @notice Emitted when a role is revoked.
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    /// @notice Thrown when an account is missing a required role.
    error AccessControlUnauthorized(address account, bytes32 role);
    /// @notice Thrown when renouncing a role for another account.
    error AccessControlRenounceSelfOnly();
    /// @notice Thrown when initializing with the zero admin address.
    error AccessControlZeroAdmin();
    /// @notice Thrown when initializing more than once.
    error AccessControlAlreadyInitialized();
    /// @notice Thrown when a zero address account is provided.
    error AccessControlZeroAddressAccount();

    /// @notice Default admin for all roles unless overridden.
    /// @return The default admin role identifier.
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    /// @notice Returns true if `account` has been granted `role`.
    /// @param role The role to query.
    /// @param account The account to query.
    /// @return True if the account has the role.
    function hasRole(bytes32 role, address account) external view returns (bool);

    /// @notice Returns the admin role that controls `role`.
    /// @param role The role to query.
    /// @return The admin role for `role`.
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /// @notice Grants `role` to `account`.
    /// @param role The role to grant.
    /// @param account The account to grant the role to.
    function grantRole(bytes32 role, address account) external;

    /// @notice Revokes `role` from `account`.
    /// @param role The role to revoke.
    /// @param account The account to revoke the role from.
    function revokeRole(bytes32 role, address account) external;

    /// @notice Renounces `role` for `account`.
    /// @param role The role to renounce.
    /// @param account The account renouncing the role.
    function renounceRole(bytes32 role, address account) external;

    /// @notice Returns the role member at `index`.
    /// @param role The role to enumerate.
    /// @param index The index in the role member array.
    /// @return The account at the given index.
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    /// @notice Returns the number of members for `role`.
    /// @param role The role to enumerate.
    /// @return The number of accounts in the role.
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}
