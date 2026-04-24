// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../interfaces/IAccessControl.sol";
import {IAccessControlTime} from "../interfaces/IAccessControlTime.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {IPausable} from "../interfaces/IPausable.sol";
import {IReentrancyGuard} from "../interfaces/IReentrancyGuard.sol";
import {LibAccessControlStorage} from "../access/storage/LibAccessControlStorage.sol";
import {LibAccessControlTimeStorage} from "../access/storage/LibAccessControlTimeStorage.sol";
import {LibPausableStorage} from "../access/storage/LibPausableStorage.sol";
import {LibReentrancyGuardStorage} from "../security/storage/LibReentrancyGuardStorage.sol";
import {LibERC4626VaultStorage} from "./storage/LibERC4626VaultStorage.sol";
import {LibVaultFacetConstants} from "./libraries/LibVaultFacetConstants.sol";

/// @title VaultFacetControl
/// @notice Constructor-free access, pause, and reentrancy layer for hosted vault facets.
abstract contract VaultFacetControl is IAccessControl, IAccessControlTime, IPausable, IReentrancyGuard {
    /// @notice Default admin for all roles unless overridden.
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /// @notice Role required to call pause and unpause controls.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @dev Role that can manage vault fees and limits.
    bytes32 internal constant VAULT_MANAGER_ROLE_VALUE = LibVaultFacetConstants.VAULT_MANAGER_ROLE;

    /// @dev Reentrancy status for a function call not currently entered.
    uint256 internal constant NOT_ENTERED = 1;

    /// @dev Reentrancy status for a function call currently entered.
    uint256 internal constant ENTERED = 2;

    /// @dev Reverts if the caller is missing `role`.
    modifier onlyRole(bytes32 role) {
        _checkRole(role, msg.sender);
        _;
    }

    /// @dev Reverts if the caller does not currently have an active time-gated `role`.
    modifier onlyActiveRole(bytes32 role) {
        _checkActiveRole(role, msg.sender);
        _;
    }

    /// @dev Prevents a function from being called reentrantly.
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    /// @dev Reverts when contract is paused.
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /// @dev Reverts when contract is not paused.
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /// @inheritdoc IAccessControl
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return LibAccessControlStorage.layout().roles[role].members[account];
    }

    /// @inheritdoc IAccessControl
    function getRoleAdmin(bytes32 role) public view returns (bytes32) {
        return LibAccessControlStorage.layout().roles[role].adminRole;
    }

    /// @notice Role that can manage vault fees and limits.
    /// @return The vault manager role identifier.
    // forge-lint: disable-next-line(mixed-case-function) -- public role getter name is selector-stable.
    function VAULT_MANAGER_ROLE() public pure virtual returns (bytes32) {
        return VAULT_MANAGER_ROLE_VALUE;
    }

    /// @inheritdoc IAccessControl
    function grantRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /// @inheritdoc IAccessControlTime
    function grantRoleWithWindow(bytes32 role, address account, uint64 start, uint64 end)
        public
        onlyRole(getRoleAdmin(role))
    {
        _grantRole(role, account);
        _setRoleWindow(role, account, start, end, msg.sender);
    }

    /// @inheritdoc IAccessControl
    function revokeRole(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /// @inheritdoc IAccessControl
    function renounceRole(bytes32 role, address account) public {
        if (account != msg.sender) {
            revert AccessControlRenounceSelfOnly();
        }
        _revokeRole(role, account);
    }

    /// @inheritdoc IAccessControl
    function getRoleMember(bytes32 role, uint256 index) public view returns (address) {
        return LibAccessControlStorage.layout().roles[role].memberList[index];
    }

    /// @inheritdoc IAccessControl
    function getRoleMemberCount(bytes32 role) public view returns (uint256) {
        return LibAccessControlStorage.layout().roles[role].memberList.length;
    }

    /// @inheritdoc IAccessControlTime
    function setRoleWindow(bytes32 role, address account, uint64 start, uint64 end)
        public
        onlyRole(getRoleAdmin(role))
    {
        _setRoleWindow(role, account, start, end, msg.sender);
    }

    /// @inheritdoc IAccessControlTime
    function clearRoleWindow(bytes32 role, address account) public onlyRole(getRoleAdmin(role)) {
        _requireNonZeroAccount(account);
        _clearRoleWindow(role, account, msg.sender);
    }

    /// @inheritdoc IAccessControlTime
    function getRoleWindow(bytes32 role, address account) public view returns (uint64 start, uint64 end, bool exists) {
        LibAccessControlTimeStorage.RoleWindow storage window =
            LibAccessControlTimeStorage.layout().roleWindows[role][account];
        return (window.start, window.end, window.exists);
    }

    /// @inheritdoc IAccessControlTime
    function hasActiveRole(bytes32 role, address account) public view returns (bool) {
        if (!hasRole(role, account)) {
            return false;
        }

        LibAccessControlTimeStorage.RoleWindow storage window =
            LibAccessControlTimeStorage.layout().roleWindows[role][account];
        if (!window.exists) {
            return false;
        }

        uint256 timestamp = block.timestamp;
        if (timestamp < window.start) {
            return false;
        }
        if (window.end != 0 && timestamp >= window.end) {
            return false;
        }
        return true;
    }

    /// @inheritdoc IPausable
    function paused() public view returns (bool) {
        return LibPausableStorage.layout().paused;
    }

    /// @inheritdoc IPausable
    function paused(bytes32 scope) public view returns (bool) {
        return paused() || scopePaused(scope);
    }

    /// @inheritdoc IPausable
    function scopePaused(bytes32 scope) public view returns (bool) {
        return LibPausableStorage.layout().pausedScopes[scope];
    }

    /// @inheritdoc IPausable
    function pause() public onlyRole(PAUSER_ROLE) whenNotPaused {
        LibPausableStorage.layout().paused = true;
        emit Paused(msg.sender);
    }

    /// @inheritdoc IPausable
    function unpause() public onlyRole(PAUSER_ROLE) whenPaused {
        LibPausableStorage.layout().paused = false;
        emit Unpaused(msg.sender);
    }

    /// @inheritdoc IPausable
    function pauseScope(bytes32 scope) public onlyRole(PAUSER_ROLE) {
        _requireValidScope(scope);
        if (scopePaused(scope)) {
            revert PausableScopeEnforcedPause(scope);
        }

        LibPausableStorage.layout().pausedScopes[scope] = true;
        emit ScopePaused(scope, msg.sender);
    }

    /// @inheritdoc IPausable
    function unpauseScope(bytes32 scope) public onlyRole(PAUSER_ROLE) {
        _requireValidScope(scope);
        if (!scopePaused(scope)) {
            revert PausableScopeExpectedPause(scope);
        }

        LibPausableStorage.layout().pausedScopes[scope] = false;
        emit ScopeUnpaused(scope, msg.sender);
    }

    /// @inheritdoc IReentrancyGuard
    function reentrancyGuardEntered() public view returns (bool) {
        return LibReentrancyGuardStorage.layout().status == ENTERED;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IAccessControl).interfaceId
            || interfaceId == type(IAccessControlTime).interfaceId || interfaceId == type(IPausable).interfaceId
            || interfaceId == type(IReentrancyGuard).interfaceId;
    }

    /// @dev Initializes shared control storage and vault manager defaults when needed.
    /// @param initialAdmin The default admin, pauser, and initial vault manager.
    function _initializeVaultFacetControl(address initialAdmin) internal {
        if (!_isAccessControlInitialized()) {
            address diamondOwner;
            // This branch intentionally preserves standalone and unit-harness facet initialization when
            // no diamond owner is present in storage.
            assembly {
                diamondOwner := sload(add(0xd18822d915e92c257217ed11ce402f38beb69a891f3cff0924389749c6ea4a47, 4))
            }
            if (diamondOwner != address(0) && msg.sender != diamondOwner) {
                assembly {
                    mstore(0x00, 0x3bd3ca2300000000000000000000000000000000000000000000000000000000)
                    mstore(0x04, caller())
                    mstore(0x24, diamondOwner)
                    revert(0x00, 0x44)
                }
            }
            _initializeAccessControl(initialAdmin);
        }
        if (!_isPausableInitialized()) {
            _initializePausable(initialAdmin);
        }
        if (!_isReentrancyGuardInitialized()) {
            _initializeReentrancyGuard();
        }
        if (!LibERC4626VaultStorage.layout().controlPlaneInitialized) {
            _initializeVaultManagerDefaults(initialAdmin);
        }
    }

    function _isAccessControlInitialized() internal view returns (bool) {
        return LibAccessControlStorage.layout().initialized;
    }

    function _isPausableInitialized() internal view returns (bool) {
        return LibPausableStorage.layout().initialized;
    }

    function _isReentrancyGuardInitialized() internal view returns (bool) {
        return LibReentrancyGuardStorage.layout().initialized;
    }

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

    function _initializePausable(address initialPauser) internal {
        LibPausableStorage.Layout storage layout = LibPausableStorage.layout();
        if (layout.initialized) {
            revert PausableAlreadyInitialized();
        }
        _requireNonZeroAccount(initialPauser);

        layout.initialized = true;
        _grantRole(PAUSER_ROLE, initialPauser);
    }

    function _initializeReentrancyGuard() internal {
        LibReentrancyGuardStorage.Layout storage layout = LibReentrancyGuardStorage.layout();
        if (layout.initialized) {
            revert ReentrancyGuardAlreadyInitialized();
        }
        layout.initialized = true;
        layout.status = NOT_ENTERED;
    }

    /// @dev Seeds vault-manager defaults for a hosted vault control plane.
    /// @param initialManager The account receiving the initial manager role and fee recipient status.
    function _initializeVaultManagerDefaults(address initialManager) internal {
        _requireNonZeroAccount(initialManager);

        LibERC4626VaultStorage.Layout storage vaultLayout = LibERC4626VaultStorage.layout();
        _setRoleAdmin(VAULT_MANAGER_ROLE_VALUE, DEFAULT_ADMIN_ROLE);
        _grantRole(VAULT_MANAGER_ROLE_VALUE, initialManager);
        vaultLayout.fees.feeRecipient = initialManager;
        vaultLayout.controlPlaneInitialized = true;
    }

    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorized(account, role);
        }
    }

    function _checkActiveRole(bytes32 role, address account) internal view {
        if (!hasActiveRole(role, account)) {
            revert AccessControlRoleNotActive(account, role);
        }
    }

    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        LibAccessControlStorage.Layout storage layout = LibAccessControlStorage.layout();
        bytes32 previousAdminRole = layout.roles[role].adminRole;
        layout.roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    function _grantRole(bytes32 role, address account) internal virtual {
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

    function _revokeRole(bytes32 role, address account) internal virtual {
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
            _clearRoleWindow(role, account, msg.sender);
            emit RoleRevoked(role, account, msg.sender);
        }
    }

    function _validateRoleWindow(uint64 start, uint64 end) internal pure {
        if (end != 0 && end <= start) {
            revert AccessControlInvalidRoleWindow(start, end);
        }
    }

    function _setRoleWindow(bytes32 role, address account, uint64 start, uint64 end, address sender) internal {
        _requireNonZeroAccount(account);
        _validateRoleWindow(start, end);

        LibAccessControlTimeStorage.RoleWindow storage window =
            LibAccessControlTimeStorage.layout().roleWindows[role][account];
        window.start = start;
        window.end = end;
        window.exists = true;
        emit RoleWindowSet(role, account, start, end, sender);
    }

    function _clearRoleWindow(bytes32 role, address account, address sender) internal {
        LibAccessControlTimeStorage.Layout storage layout = LibAccessControlTimeStorage.layout();
        if (layout.roleWindows[role][account].exists) {
            delete layout.roleWindows[role][account];
            emit RoleWindowCleared(role, account, sender);
        }
    }

    function _nonReentrantBefore() internal {
        LibReentrancyGuardStorage.Layout storage layout = LibReentrancyGuardStorage.layout();
        if (layout.status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        layout.status = ENTERED;
    }

    function _nonReentrantAfter() internal {
        LibReentrancyGuardStorage.layout().status = NOT_ENTERED;
    }

    function _requireNotPaused() internal view {
        if (paused()) {
            revert PausableEnforcedPause();
        }
    }

    function _requireScopeNotPaused(bytes32 scope) internal view {
        if (paused(scope)) {
            revert PausableScopeEnforcedPause(scope);
        }
    }

    function _requirePaused() internal view {
        if (!paused()) {
            revert PausableExpectedPause();
        }
    }

    function _requireValidScope(bytes32 scope) internal pure {
        if (scope == bytes32(0)) {
            revert PausableZeroScope();
        }
    }

    function _requireNonZeroAccount(address account) internal pure {
        if (account == address(0)) {
            revert AccessControlZeroAddressAccount();
        }
    }
}
