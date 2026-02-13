// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IOracleFeed
/// @notice Provider-facing oracle feed interface (Chainlink-style round data).
interface IOracleFeed {
    /// @notice Returns feed decimals for answer normalization.
    /// @return The number of decimals used by the feed answer.
    function decimals() external view returns (uint8);

    /// @notice Returns the latest round data.
    /// @return roundId The round identifier.
    /// @return answer The raw signed answer.
    /// @return startedAt Timestamp when the round started.
    /// @return updatedAt Timestamp when the round was updated.
    /// @return answeredInRound The round in which the answer was computed.
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

