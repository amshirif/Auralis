// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "../access/AccessControl.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {IUpgradeGuardrails} from "../interfaces/IUpgradeGuardrails.sol";
import {LibUpgradeGuardrailsStorage} from "./storage/LibUpgradeGuardrailsStorage.sol";

/// @title UpgradeGuardrails
/// @notice Opt-in role-gated queue/execute upgrade guard rails with optional timelock.
/// @dev Uses `UPGRADER_ROLE` and namespaced storage; deployments must implement their own `_applyUpgrade` hook.
abstract contract UpgradeGuardrails is AccessControl, IUpgradeGuardrails {
    /// @notice Role required to queue, cancel, and execute upgrades.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @param initialAdmin The account to receive DEFAULT_ADMIN_ROLE.
    /// @param minDelaySeconds The minimum delay between queue and execute.
    constructor(address initialAdmin, uint64 minDelaySeconds) AccessControl(initialAdmin) {
        _initializeUpgradeGuardrails(initialAdmin, minDelaySeconds);
    }

    /// @notice Returns the minimum required delay between queue and execute.
    /// @return Delay in seconds.
    function minUpgradeDelay() public view returns (uint64) {
        return LibUpgradeGuardrailsStorage.layout().minUpgradeDelay;
    }

    /// @notice Returns the currently queued upgrade intent.
    /// @return implementation The queued implementation address.
    /// @return executeAfter Earliest execution timestamp.
    /// @return exists True when an intent is queued.
    function getUpgradeIntent() public view returns (address implementation, uint64 executeAfter, bool exists) {
        LibUpgradeGuardrailsStorage.UpgradeIntent storage intent = LibUpgradeGuardrailsStorage.layout().intent;
        return (intent.implementation, intent.executeAfter, intent.exists);
    }

    /// @notice Queues an upgrade intent.
    /// @dev Caller must have `UPGRADER_ROLE`.
    /// @param implementation The new implementation address.
    function queueUpgradeIntent(address implementation) public onlyRole(UPGRADER_ROLE) {
        _requireNonZeroImplementation(implementation);
        uint64 executeAfter = uint64(block.timestamp) + minUpgradeDelay();

        LibUpgradeGuardrailsStorage.UpgradeIntent storage intent = LibUpgradeGuardrailsStorage.layout().intent;
        intent.implementation = implementation;
        intent.executeAfter = executeAfter;
        intent.exists = true;

        emit UpgradeIntentQueued(implementation, executeAfter, msg.sender);
    }

    /// @notice Cancels the currently queued upgrade intent.
    /// @dev Caller must have `UPGRADER_ROLE`.
    function cancelUpgradeIntent() public onlyRole(UPGRADER_ROLE) {
        LibUpgradeGuardrailsStorage.UpgradeIntent storage intent = LibUpgradeGuardrailsStorage.layout().intent;
        if (!intent.exists) {
            revert UpgradeGuardrailsNoUpgradeIntent();
        }

        address implementation = intent.implementation;
        delete LibUpgradeGuardrailsStorage.layout().intent;
        emit UpgradeIntentCancelled(implementation, msg.sender);
    }

    /// @notice Executes a queued upgrade after guardrail checks.
    /// @dev Caller must have `UPGRADER_ROLE`.
    /// @param implementation The queued implementation address.
    function executeUpgrade(address implementation) public onlyRole(UPGRADER_ROLE) {
        _requireNonZeroImplementation(implementation);
        LibUpgradeGuardrailsStorage.UpgradeIntent storage intent = LibUpgradeGuardrailsStorage.layout().intent;
        if (!intent.exists) {
            revert UpgradeGuardrailsNoUpgradeIntent();
        }
        if (intent.implementation != implementation) {
            revert UpgradeGuardrailsImplementationNotQueued(intent.implementation, implementation);
        }

        uint64 currentTime = uint64(block.timestamp);
        if (currentTime < intent.executeAfter) {
            revert UpgradeGuardrailsUpgradeNotReady(intent.executeAfter, currentTime);
        }

        delete LibUpgradeGuardrailsStorage.layout().intent;
        _applyUpgrade(implementation);
        emit UpgradeExecuted(implementation, msg.sender);
    }

    /// @notice Returns true if this contract implements `interfaceId`.
    /// @param interfaceId The interface identifier.
    /// @return True if the interface is supported.
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, IERC165) returns (bool) {
        return interfaceId == type(IUpgradeGuardrails).interfaceId || interfaceId == type(IERC165).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @dev Initializes upgrade guardrails storage for an opt-in deployment.
    /// @param initialUpgrader The account to receive `UPGRADER_ROLE`.
    /// @param minDelaySeconds The minimum delay between queue and execute.
    function _initializeUpgradeGuardrails(address initialUpgrader, uint64 minDelaySeconds) internal {
        LibUpgradeGuardrailsStorage.Layout storage layout = LibUpgradeGuardrailsStorage.layout();
        if (layout.initialized) {
            revert UpgradeGuardrailsAlreadyInitialized();
        }
        _requireNonZeroAccount(initialUpgrader);

        layout.initialized = true;
        layout.minUpgradeDelay = minDelaySeconds;
        _grantRole(UPGRADER_ROLE, initialUpgrader);
    }

    /// @dev Reverts when `implementation` is the zero address.
    /// @param implementation The implementation to validate.
    function _requireNonZeroImplementation(address implementation) internal pure {
        if (implementation == address(0)) {
            revert UpgradeGuardrailsZeroImplementation();
        }
    }

    /// @dev Applies the upgrade operation after guardrail checks pass.
    /// @param implementation The implementation to apply.
    function _applyUpgrade(address implementation) internal virtual;
}
