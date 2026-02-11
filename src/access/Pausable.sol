// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "./AccessControl.sol";
import {IPausable} from "../interfaces/IPausable.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {LibPausableStorage} from "./storage/LibPausableStorage.sol";

/// @title Pausable
/// @notice Role-gated pause and emergency stop module.
/// @dev Uses `PAUSER_ROLE` and diamond-ready storage.
abstract contract Pausable is AccessControl, IPausable {
    /// @notice Role required to call `pause` and `unpause`.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @param initialAdmin The account to receive DEFAULT_ADMIN_ROLE.
    constructor(address initialAdmin) AccessControl(initialAdmin) {
        _initializePausable(initialAdmin);
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

    /// @dev Reverts when the given pause `scope` is effectively paused.
    modifier whenScopeNotPaused(bytes32 scope) {
        _requireScopeNotPaused(scope);
        _;
    }

    /// @dev Reverts when the given pause `scope` is not effectively paused.
    modifier whenScopePaused(bytes32 scope) {
        _requireScopePaused(scope);
        _;
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
    function unpause() public onlyRole(PAUSER_ROLE) whenPaused {
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
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, IERC165) returns (bool) {
        return interfaceId == type(IPausable).interfaceId || interfaceId == type(IERC165).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @dev Initializes pausable storage (diamond-ready).
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

    /// @dev Reverts with {PausableScopeExpectedPause} when scope is not effectively paused.
    /// @param scope The scope identifier.
    function _requireScopePaused(bytes32 scope) internal view {
        _requireValidScope(scope);
        if (!paused(scope)) {
            revert PausableScopeExpectedPause(scope);
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
