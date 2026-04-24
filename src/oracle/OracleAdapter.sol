// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "../access/AccessControl.sol";
import {IOracleAdapter} from "../interfaces/IOracleAdapter.sol";
import {IOracleFeed} from "../interfaces/IOracleFeed.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {LibOracleAdapterStorage} from "./storage/LibOracleAdapterStorage.sol";

/// @title OracleAdapter
/// @notice Base oracle adapter with normalized quote reads and upgrade-safe storage.
/// @dev Uses dedicated oracle roles for least-privilege controls.
abstract contract OracleAdapter is AccessControl, IOracleAdapter {
    /// @notice Role allowed to manage oracle configuration and fallback policy.
    bytes32 public constant ORACLE_ADMIN_ROLE = keccak256("ORACLE_ADMIN_ROLE");
    /// @notice Role allowed to trip the oracle circuit breaker.
    bytes32 public constant ORACLE_GUARDIAN_ROLE = keccak256("ORACLE_GUARDIAN_ROLE");

    /// @param initialAdmin The account to receive DEFAULT_ADMIN_ROLE.
    /// @param initialSource The initial oracle feed source.
    /// @param initialMaxStaleness The initial max staleness threshold.
    constructor(address initialAdmin, address initialSource, uint64 initialMaxStaleness) AccessControl(initialAdmin) {
        _initializeOracleRoles(initialAdmin, initialAdmin);
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

    /// @notice Returns configured answer bounds and whether bounds checks are enabled.
    /// @return minAnswer The inclusive minimum answer.
    /// @return maxAnswer The inclusive maximum answer.
    /// @return boundsEnabled True when bounds checks are enforced.
    function validationBounds() public view returns (int256 minAnswer, int256 maxAnswer, bool boundsEnabled) {
        LibOracleAdapterStorage.Layout storage layout = LibOracleAdapterStorage.layout();
        return (layout.minAnswer, layout.maxAnswer, layout.boundsEnabled);
    }

    /// @notice Returns true when circuit breaker is active.
    /// @return True if breaker is active.
    function circuitBreakerActive() public view returns (bool) {
        return LibOracleAdapterStorage.layout().breakerActive;
    }

    /// @notice Returns fallback mode used for unhealthy oracle reads.
    /// @return The configured fallback mode.
    function fallbackMode() public view returns (FallbackMode) {
        return FallbackMode(LibOracleAdapterStorage.layout().fallbackMode);
    }

    /// @notice Returns configured fallback quote and whether it exists.
    /// @return fallbackQuotePayload The configured fallback quote.
    /// @return configured True if a fallback quote is configured.
    function fallbackQuote() public view returns (OracleQuote memory fallbackQuotePayload, bool configured) {
        LibOracleAdapterStorage.Layout storage layout = LibOracleAdapterStorage.layout();
        fallbackQuotePayload = OracleQuote({
            value: layout.fallbackValue, updatedAt: layout.fallbackUpdatedAt, decimals: layout.fallbackDecimals
        });
        configured = layout.hasFallbackQuote;
    }

    /// @notice Returns the latest normalized quote from the configured source.
    /// @dev Applies breaker and fallback policy for unhealthy conditions.
    /// @return quotePayload The latest normalized quote payload.
    function quote() public view returns (OracleQuote memory quotePayload) {
        if (circuitBreakerActive()) {
            return _resolveFallbackOrRevert(true);
        }

        if (fallbackMode() == FallbackMode.StrictRevert) {
            return _readLiveQuoteStrict();
        }

        (bool liveReadSuccess, OracleQuote memory liveQuote) = _tryReadLiveQuote();
        if (liveReadSuccess) {
            return liveQuote;
        }
        return _resolveFallbackOrRevert(false);
    }

    /// @notice Updates the oracle source.
    /// @dev Caller must have ORACLE_ADMIN_ROLE.
    /// @param newSource The new oracle source contract.
    function setOracleSource(address newSource) external onlyRole(ORACLE_ADMIN_ROLE) {
        _setOracleSource(newSource);
    }

    /// @notice Updates the max staleness window.
    /// @dev Caller must have ORACLE_ADMIN_ROLE.
    /// @param newMaxStaleness New staleness threshold in seconds.
    function setMaxStaleness(uint64 newMaxStaleness) external onlyRole(ORACLE_ADMIN_ROLE) {
        _setMaxStaleness(newMaxStaleness);
    }

    /// @notice Updates answer bounds validation policy.
    /// @dev Caller must have ORACLE_ADMIN_ROLE.
    /// @param newMinAnswer The inclusive minimum answer.
    /// @param newMaxAnswer The inclusive maximum answer.
    /// @param newBoundsEnabled True to enforce bounds during reads.
    function setValidationBounds(int256 newMinAnswer, int256 newMaxAnswer, bool newBoundsEnabled)
        external
        onlyRole(ORACLE_ADMIN_ROLE)
    {
        _setValidationBounds(newMinAnswer, newMaxAnswer, newBoundsEnabled);
    }

    /// @notice Trips the oracle circuit breaker.
    /// @dev Caller must have ORACLE_GUARDIAN_ROLE.
    function tripCircuitBreaker() external onlyRole(ORACLE_GUARDIAN_ROLE) {
        LibOracleAdapterStorage.Layout storage layout = LibOracleAdapterStorage.layout();
        if (layout.breakerActive) {
            revert OracleAdapterBreakerAlreadyActive();
        }
        layout.breakerActive = true;
        emit OracleCircuitBreakerTripped(msg.sender);
    }

    /// @notice Resets the oracle circuit breaker.
    /// @dev Caller must have ORACLE_ADMIN_ROLE.
    function resetCircuitBreaker() external onlyRole(ORACLE_ADMIN_ROLE) {
        LibOracleAdapterStorage.Layout storage layout = LibOracleAdapterStorage.layout();
        if (!layout.breakerActive) {
            revert OracleAdapterBreakerAlreadyInactive();
        }
        layout.breakerActive = false;
        emit OracleCircuitBreakerReset(msg.sender);
    }

    /// @notice Updates fallback behavior used under unhealthy oracle conditions.
    /// @dev Caller must have ORACLE_ADMIN_ROLE.
    /// @param newMode The new fallback mode.
    function setFallbackMode(FallbackMode newMode) external onlyRole(ORACLE_ADMIN_ROLE) {
        LibOracleAdapterStorage.Layout storage layout = LibOracleAdapterStorage.layout();
        FallbackMode previousMode = FallbackMode(layout.fallbackMode);
        layout.fallbackMode = uint8(newMode);
        emit OracleFallbackModeUpdated(previousMode, newMode, msg.sender);
    }

    /// @notice Sets fallback quote returned in `UseConfiguredQuote` mode.
    /// @dev Caller must have ORACLE_ADMIN_ROLE.
    /// @param value Fallback quote value.
    /// @param updatedAt Fallback quote timestamp.
    /// @param decimals Fallback quote decimals.
    function setFallbackQuote(int256 value, uint64 updatedAt, uint8 decimals) external onlyRole(ORACLE_ADMIN_ROLE) {
        _setFallbackQuote(value, updatedAt, decimals);
    }

    /// @notice Clears configured fallback quote.
    /// @dev Caller must have ORACLE_ADMIN_ROLE.
    function clearFallbackQuote() external onlyRole(ORACLE_ADMIN_ROLE) {
        LibOracleAdapterStorage.Layout storage layout = LibOracleAdapterStorage.layout();
        layout.hasFallbackQuote = false;
        layout.fallbackValue = 0;
        layout.fallbackUpdatedAt = 0;
        layout.fallbackDecimals = 0;
        emit OracleFallbackQuoteCleared(msg.sender);
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
        layout.minAnswer = type(int256).min;
        layout.maxAnswer = type(int256).max;
        layout.boundsEnabled = false;
        layout.fallbackMode = uint8(FallbackMode.StrictRevert);
        _setOracleSource(initialSource);
        _setMaxStaleness(initialMaxStaleness);
    }

    /// @dev Initializes oracle role hierarchy and initial role assignments.
    /// @param initialOracleAdmin Account to receive ORACLE_ADMIN_ROLE.
    /// @param initialOracleGuardian Account to receive ORACLE_GUARDIAN_ROLE.
    function _initializeOracleRoles(address initialOracleAdmin, address initialOracleGuardian) internal {
        _setRoleAdmin(ORACLE_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ORACLE_GUARDIAN_ROLE, ORACLE_ADMIN_ROLE);
        _grantRole(ORACLE_ADMIN_ROLE, initialOracleAdmin);
        _grantRole(ORACLE_GUARDIAN_ROLE, initialOracleGuardian);
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

    /// @dev Sets bounds validation policy.
    /// @param newMinAnswer The inclusive minimum answer.
    /// @param newMaxAnswer The inclusive maximum answer.
    /// @param newBoundsEnabled True to enforce bounds during reads.
    function _setValidationBounds(int256 newMinAnswer, int256 newMaxAnswer, bool newBoundsEnabled) internal {
        if (newMinAnswer > newMaxAnswer) {
            revert OracleAdapterInvalidValidationBounds(newMinAnswer, newMaxAnswer);
        }

        LibOracleAdapterStorage.Layout storage layout = LibOracleAdapterStorage.layout();
        int256 previousMinAnswer = layout.minAnswer;
        int256 previousMaxAnswer = layout.maxAnswer;
        bool previousBoundsEnabled = layout.boundsEnabled;

        layout.minAnswer = newMinAnswer;
        layout.maxAnswer = newMaxAnswer;
        layout.boundsEnabled = newBoundsEnabled;

        emit OracleValidationBoundsUpdated(
            previousMinAnswer,
            previousMaxAnswer,
            previousBoundsEnabled,
            newMinAnswer,
            newMaxAnswer,
            newBoundsEnabled,
            msg.sender
        );
    }

    /// @dev Sets fallback quote configuration.
    /// @param value Fallback quote value.
    /// @param updatedAt Fallback quote timestamp.
    /// @param decimals Fallback quote decimals.
    function _setFallbackQuote(int256 value, uint64 updatedAt, uint8 decimals) internal {
        if (updatedAt == 0) {
            revert OracleAdapterInvalidFallbackQuote(updatedAt);
        }

        LibOracleAdapterStorage.Layout storage layout = LibOracleAdapterStorage.layout();
        layout.hasFallbackQuote = true;
        layout.fallbackValue = value;
        layout.fallbackUpdatedAt = updatedAt;
        layout.fallbackDecimals = decimals;
        emit OracleFallbackQuoteUpdated(value, updatedAt, decimals, msg.sender);
    }

    /// @dev Reads live oracle data using strict validation semantics.
    /// @dev Reverts with validation errors or {OracleAdapterLiveReadFailed} on source call failures.
    /// @return quotePayload The validated live quote payload.
    function _readLiveQuoteStrict() internal view returns (OracleQuote memory quotePayload) {
        address source = oracleSource();
        (bool roundDataCallSuccess, bytes memory roundDataRaw) =
            source.staticcall(abi.encodeWithSelector(IOracleFeed.latestRoundData.selector));
        if (!roundDataCallSuccess || roundDataRaw.length != 160) {
            revert OracleAdapterLiveReadFailed();
        }
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            abi.decode(roundDataRaw, (uint80, int256, uint256, uint256, uint80));

        uint64 normalizedUpdatedAt = _validateRoundData(roundId, answer, updatedAt, answeredInRound);
        (bool decimalsCallSuccess, bytes memory decimalsRaw) =
            source.staticcall(abi.encodeWithSelector(IOracleFeed.decimals.selector));
        if (!decimalsCallSuccess || decimalsRaw.length != 32) {
            revert OracleAdapterLiveReadFailed();
        }
        uint8 decimals = abi.decode(decimalsRaw, (uint8));

        quotePayload = OracleQuote({value: answer, updatedAt: normalizedUpdatedAt, decimals: decimals});
    }

    /// @dev Attempts to read and validate live oracle data without reverting.
    /// @return success True when read/validation succeeds.
    /// @return quotePayload Normalized quote payload.
    function _tryReadLiveQuote() internal view returns (bool success, OracleQuote memory quotePayload) {
        address source = oracleSource();
        (bool roundDataCallSuccess, bytes memory roundDataRaw) =
            source.staticcall(abi.encodeWithSelector(IOracleFeed.latestRoundData.selector));
        if (!roundDataCallSuccess || roundDataRaw.length != 160) {
            return (false, quotePayload);
        }

        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            abi.decode(roundDataRaw, (uint80, int256, uint256, uint256, uint80));
        if (!_isRoundDataValid(roundId, answer, updatedAt, answeredInRound)) {
            return (false, quotePayload);
        }

        (bool decimalsCallSuccess, bytes memory decimalsRaw) =
            source.staticcall(abi.encodeWithSelector(IOracleFeed.decimals.selector));
        if (!decimalsCallSuccess || decimalsRaw.length != 32) {
            return (false, quotePayload);
        }
        uint8 decimals = abi.decode(decimalsRaw, (uint8));

        // casting to `uint64` is safe because `_isRoundDataValid` enforces bounds.
        // forge-lint: disable-next-line(unsafe-typecast)
        quotePayload = OracleQuote({value: answer, updatedAt: uint64(updatedAt), decimals: decimals});
        return (true, quotePayload);
    }

    /// @dev Checks whether returned round data passes baseline validity rules.
    /// @param roundId The source round ID.
    /// @param answer The source answer.
    /// @param updatedAt The round update timestamp.
    /// @param answeredInRound The round in which the answer was computed.
    /// @return True when data is valid for fallback mode reads.
    function _isRoundDataValid(uint80 roundId, int256 answer, uint256 updatedAt, uint80 answeredInRound)
        internal
        view
        returns (bool)
    {
        if (updatedAt == 0 || updatedAt > type(uint64).max) {
            return false;
        }

        uint256 currentTimestamp = block.timestamp;
        if (updatedAt > currentTimestamp) {
            return false;
        }

        uint256 allowedStaleness = maxStaleness();
        if (allowedStaleness != 0 && currentTimestamp - updatedAt > allowedStaleness) {
            return false;
        }

        if (answeredInRound < roundId) {
            return false;
        }

        if (!_isAnswerWithinBounds(answer)) {
            return false;
        }

        return true;
    }

    /// @dev Validates round data freshness, consistency, and optional bounds.
    /// @param roundId The returned round identifier.
    /// @param answer The returned answer value.
    /// @param updatedAt The returned update timestamp.
    /// @param answeredInRound The returned answered-in-round identifier.
    /// @return normalizedUpdatedAt The `updatedAt` normalized to `uint64`.
    function _validateRoundData(uint80 roundId, int256 answer, uint256 updatedAt, uint80 answeredInRound)
        internal
        view
        returns (uint64 normalizedUpdatedAt)
    {
        if (updatedAt > type(uint64).max) {
            revert OracleAdapterInvalidUpdatedAt(updatedAt);
        }
        // casting to `uint64` is safe because the overflow path is rejected above.
        // forge-lint: disable-next-line(unsafe-typecast)
        normalizedUpdatedAt = uint64(updatedAt);
        if (normalizedUpdatedAt == 0) {
            revert OracleAdapterZeroUpdatedAt();
        }

        uint64 currentTimestamp = uint64(block.timestamp);
        if (normalizedUpdatedAt > currentTimestamp) {
            revert OracleAdapterFutureUpdatedAt(normalizedUpdatedAt, currentTimestamp);
        }

        uint64 allowedStaleness = maxStaleness();
        if (allowedStaleness != 0 && currentTimestamp - normalizedUpdatedAt > allowedStaleness) {
            revert OracleAdapterStaleQuote(normalizedUpdatedAt, currentTimestamp, allowedStaleness);
        }

        if (answeredInRound < roundId) {
            revert OracleAdapterInvalidRound(roundId, answeredInRound);
        }

        _validateAnswerBounds(answer);
    }

    /// @dev Returns true when `answer` is inside configured bounds.
    /// @param answer The oracle answer to validate.
    /// @return True when answer is in range or bounds are disabled.
    function _isAnswerWithinBounds(int256 answer) internal view returns (bool) {
        (int256 minAnswer, int256 maxAnswer, bool boundsEnabled) = validationBounds();
        return !boundsEnabled || (answer >= minAnswer && answer <= maxAnswer);
    }

    /// @dev Reverts when `answer` is outside configured bounds while bounds are enabled.
    /// @param answer The oracle answer to validate.
    function _validateAnswerBounds(int256 answer) internal view {
        if (!_isAnswerWithinBounds(answer)) {
            (int256 minAnswer, int256 maxAnswer,) = validationBounds();
            revert OracleAdapterAnswerOutOfBounds(answer, minAnswer, maxAnswer);
        }
    }

    /// @dev Resolves fallback policy, reverting in strict mode.
    /// @param breakerTriggered True when fallback resolution is due to active breaker.
    /// @return quotePayload The fallback quote payload.
    function _resolveFallbackOrRevert(bool breakerTriggered) internal view returns (OracleQuote memory quotePayload) {
        if (fallbackMode() == FallbackMode.StrictRevert) {
            if (breakerTriggered) {
                revert OracleAdapterCircuitBreakerActive();
            }
            revert OracleAdapterLiveReadFailed();
        }

        (OracleQuote memory configuredFallback, bool configured) = fallbackQuote();
        if (!configured) {
            revert OracleAdapterFallbackUnavailable();
        }
        return configuredFallback;
    }
}
