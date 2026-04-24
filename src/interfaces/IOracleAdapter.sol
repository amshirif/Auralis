// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "./IERC165.sol";

/// @title IOracleAdapter
/// @notice Interface for normalized oracle adapter reads and base configuration.
interface IOracleAdapter is IERC165 {
    /// @notice Defines how reads behave when live oracle data is unavailable.
    enum FallbackMode {
        StrictRevert,
        UseConfiguredQuote
    }

    /// @notice Normalized oracle quote returned by the adapter.
    struct OracleQuote {
        int256 value;
        uint64 updatedAt;
        uint8 decimals;
    }

    /// @notice Emitted when oracle source is updated.
    /// @param previousSource Previous oracle source.
    /// @param newSource New oracle source.
    /// @param sender Account that updated the source.
    event OracleSourceUpdated(address indexed previousSource, address indexed newSource, address indexed sender);
    /// @notice Emitted when max staleness is updated.
    /// @param previousMaxStaleness Previous staleness threshold.
    /// @param newMaxStaleness New staleness threshold.
    /// @param sender Account that updated staleness.
    event OracleMaxStalenessUpdated(uint64 previousMaxStaleness, uint64 newMaxStaleness, address indexed sender);
    /// @notice Emitted when validation bounds policy is updated.
    /// @param previousMinAnswer Previous minimum accepted answer.
    /// @param previousMaxAnswer Previous maximum accepted answer.
    /// @param previousBoundsEnabled Previous bounds-enabled flag.
    /// @param newMinAnswer New minimum accepted answer.
    /// @param newMaxAnswer New maximum accepted answer.
    /// @param newBoundsEnabled New bounds-enabled flag.
    /// @param sender Account that updated bounds.
    event OracleValidationBoundsUpdated(
        int256 previousMinAnswer,
        int256 previousMaxAnswer,
        bool previousBoundsEnabled,
        int256 newMinAnswer,
        int256 newMaxAnswer,
        bool newBoundsEnabled,
        address indexed sender
    );
    /// @notice Emitted when circuit breaker is tripped.
    /// @param sender Account that tripped the breaker.
    event OracleCircuitBreakerTripped(address indexed sender);
    /// @notice Emitted when circuit breaker is reset.
    /// @param sender Account that reset the breaker.
    event OracleCircuitBreakerReset(address indexed sender);
    /// @notice Emitted when fallback mode is updated.
    /// @param previousMode Previous fallback mode.
    /// @param newMode New fallback mode.
    /// @param sender Account that updated fallback mode.
    event OracleFallbackModeUpdated(FallbackMode previousMode, FallbackMode newMode, address indexed sender);
    /// @notice Emitted when fallback quote is configured.
    /// @param value Fallback quote value.
    /// @param updatedAt Fallback quote timestamp.
    /// @param decimals Fallback quote decimals.
    /// @param sender Account that updated the fallback quote.
    event OracleFallbackQuoteUpdated(int256 value, uint64 updatedAt, uint8 decimals, address indexed sender);
    /// @notice Emitted when fallback quote is cleared.
    /// @param sender Account that cleared the fallback quote.
    event OracleFallbackQuoteCleared(address indexed sender);

