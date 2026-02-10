// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../interfaces/IAccessControl.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {LibAccessControlStorage} from "./LibAccessControlStorage.sol";

/// @title AccessControl
/// @notice Minimal role-based access control with admin hierarchy.
/// @dev Roles default to being administered by DEFAULT_ADMIN_ROLE.
abstract contract AccessControl is IAccessControl {
    /// @notice Default admin for all roles unless overridden.
    /// @dev Equal to bytes32(0).
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /// @param initialAdmin The account to receive DEFAULT_ADMIN_ROLE.
    constructor(address initialAdmin) {
        _initializeAccessControl(initialAdmin);
    }

    /// @dev Reverts if the caller is missing `role`.
    modifier onlyRole(bytes32 role) {
        _checkRole(role, msg.sender);
        _;
    }

    /// @notice Returns true if `account` has been granted `role`.
    /// @param role The role to query.
    /// @param account The account to query.
    /// @return True if the account has the role.
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return LibAccessControlStorage.layout().roles[role].members[account];
    }

    /// @notice Returns the admin role that controls `role`.
    /// @param role The role to query.
    /// @return The admin role for `role`.
    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return LibAccessControlStorage.layout().roles[role].adminRole;
    }

    /// @notice Returns true if this contract implements `interfaceId`.
    /// @param interfaceId The interface identifier.
    /// @return True if the interface is supported.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /// @notice Grants `role` to `account`.
    /// @dev Caller must have ``getRoleAdmin(role)``.
    /// @param role The role to grant.
    /// @param account The account to grant the role to.
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /// @notice Revokes `role` from `account`.
    /// @dev Caller must have ``getRoleAdmin(role)``.
    /// @param role The role to revoke.
    /// @param account The account to revoke the role from.
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /// @notice Renounces `role` for `account`.
    /// @dev Reverts unless `account == msg.sender`.
    /// @param role The role to renounce.
    /// @param account The account renouncing the role.
    function renounceRole(bytes32 role, address account) public virtual {
        if (account != msg.sender) {
            revert AccessControlRenounceSelfOnly();
        }
        _revokeRole(role, account);
    }

    /// @notice Returns the role member at `index`.
    /// @param role The role to enumerate.
    /// @param index The index in the role member array.
    /// @return The account at the given index.
    function getRoleMember(bytes32 role, uint256 index) public view returns (address) {
        return LibAccessControlStorage.layout().roles[role].memberList[index];
    }

    /// @notice Returns the number of members for `role`.
    /// @param role The role to enumerate.
    /// @return The number of accounts in the role.
    function getRoleMemberCount(bytes32 role) public view returns (uint256) {
        return LibAccessControlStorage.layout().roles[role].memberList.length;
    }

    /// @dev Initializes access control storage (diamond-ready).
    /// @param initialAdmin The account to receive DEFAULT_ADMIN_ROLE.
    function _initializeAccessControl(address initialAdmin) internal {
        LibAccessControlStorage.Layout storage layout = LibAccessControlStorage.layout();
        if (layout.initialized) {
            revert AccessControlAlreadyInitialized();
        }
        if (initialAdmin == address(0)) {
            revert AccessControlZeroAdmin();
        }
        layout.initialized = true;
        layout.roles[DEFAULT_ADMIN_ROLE].adminRole = DEFAULT_ADMIN_ROLE;
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    /// @dev Reverts with {AccessControlUnauthorized} if `account` lacks `role`.
    /// @param role The required role.
    /// @param account The account being checked.
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorized(account, role);
        }
    }

    /// @dev Updates the admin role for `role`.
    /// @param role The role to update.
    /// @param adminRole The new admin role.
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        LibAccessControlStorage.Layout storage layout = LibAccessControlStorage.layout();
        bytes32 previousAdminRole = layout.roles[role].adminRole;
        layout.roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /// @dev Grants `role` to `account` if not already granted.
    /// @param role The role to grant.
    /// @param account The account receiving the role.
    function _grantRole(bytes32 role, address account) internal virtual {
        LibAccessControlStorage.RoleData storage roleData = LibAccessControlStorage.layout().roles[role];
        if (!roleData.members[account]) {
            roleData.members[account] = true;
            if (roleData.memberIndex[account] == 0) {
                roleData.memberList.push(account);
                roleData.memberIndex[account] = roleData.memberList.length;
            }
            emit RoleGranted(role, account, msg.sender);
        }
    }

    /// @dev Revokes `role` from `account` if currently granted.
    /// @param role The role to revoke.
    /// @param account The account losing the role.
    function _revokeRole(bytes32 role, address account) internal virtual {
        LibAccessControlStorage.RoleData storage roleData = LibAccessControlStorage.layout().roles[role];
        if (roleData.members[account]) {
            roleData.members[account] = false;
            uint256 index = roleData.memberIndex[account];
            if (index != 0) {
                uint256 lastIndex = roleData.memberList.length;
                if (index != lastIndex) {
                    address lastMember = roleData.memberList[lastIndex - 1];
                    roleData.memberList[index - 1] = lastMember;
                    roleData.memberIndex[lastMember] = index;
                }
                roleData.memberList.pop();
                roleData.memberIndex[account] = 0;
            }
            emit RoleRevoked(role, account, msg.sender);
        }
    }
}
