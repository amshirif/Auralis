// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {
    MalformedDecimalsFeed,
    MalformedRoundDataFeed,
    OracleAdapterFixture
} from "./helpers/OracleAdapterTestHarness.sol";
import {IOracleAdapter} from "../src/interfaces/IOracleAdapter.sol";

contract OracleAdapterCircuitBreakerTest is OracleAdapterFixture {
    function testQuoteRevertsWhenBreakerActiveInStrictMode() public {
        VM.prank(admin);
        adapter.tripCircuitBreaker();

        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterCircuitBreakerActive.selector));
        adapter.quote();
    }

    function testQuoteUsesFallbackWhenBreakerActiveAndFallbackModeEnabled() public {
        VM.prank(admin);
        adapter.setFallbackQuote(123, 888_000, 8);
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);
        VM.prank(admin);
        adapter.tripCircuitBreaker();

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == 123, "breaker should return fallback value");
        assertTrue(readQuote.updatedAt == 888_000, "breaker should return fallback timestamp");
        assertTrue(readQuote.decimals == 8, "breaker should return fallback decimals");
    }

    function testQuoteRevertsWhenLiveReadFailsInStrictMode() public {
        feedA.setRevertLatestRoundData(true);

        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterLiveReadFailed.selector));
        adapter.quote();
    }

    function testQuoteUsesFallbackWhenLiveReadFails() public {
        VM.prank(admin);
        adapter.setFallbackQuote(55, 777_000, 8);
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);
        feedA.setRevertLatestRoundData(true);

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == 55, "fallback value should be used");
        assertTrue(readQuote.updatedAt == 777_000, "fallback updatedAt should be used");
        assertTrue(readQuote.decimals == 8, "fallback decimals should be used");
    }

    function testQuoteUsesFallbackWhenDecimalsCallReverts() public {
        VM.prank(admin);
        adapter.setFallbackQuote(44, 770_000, 8);
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);
        feedA.setRevertDecimals(true);

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == 44, "fallback value should be used");
        assertTrue(readQuote.updatedAt == 770_000, "fallback updatedAt should be used");
        assertTrue(readQuote.decimals == 8, "fallback decimals should be used");
    }

    function testQuoteUsesFallbackWhenRoundDataPayloadMalformed() public {
        MalformedRoundDataFeed malformedFeed = new MalformedRoundDataFeed();

        VM.prank(admin);
        adapter.setOracleSource(address(malformedFeed));
        VM.prank(admin);
        adapter.setFallbackQuote(45, 771_000, 8);
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == 45, "fallback value should be used");
        assertTrue(readQuote.updatedAt == 771_000, "fallback updatedAt should be used");
        assertTrue(readQuote.decimals == 8, "fallback decimals should be used");
    }

    function testQuoteUsesFallbackWhenDecimalsPayloadMalformed() public {
        MalformedDecimalsFeed malformedFeed = new MalformedDecimalsFeed();

        VM.prank(admin);
        adapter.setOracleSource(address(malformedFeed));
        VM.prank(admin);
        adapter.setFallbackQuote(46, 772_000, 8);
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == 46, "fallback value should be used");
        assertTrue(readQuote.updatedAt == 772_000, "fallback updatedAt should be used");
        assertTrue(readQuote.decimals == 8, "fallback decimals should be used");
    }

    function testQuoteRevertsWhenFallbackModeEnabledWithoutConfiguredFallback() public {
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);
        feedA.setRevertLatestRoundData(true);

        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterFallbackUnavailable.selector));
        adapter.quote();
    }

    function testQuoteTreatsStaleDataAsUnhealthy() public {
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);
        VM.prank(admin);
        adapter.setFallbackQuote(66, 700_000, 8);

        uint64 staleUpdatedAt = currentTime - maxStaleness - 1;
        feedA.setLatestRoundData(1, 100_000_000, staleUpdatedAt, staleUpdatedAt, 1);

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == 66, "stale live quote should fall back");
    }

    function testQuoteTreatsFutureDataAsUnhealthy() public {
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);
        VM.prank(admin);
        adapter.setFallbackQuote(77, 700_000, 8);

        uint64 futureUpdatedAt = currentTime + 1;
        feedA.setLatestRoundData(1, 100_000_000, futureUpdatedAt, futureUpdatedAt, 1);

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == 77, "future live quote should fall back");
    }

    function testQuoteTreatsInvalidRoundAsUnhealthy() public {
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);
        VM.prank(admin);
        adapter.setFallbackQuote(88, 700_000, 8);
        feedA.setLatestRoundData(2, 100_000_000, feedAUpdatedAt, feedAUpdatedAt, 1);

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == 88, "invalid round should fall back");
    }

    function testRecoveredStateUsesLiveQuoteAfterBreakerReset() public {
        VM.prank(admin);
        adapter.setFallbackQuote(99, 700_000, 8);
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);
        VM.prank(admin);
        adapter.tripCircuitBreaker();

        IOracleAdapter.OracleQuote memory degradedQuote = adapter.quote();
        assertTrue(degradedQuote.value == 99, "degraded quote should use fallback");

        VM.prank(admin);
        adapter.resetCircuitBreaker();
        feedA.setRevertLatestRoundData(false);
        feedA.setLatestRoundData(1, 111_000_000, feedAUpdatedAt, feedAUpdatedAt, 1);

        IOracleAdapter.OracleQuote memory recoveredQuote = adapter.quote();
        assertTrue(recoveredQuote.value == 111_000_000, "recovered quote should use live source");
    }
}