    /// @notice Thrown when the oracle source address is zero.
    error OracleAdapterZeroSource();
    /// @notice Thrown when adapter initializer runs more than once.
    error OracleAdapterAlreadyInitialized();
    /// @notice Thrown when feed timestamp does not fit in uint64.
    /// @param updatedAt Feed timestamp that exceeded uint64.
    error OracleAdapterInvalidUpdatedAt(uint256 updatedAt);
    /// @notice Thrown when feed timestamp is zero.
    error OracleAdapterZeroUpdatedAt();
    /// @notice Thrown when feed timestamp is in the future.
    /// @param updatedAt Feed timestamp.
    /// @param currentTimestamp Current block timestamp.
    error OracleAdapterFutureUpdatedAt(uint64 updatedAt, uint64 currentTimestamp);
    /// @notice Thrown when quote exceeds configured staleness threshold.
    /// @param updatedAt Feed timestamp.
    /// @param currentTimestamp Current block timestamp.
    /// @param maxStaleness Maximum allowed age.
    error OracleAdapterStaleQuote(uint64 updatedAt, uint64 currentTimestamp, uint64 maxStaleness);
    /// @notice Thrown when feed round consistency is invalid.
    /// @param roundId Reported round id.
    /// @param answeredInRound Round id that produced the answer.
    error OracleAdapterInvalidRound(uint80 roundId, uint80 answeredInRound);
    /// @notice Thrown when configured bounds are invalid.
    /// @param minAnswer Minimum answer.
    /// @param maxAnswer Maximum answer.
    error OracleAdapterInvalidValidationBounds(int256 minAnswer, int256 maxAnswer);
    /// @notice Thrown when quote value falls outside configured bounds.
    /// @param answer Oracle answer.
    /// @param minAnswer Minimum accepted answer.
    /// @param maxAnswer Maximum accepted answer.
    error OracleAdapterAnswerOutOfBounds(int256 answer, int256 minAnswer, int256 maxAnswer);
    /// @notice Thrown when breaker is already active.
    error OracleAdapterBreakerAlreadyActive();
    /// @notice Thrown when breaker is already inactive.
    error OracleAdapterBreakerAlreadyInactive();
    /// @notice Thrown when strict mode is active and breaker blocks reads.
    error OracleAdapterCircuitBreakerActive();
    /// @notice Thrown when strict mode is active and live reads fail.
    error OracleAdapterLiveReadFailed();
    /// @notice Thrown when fallback mode is selected but no fallback quote is configured.
    error OracleAdapterFallbackUnavailable();
    /// @notice Thrown when configured fallback quote is invalid.
    /// @param updatedAt Fallback quote timestamp.
    error OracleAdapterInvalidFallbackQuote(uint64 updatedAt);

    /// @notice Returns the configured oracle source address.
    /// @return The oracle source contract.
    function oracleSource() external view returns (address);

    /// @notice Role that can manage oracle configuration.
    /// @return The oracle admin role identifier.
    function ORACLE_ADMIN_ROLE() external view returns (bytes32);

    /// @notice Role that can trigger emergency breaker operations.
    /// @return The oracle guardian role identifier.
    function ORACLE_GUARDIAN_ROLE() external view returns (bytes32);

    /// @notice Returns the configured max accepted staleness in seconds.
    /// @return The max staleness window.
    function maxStaleness() external view returns (uint64);

    /// @notice Returns configured answer bounds and whether bounds checks are enabled.
    /// @return minAnswer The inclusive minimum answer.
    /// @return maxAnswer The inclusive maximum answer.
    /// @return boundsEnabled True when bounds checks are enforced.
    function validationBounds() external view returns (int256 minAnswer, int256 maxAnswer, bool boundsEnabled);

    /// @notice Returns true when circuit breaker is active.
    /// @return True if breaker is active.
    function circuitBreakerActive() external view returns (bool);

    /// @notice Returns fallback mode used for unhealthy oracle reads.
    /// @return The configured fallback mode.
    function fallbackMode() external view returns (FallbackMode);

    /// @notice Returns configured fallback quote and whether it exists.
    /// @return fallbackQuotePayload The configured fallback quote.
    /// @return configured True if a fallback quote is configured.
    function fallbackQuote() external view returns (OracleQuote memory fallbackQuotePayload, bool configured);

    /// @notice Returns the latest normalized quote from the configured source.
    /// @return quote The latest normalized quote payload.
    function quote() external view returns (OracleQuote memory quote);

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

    /// @notice Trips the oracle circuit breaker.
    function tripCircuitBreaker() external;

    /// @notice Resets the oracle circuit breaker.
    function resetCircuitBreaker() external;

    /// @notice Updates fallback behavior used under unhealthy oracle conditions.
    /// @param newMode The new fallback mode.
    function setFallbackMode(FallbackMode newMode) external;

    /// @notice Sets fallback quote returned in `UseConfiguredQuote` mode.
    /// @param value Fallback quote value.
    /// @param updatedAt Fallback quote timestamp.
    /// @param decimals Fallback quote decimals.
    function setFallbackQuote(int256 value, uint64 updatedAt, uint8 decimals) external;

    /// @notice Clears configured fallback quote.
    function clearFallbackQuote() external;
}
