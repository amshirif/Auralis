// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title LibUpgradeGuardrailsStorage
/// @notice Namespaced storage layout for opt-in upgrade guardrails modules.
library LibUpgradeGuardrailsStorage {
    /// @dev Storage slot for upgrade guardrails layout.
    bytes32 internal constant STORAGE_SLOT = keccak256("auralis.upgrade-guardrails.storage");

    /// @notice Queued upgrade metadata.
    struct UpgradeIntent {
        address implementation;
        uint64 executeAfter;
        bool exists;
    }

    /// @notice Upgrade guardrails storage layout.
    struct Layout {
        bool initialized;
        uint64 minUpgradeDelay;
        UpgradeIntent intent;
    }

    /// @notice Returns the storage layout for upgrade guardrails state.
    /// @return l The storage layout pointer.
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
