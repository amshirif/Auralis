// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "./IERC165.sol";

/// @title IOracleAdapter
/// @notice Interface for normalized oracle adapter reads and base configuration.
interface IOracleAdapter is IERC165 {
    /// @notice Normalized oracle quote returned by the adapter.
    struct OracleQuote {
        int256 value;
        uint64 updatedAt;
        uint8 decimals;
    }

    /// @notice Emitted when oracle source is updated.
    event OracleSourceUpdated(address indexed previousSource, address indexed newSource, address indexed sender);
    /// @notice Emitted when max staleness is updated.
    event OracleMaxStalenessUpdated(uint64 previousMaxStaleness, uint64 newMaxStaleness, address indexed sender);

    /// @notice Thrown when the oracle source address is zero.
    error OracleAdapterZeroSource();
    /// @notice Thrown when adapter initializer runs more than once.
    error OracleAdapterAlreadyInitialized();
    /// @notice Thrown when feed timestamp does not fit in uint64.
    error OracleAdapterInvalidUpdatedAt(uint256 updatedAt);

    /// @notice Returns the configured oracle source address.
    /// @return The oracle source contract.
    function oracleSource() external view returns (address);

    /// @notice Returns the configured max accepted staleness in seconds.
    /// @return The max staleness window.
    function maxStaleness() external view returns (uint64);

    /// @notice Returns the latest normalized quote from the configured source.
    /// @return quote The latest normalized quote payload.
    function quote() external view returns (OracleQuote memory quote);

    /// @notice Updates the oracle source.
    /// @param newSource The new oracle source contract.
    function setOracleSource(address newSource) external;

    /// @notice Updates the max staleness window.
    /// @param newMaxStaleness New staleness threshold in seconds.
    function setMaxStaleness(uint64 newMaxStaleness) external;
}

