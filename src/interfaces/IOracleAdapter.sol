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
    /// @notice Emitted when validation bounds policy is updated.
    event OracleValidationBoundsUpdated(
        int256 previousMinAnswer,
        int256 previousMaxAnswer,
        bool previousBoundsEnabled,
        int256 newMinAnswer,
        int256 newMaxAnswer,
        bool newBoundsEnabled,
        address indexed sender
    );

    /// @notice Thrown when the oracle source address is zero.
    error OracleAdapterZeroSource();
    /// @notice Thrown when adapter initializer runs more than once.
    error OracleAdapterAlreadyInitialized();
    /// @notice Thrown when feed timestamp does not fit in uint64.
    error OracleAdapterInvalidUpdatedAt(uint256 updatedAt);
    /// @notice Thrown when feed timestamp is zero.
    error OracleAdapterZeroUpdatedAt();
    /// @notice Thrown when feed timestamp is in the future.
    error OracleAdapterFutureUpdatedAt(uint64 updatedAt, uint64 currentTimestamp);
    /// @notice Thrown when quote exceeds configured staleness threshold.
    error OracleAdapterStaleQuote(uint64 updatedAt, uint64 currentTimestamp, uint64 maxStaleness);
    /// @notice Thrown when feed round consistency is invalid.
    error OracleAdapterInvalidRound(uint80 roundId, uint80 answeredInRound);
    /// @notice Thrown when configured bounds are invalid.
    error OracleAdapterInvalidValidationBounds(int256 minAnswer, int256 maxAnswer);
    /// @notice Thrown when quote value falls outside configured bounds.
    error OracleAdapterAnswerOutOfBounds(int256 answer, int256 minAnswer, int256 maxAnswer);

    /// @notice Returns the configured oracle source address.
    /// @return The oracle source contract.
    function oracleSource() external view returns (address);

    /// @notice Returns the configured max accepted staleness in seconds.
    /// @return The max staleness window.
    function maxStaleness() external view returns (uint64);

    /// @notice Returns the latest normalized quote from the configured source.
    /// @return quote The latest normalized quote payload.
    function quote() external view returns (OracleQuote memory quote);

    /// @notice Returns configured answer bounds and whether bounds checks are enabled.
    /// @return minAnswer The inclusive minimum answer.
    /// @return maxAnswer The inclusive maximum answer.
    /// @return boundsEnabled True when bounds checks are enforced.
    function validationBounds() external view returns (int256 minAnswer, int256 maxAnswer, bool boundsEnabled);

    /// @notice Updates the oracle source.
    /// @param newSource The new oracle source contract.
    function setOracleSource(address newSource) external;

    /// @notice Updates the max staleness window.
    /// @param newMaxStaleness New staleness threshold in seconds.
    function setMaxStaleness(uint64 newMaxStaleness) external;

    /// @notice Updates answer bounds validation policy.
    /// @param newMinAnswer The inclusive minimum answer.
    /// @param newMaxAnswer The inclusive maximum answer.
    /// @param newBoundsEnabled True to enforce bounds during reads.
    function setValidationBounds(int256 newMinAnswer, int256 newMaxAnswer, bool newBoundsEnabled) external;
}
