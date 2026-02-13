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

    /// @notice Returns configured answer bounds and whether bounds checks are enabled.
    /// @return minAnswer The inclusive minimum answer.
    /// @return maxAnswer The inclusive maximum answer.
    /// @return boundsEnabled True when bounds checks are enforced.
    function validationBounds() public view returns (int256 minAnswer, int256 maxAnswer, bool boundsEnabled) {
        LibOracleAdapterStorage.Layout storage layout = LibOracleAdapterStorage.layout();
        return (layout.minAnswer, layout.maxAnswer, layout.boundsEnabled);
    }

    /// @notice Returns the latest normalized quote from the configured source.
    /// @return quotePayload The latest normalized quote payload.
    function quote() public view returns (OracleQuote memory quotePayload) {
        address source = oracleSource();
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            IOracleFeed(source).latestRoundData();
        uint64 normalizedUpdatedAt = _validateRoundData(roundId, answer, updatedAt, answeredInRound);

        quotePayload =
            OracleQuote({value: answer, updatedAt: normalizedUpdatedAt, decimals: IOracleFeed(source).decimals()});
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

    /// @notice Updates answer bounds validation policy.
    /// @dev Caller must have DEFAULT_ADMIN_ROLE.
    /// @param newMinAnswer The inclusive minimum answer.
    /// @param newMaxAnswer The inclusive maximum answer.
    /// @param newBoundsEnabled True to enforce bounds during reads.
    function setValidationBounds(int256 newMinAnswer, int256 newMaxAnswer, bool newBoundsEnabled)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setValidationBounds(newMinAnswer, newMaxAnswer, newBoundsEnabled);
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

    /// @dev Reverts when `answer` is outside configured bounds while bounds are enabled.
    /// @param answer The oracle answer to validate.
    function _validateAnswerBounds(int256 answer) internal view {
        (int256 minAnswer, int256 maxAnswer, bool boundsEnabled) = validationBounds();
        if (boundsEnabled && (answer < minAnswer || answer > maxAnswer)) {
            revert OracleAdapterAnswerOutOfBounds(answer, minAnswer, maxAnswer);
        }
    }
}
