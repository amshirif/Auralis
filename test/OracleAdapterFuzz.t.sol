// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {OracleAdapterFixture} from "./helpers/OracleAdapterTestHarness.sol";
import {IOracleAdapter} from "../src/interfaces/IOracleAdapter.sol";

contract OracleAdapterFuzzTest is OracleAdapterFixture {
    function testFuzzQuoteReturnsHealthyLivePayload(
        int192 answerRaw,
        uint8 decimals,
        uint16 ageRaw,
        uint8 answeredOffsetRaw
    ) public {
        uint64 age = uint64(ageRaw % (maxStaleness + 1));
        uint64 updatedAt = currentTime - age;
        int256 answer = int256(answerRaw);
        uint80 roundId = 100;
        uint80 answeredInRound = roundId + uint80(answeredOffsetRaw % 8);

        feedA.setDecimals(decimals);
        feedA.setLatestRoundData(roundId, answer, updatedAt, updatedAt, answeredInRound);

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == answer, "quote value should match live feed");
        assertTrue(readQuote.updatedAt == updatedAt, "quote timestamp should match live feed");
        assertTrue(readQuote.decimals == decimals, "quote decimals should match live feed");
    }

    function testFuzzQuoteRevertsWhenStalenessExceeded(uint16 staleExtraRaw) public {
        uint64 extraRange = currentTime - maxStaleness - 1;
        uint64 age = maxStaleness + 1 + uint64(staleExtraRaw % extraRange);
        uint64 staleUpdatedAt = currentTime - age;
        feedA.setLatestRoundData(1, 100_000_000, staleUpdatedAt, staleUpdatedAt, 1);

        VM.expectRevert(
            abi.encodeWithSelector(
                IOracleAdapter.OracleAdapterStaleQuote.selector,
                staleUpdatedAt,
                uint64(currentTime),
                uint64(maxStaleness)
            )
        );
        adapter.quote();
    }

    function testFuzzBoundsInclusiveEndpoints(int64 minAnswerRaw, uint32 spanRaw, bool useUpperBound) public {
        int256 minAnswer = int256(minAnswerRaw);
        int256 maxAnswer = minAnswer + int256(uint256(spanRaw));
        int256 answer = useUpperBound ? maxAnswer : minAnswer;

        VM.prank(admin);
        adapter.setValidationBounds(minAnswer, maxAnswer, true);
        feedA.setLatestRoundData(1, answer, feedAUpdatedAt, feedAUpdatedAt, 1);

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == answer, "inclusive bounds should accept endpoint answers");
    }

    function testFuzzOutOfBoundsFallsBackWhenConfigured(
        int64 minAnswerRaw,
        uint32 spanRaw,
        bool aboveMax,
        int192 fallbackValueRaw,
        uint8 fallbackDecimals
    ) public {
        int256 minAnswer = int256(minAnswerRaw);
        int256 maxAnswer = minAnswer + int256(uint256(spanRaw));
        int256 outOfBoundsAnswer = aboveMax ? maxAnswer + 1 : minAnswer - 1;
        int256 fallbackValue = int256(fallbackValueRaw);
        uint64 fallbackUpdatedAt = currentTime;

        VM.prank(admin);
        adapter.setValidationBounds(minAnswer, maxAnswer, true);
        VM.prank(admin);
        adapter.setFallbackQuote(fallbackValue, fallbackUpdatedAt, fallbackDecimals);
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);

        feedA.setLatestRoundData(1, outOfBoundsAnswer, feedAUpdatedAt, feedAUpdatedAt, 1);

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == fallbackValue, "out-of-bounds live answer should fall back");
        assertTrue(readQuote.updatedAt == fallbackUpdatedAt, "fallback timestamp should be returned");
        assertTrue(readQuote.decimals == fallbackDecimals, "fallback decimals should be returned");
    }

    function testFuzzCircuitBreakerReturnsConfiguredFallback(
        int192 fallbackValueRaw,
        uint64 fallbackUpdatedAtRaw,
        uint8 fallbackDecimals
    ) public {
        uint64 fallbackUpdatedAt = uint64((fallbackUpdatedAtRaw % currentTime) + 1);
        int256 fallbackValue = int256(fallbackValueRaw);

        VM.prank(admin);
        adapter.setFallbackQuote(fallbackValue, fallbackUpdatedAt, fallbackDecimals);
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);
        VM.prank(admin);
        adapter.tripCircuitBreaker();

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == fallbackValue, "breaker path should return configured fallback value");
        assertTrue(readQuote.updatedAt == fallbackUpdatedAt, "breaker path should return fallback timestamp");
        assertTrue(readQuote.decimals == fallbackDecimals, "breaker path should return fallback decimals");
    }

    function testFuzzInvalidRoundStrictRevertsThenFallbackModeUsesConfiguredQuote(
        uint80 roundIdRaw,
        int192 fallbackValueRaw,
        uint8 fallbackDecimals
    ) public {
        uint80 roundId = uint80((uint256(roundIdRaw) % 1_000_000) + 1);
        uint80 answeredInRound = roundId - 1;
        int256 fallbackValue = int256(fallbackValueRaw);
        uint64 fallbackUpdatedAt = currentTime;

        feedA.setLatestRoundData(roundId, 100_000_000, feedAUpdatedAt, feedAUpdatedAt, answeredInRound);

        VM.expectRevert(
            abi.encodeWithSelector(IOracleAdapter.OracleAdapterInvalidRound.selector, roundId, answeredInRound)
        );
        adapter.quote();

        VM.prank(admin);
        adapter.setFallbackQuote(fallbackValue, fallbackUpdatedAt, fallbackDecimals);
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == fallbackValue, "invalid round should resolve to configured fallback quote");
        assertTrue(readQuote.updatedAt == fallbackUpdatedAt, "fallback timestamp should be returned");
        assertTrue(readQuote.decimals == fallbackDecimals, "fallback decimals should be returned");
    }
}
