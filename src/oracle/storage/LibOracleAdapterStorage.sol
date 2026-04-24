// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title LibOracleAdapterStorage
/// @notice Storage layout for oracle adapter modules (diamond-ready).
library LibOracleAdapterStorage {
    /// @dev Unique namespaced storage slot; do not reuse or rename without migration review.
    bytes32 internal constant STORAGE_SLOT = keccak256("auralis.oracle-adapter.storage");

    /// @notice Oracle adapter storage layout.
    struct Layout {
        bool initialized;
        address source;
        uint64 maxStaleness;
        int256 minAnswer;
        int256 maxAnswer;
        bool boundsEnabled;
        bool breakerActive;
        uint8 fallbackMode;
        bool hasFallbackQuote;
        int256 fallbackValue;
        uint64 fallbackUpdatedAt;
        uint8 fallbackDecimals;
    }

    /// @notice Returns the storage layout for oracle adapter state.
    /// @return l The storage layout pointer.
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
