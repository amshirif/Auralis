// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "../access/AccessControl.sol";
import {IOracleAdapter} from "../interfaces/IOracleAdapter.sol";
import {IOracleFeed} from "../interfaces/IOracleFeed.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {LibOracleAdapterStorage} from "./storage/LibOracleAdapterStorage.sol";

/// @title OracleAdapter
/// @notice Base oracle adapter with normalized quote reads and upgrade-safe storage.
/// @dev Uses DEFAULT_ADMIN_ROLE for baseline configuration controls.
abstract contract OracleAdapter is AccessControl, IOracleAdapter {
    /// @param initialAdmin The account to receive DEFAULT_ADMIN_ROLE.
    /// @param initialSource The initial oracle feed source.
    /// @param initialMaxStaleness The initial max staleness threshold.
    constructor(address initialAdmin, address initialSource, uint64 initialMaxStaleness) AccessControl(initialAdmin) {
        _initializeOracleAdapter(initialSource, initialMaxStaleness);
    }

    /// @notice Returns the configured oracle source address.
    /// @return The oracle source contract.
    function oracleSource() public view returns (address) {
        return LibOracleAdapterStorage.layout().source;
    }

    /// @notice Returns the configured max accepted staleness in seconds.
    /// @return The max staleness window.
    function maxStaleness() public view returns (uint64) {
        return LibOracleAdapterStorage.layout().maxStaleness;
    }

    /// @notice Returns the latest normalized quote from the configured source.
    /// @return quotePayload The latest normalized quote payload.
    function quote() public view returns (OracleQuote memory quotePayload) {
        (, int256 answer,, uint256 updatedAt,) = IOracleFeed(oracleSource()).latestRoundData();
        if (updatedAt > type(uint64).max) {
            revert OracleAdapterInvalidUpdatedAt(updatedAt);
        }

        quotePayload = OracleQuote({
            value: answer, updatedAt: uint64(updatedAt), decimals: IOracleFeed(oracleSource()).decimals()
        });
    }

    /// @notice Updates the oracle source.
    /// @dev Caller must have DEFAULT_ADMIN_ROLE.
    /// @param newSource The new oracle source contract.
    function setOracleSource(address newSource) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setOracleSource(newSource);
    }

    /// @notice Updates the max staleness window.
    /// @dev Caller must have DEFAULT_ADMIN_ROLE.
    /// @param newMaxStaleness New staleness threshold in seconds.
    function setMaxStaleness(uint64 newMaxStaleness) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMaxStaleness(newMaxStaleness);
    }

    /// @notice Returns true if this contract implements `interfaceId`.
    /// @param interfaceId The interface identifier.
    /// @return True if the interface is supported.
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, IERC165) returns (bool) {
        return interfaceId == type(IOracleAdapter).interfaceId || interfaceId == type(IERC165).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @dev Initializes oracle adapter storage (diamond-ready).
    /// @param initialSource The initial oracle feed source.
    /// @param initialMaxStaleness The initial max staleness threshold.
    function _initializeOracleAdapter(address initialSource, uint64 initialMaxStaleness) internal {
        LibOracleAdapterStorage.Layout storage layout = LibOracleAdapterStorage.layout();
        if (layout.initialized) {
            revert OracleAdapterAlreadyInitialized();
        }
        layout.initialized = true;
        _setOracleSource(initialSource);
        _setMaxStaleness(initialMaxStaleness);
    }

    /// @dev Sets oracle source after validation.
    /// @param newSource The new oracle source contract.
    function _setOracleSource(address newSource) internal {
        if (newSource == address(0)) {
            revert OracleAdapterZeroSource();
        }

        LibOracleAdapterStorage.Layout storage layout = LibOracleAdapterStorage.layout();
        address previousSource = layout.source;
        layout.source = newSource;
        emit OracleSourceUpdated(previousSource, newSource, msg.sender);
    }

    /// @dev Sets max staleness threshold.
    /// @param newMaxStaleness New staleness threshold in seconds.
    function _setMaxStaleness(uint64 newMaxStaleness) internal {
        LibOracleAdapterStorage.Layout storage layout = LibOracleAdapterStorage.layout();
        uint64 previousMaxStaleness = layout.maxStaleness;
        layout.maxStaleness = newMaxStaleness;
        emit OracleMaxStalenessUpdated(previousMaxStaleness, newMaxStaleness, msg.sender);
    }
}

