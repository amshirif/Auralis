// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "./IERC165.sol";

/// @title IUpgradeGuardrails
/// @notice Interface for role-gated upgrade guard rails.
interface IUpgradeGuardrails is IERC165 {
    /// @notice Emitted when an upgrade intent is queued.
    event UpgradeIntentQueued(address indexed implementation, uint64 executeAfter, address indexed sender);
    /// @notice Emitted when an upgrade intent is cancelled.
    event UpgradeIntentCancelled(address indexed implementation, address indexed sender);
    /// @notice Emitted when an upgrade is executed.
    event UpgradeExecuted(address indexed implementation, address indexed sender);

    /// @notice Thrown when implementation is zero address.
    error UpgradeGuardrailsZeroImplementation();
    /// @notice Thrown when attempting to execute/cancel without a queued intent.
    error UpgradeGuardrailsNoUpgradeIntent();
    /// @notice Thrown when requested implementation does not match queued implementation.
    error UpgradeGuardrailsImplementationNotQueued(address queuedImplementation, address requestedImplementation);
    /// @notice Thrown when upgrade timelock is still active.
    error UpgradeGuardrailsUpgradeNotReady(uint64 executeAfter, uint64 currentTime);
    /// @notice Thrown when upgrade guardrails module is initialized more than once.
    error UpgradeGuardrailsAlreadyInitialized();

    /// @notice Role required to queue, cancel, and execute upgrades.
    /// @return The upgrader role identifier.
    function UPGRADER_ROLE() external view returns (bytes32);

    /// @notice Returns the minimum required delay between queue and execute.
    /// @return Delay in seconds.
    function minUpgradeDelay() external view returns (uint64);

    /// @notice Returns the currently queued upgrade intent.
    /// @return implementation The queued implementation address.
    /// @return executeAfter Earliest execution timestamp.
    /// @return exists True when an intent is queued.
    function getUpgradeIntent() external view returns (address implementation, uint64 executeAfter, bool exists);

    /// @notice Queues an upgrade intent.
    /// @param implementation The new implementation address.
    function queueUpgradeIntent(address implementation) external;

    /// @notice Cancels the currently queued upgrade intent.
    function cancelUpgradeIntent() external;

    /// @notice Executes a queued upgrade after guardrail checks.
    /// @param implementation The queued implementation address.
    function executeUpgrade(address implementation) external;
}

