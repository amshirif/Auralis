// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../interfaces/IAccessControl.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {IPausable} from "../interfaces/IPausable.sol";
import {LibAccessControlStorage} from "../access/storage/LibAccessControlStorage.sol";
import {LibPausableStorage} from "../access/storage/LibPausableStorage.sol";

/// @title TokenFacetControl
/// @notice Constructor-free access control and pausability layer for hosted token facets.
abstract contract TokenFacetControl is IAccessControl, IPausable {
    /// @notice Default admin for all roles unless overridden.
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /// @notice Role required to call `pause` and `unpause`.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @dev Reverts if the caller is missing `role`.
    modifier onlyRole(bytes32 role) {
        _checkRole(role, msg.sender);
        _;
    }

    /// @dev Reverts when contract is paused.
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /// @dev Reverts when the given pause `scope` is effectively paused.
    modifier whenScopeNotPaused(bytes32 scope) {
        _requireScopeNotPaused(scope);
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

    /// @notice Grants `role` to `account`.
    /// @dev Caller must have ``getRoleAdmin(role)``.
    /// @param role The role to grant.
    /// @param account The account to grant the role to.
    function grantRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /// @notice Revokes `role` from `account`.
    /// @dev Caller must have ``getRoleAdmin(role)``.
    /// @param role The role to revoke.
    /// @param account The account to revoke the role from.
    function revokeRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /// @notice Renounces `role` for `account`.
    /// @dev Reverts unless `account == msg.sender`.
    /// @param role The role to renounce.
    /// @param account The account renouncing the role.
    function renounceRole(bytes32 role, address account) public {
        if (account != msg.sender) {
            revert AccessControlRenounceSelfOnly();
        }
        _revokeRole(role, account);
    }

    /// @notice Returns true when the contract is paused.
    /// @return True if paused.
    function paused() public view returns (bool) {
        return LibPausableStorage.layout().paused;
    }

    /// @notice Returns true when `scope` is effectively paused.
    /// @dev Effective pause includes global pause override.
    /// @param scope The scope identifier.
    /// @return True if globally paused or scope paused.
    function paused(bytes32 scope) public view returns (bool) {
        // Global pause is the emergency override; a scoped unpause never bypasses a contract-wide stop.
        return paused() || scopePaused(scope);
    }

    /// @notice Returns true when `scope` is locally paused.
    /// @param scope The scope identifier.
    /// @return True if the scope itself is paused.
    function scopePaused(bytes32 scope) public view returns (bool) {
        return LibPausableStorage.layout().pausedScopes[scope];
    }

    /// @notice Pauses the contract.
    /// @dev Caller must have `PAUSER_ROLE`.
    function pause() public onlyRole(PAUSER_ROLE) whenNotPaused {
        LibPausableStorage.layout().paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Unpauses the contract.
    /// @dev Caller must have `PAUSER_ROLE`.
    function unpause() public onlyRole(PAUSER_ROLE) {
        _requirePaused();
        LibPausableStorage.layout().paused = false;
        emit Unpaused(msg.sender);
    }

    /// @notice Pauses a specific scope.
    /// @dev Caller must have `PAUSER_ROLE`.
    /// @param scope The scope identifier.
    function pauseScope(bytes32 scope) public onlyRole(PAUSER_ROLE) {
        _requireValidScope(scope);
        if (scopePaused(scope)) {
            revert PausableScopeEnforcedPause(scope);
        }
        LibPausableStorage.layout().pausedScopes[scope] = true;
        emit ScopePaused(scope, msg.sender);
    }

    /// @notice Unpauses a specific scope.
    /// @dev Caller must have `PAUSER_ROLE`.
    /// @param scope The scope identifier.
    function unpauseScope(bytes32 scope) public onlyRole(PAUSER_ROLE) {
        _requireValidScope(scope);
        if (!scopePaused(scope)) {
            revert PausableScopeExpectedPause(scope);
        }
        LibPausableStorage.layout().pausedScopes[scope] = false;
        emit ScopeUnpaused(scope, msg.sender);
    }

    /// @notice Returns true if this contract implements `interfaceId`.
    /// @param interfaceId The interface identifier.
    /// @return True if the interface is supported.
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IAccessControl).interfaceId
            || interfaceId == type(IPausable).interfaceId;
    }

    /// @dev Initializes shared access control and pausability storage when needed.
    /// @param initialAdmin The default admin and initial pauser.
    function _initializeTokenFacetControl(address initialAdmin) internal {
        // Hosted facets share control storage, so initialization must be opportunistic and idempotent
        // rather than assuming one dedicated initializer per facet.
        if (!_isAccessControlInitialized()) {
            _initializeAccessControl(initialAdmin);
        }
        if (!_isPausableInitialized()) {
            _initializePausable(initialAdmin);
        }
    }

    /// @dev Returns true if access control storage has already been initialized.
    /// @return True if initialized.
    function _isAccessControlInitialized() internal view returns (bool) {
        return LibAccessControlStorage.layout().initialized;
    }

    /// @dev Returns true if pausability storage has already been initialized.
    /// @return True if initialized.
    function _isPausableInitialized() internal view returns (bool) {
        return LibPausableStorage.layout().initialized;
    }

    /// @dev Initializes access control storage.
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

    /// @dev Initializes pausable storage and grants `PAUSER_ROLE`.
    /// @param initialPauser The account to receive `PAUSER_ROLE`.
    function _initializePausable(address initialPauser) internal {
        LibPausableStorage.Layout storage layout = LibPausableStorage.layout();
        if (layout.initialized) {
            revert PausableAlreadyInitialized();
        }
        _requireNonZeroAccount(initialPauser);

        layout.initialized = true;
        _grantRole(PAUSER_ROLE, initialPauser);
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
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        LibAccessControlStorage.Layout storage layout = LibAccessControlStorage.layout();
        bytes32 previousAdminRole = layout.roles[role].adminRole;
        layout.roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /// @dev Grants `role` to `account` if not already granted.
    /// @param role The role to grant.
    /// @param account The account receiving the role.
    function _grantRole(bytes32 role, address account) internal {
        _requireNonZeroAccount(account);

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
    function _revokeRole(bytes32 role, address account) internal {
        _requireNonZeroAccount(account);

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

    /// @dev Reverts when `account` is the zero address.
    /// @param account The account to validate.
    function _requireNonZeroAccount(address account) internal pure {
        if (account == address(0)) {
            revert AccessControlZeroAddressAccount();
        }
    }

    /// @dev Reverts with {PausableEnforcedPause} when paused.
    function _requireNotPaused() internal view {
        if (paused()) {
            revert PausableEnforcedPause();
        }
    }

    /// @dev Reverts with {PausableExpectedPause} when unpaused.
    function _requirePaused() internal view {
        if (!paused()) {
            revert PausableExpectedPause();
        }
    }

    /// @dev Reverts with {PausableScopeEnforcedPause} when scope is effectively paused.
    /// @param scope The scope identifier.
    function _requireScopeNotPaused(bytes32 scope) internal view {
        _requireValidScope(scope);
        if (paused(scope)) {
            revert PausableScopeEnforcedPause(scope);
        }
    }

    /// @dev Reverts with {PausableZeroScope} when `scope` is zero.
    /// @param scope The scope identifier.
    function _requireValidScope(bytes32 scope) internal pure {
        if (scope == bytes32(0)) {
            revert PausableZeroScope();
        }
    }
}
