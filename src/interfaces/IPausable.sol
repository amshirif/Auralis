// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "./IERC165.sol";

/// @title IPausable
/// @notice Interface for role-gated pause and unpause controls.
interface IPausable is IERC165 {
    /// @notice Emitted when the contract is paused.
    /// @param account Account that paused the contract.
    event Paused(address indexed account);
    /// @notice Emitted when the contract is unpaused.
    /// @param account Account that unpaused the contract.
    event Unpaused(address indexed account);
    /// @notice Emitted when a pause scope is paused.
    /// @param scope Scope that was paused.
    /// @param account Account that paused the scope.
    event ScopePaused(bytes32 indexed scope, address indexed account);
    /// @notice Emitted when a pause scope is unpaused.
    /// @param scope Scope that was unpaused.
    /// @param account Account that unpaused the scope.
    event ScopeUnpaused(bytes32 indexed scope, address indexed account);

    /// @notice Thrown when pause is required but contract is not paused.
    error PausableExpectedPause();
    /// @notice Thrown when unpaused state is required but contract is paused.
    error PausableEnforcedPause();
    /// @notice Thrown when a scope-specific pause is required but scope is not paused.
    /// @param scope Scope expected to be paused.
    error PausableScopeExpectedPause(bytes32 scope);
    /// @notice Thrown when unpaused scope state is required but scope is paused.
    /// @param scope Scope required to be unpaused.
    error PausableScopeEnforcedPause(bytes32 scope);
    /// @notice Thrown when a zero-value scope is used.
    error PausableZeroScope();
    /// @notice Thrown when pausable module is initialized more than once.
    error PausableAlreadyInitialized();

    /// @notice Role required to call `pause` and `unpause`.
    /// @return The pauser role identifier.
    function PAUSER_ROLE() external view returns (bytes32);

    /// @notice Returns true when the contract is paused.
    /// @return True if paused.
    function paused() external view returns (bool);

    /// @notice Returns true when `scope` is effectively paused.
    /// @dev Effective pause includes global pause override.
    /// @param scope The scope identifier.
    /// @return True if globally paused or scope paused.
    function paused(bytes32 scope) external view returns (bool);

    /// @notice Returns true when `scope` is locally paused.
    /// @param scope The scope identifier.
    /// @return True if the scope itself is paused.
    function scopePaused(bytes32 scope) external view returns (bool);

    /// @notice Pauses the contract.
    /// @dev Requires `PAUSER_ROLE`.
    function pause() external;

    /// @notice Unpauses the contract.
    /// @dev Requires `PAUSER_ROLE`.
    function unpause() external;

    /// @notice Pauses a specific scope.
    /// @dev Requires `PAUSER_ROLE`.
    /// @param scope The scope identifier.
    function pauseScope(bytes32 scope) external;

    /// @notice Unpauses a specific scope.
    /// @dev Requires `PAUSER_ROLE`.
    /// @param scope The scope identifier.
    function unpauseScope(bytes32 scope) external;
}
