// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {OracleAdapterFixture} from "./helpers/OracleAdapterTestHarness.sol";
import {IOracleAdapter} from "../src/interfaces/IOracleAdapter.sol";

contract OracleAdapterValidationTest is OracleAdapterFixture {
    function testQuoteRevertsWhenUpdatedAtIsZero() public {
        feedA.setLatestRoundData(1, 100_000_000, 0, 0, 1);

        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterZeroUpdatedAt.selector));
        adapter.quote();
    }

    function testQuoteRevertsWhenUpdatedAtInFuture() public {
        uint64 futureUpdatedAt = currentTime + 1;
        feedA.setLatestRoundData(1, 100_000_000, futureUpdatedAt, futureUpdatedAt, 1);

        VM.expectRevert(
            abi.encodeWithSelector(
                IOracleAdapter.OracleAdapterFutureUpdatedAt.selector, uint64(futureUpdatedAt), uint64(currentTime)
            )
        );
        adapter.quote();
    }

    function testQuoteRevertsWhenStale() public {
        uint64 staleUpdatedAt = currentTime - maxStaleness - 1;
        feedA.setLatestRoundData(1, 100_000_000, staleUpdatedAt, staleUpdatedAt, 1);

        VM.expectRevert(
            abi.encodeWithSelector(
                IOracleAdapter.OracleAdapterStaleQuote.selector,
                uint64(staleUpdatedAt),
                uint64(currentTime),
                uint64(maxStaleness)
            )
        );
        adapter.quote();
    }

    function testZeroMaxStalenessDisablesStalenessCheck() public {
        VM.prank(admin);
        adapter.setMaxStaleness(0);
        feedA.setLatestRoundData(1, 100_000_000, 1, 1, 1);

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == 100_000_000, "quote should still read");
        assertTrue(readQuote.updatedAt == 1, "old timestamp should remain valid with disabled staleness");
    }

    function testQuoteRevertsOnInvalidRoundConsistency() public {
        feedA.setLatestRoundData(2, 100_000_000, feedAUpdatedAt, feedAUpdatedAt, 1);

        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterInvalidRound.selector, 2, 1));
        adapter.quote();
    }

    function testQuoteRevertsWhenBoundsEnabledAndAnswerBelowMin() public {
        VM.prank(admin);
        adapter.setValidationBounds(100_000_000, 2_000_000_000, true);
        feedA.setLatestRoundData(1, 99_999_999, feedAUpdatedAt, feedAUpdatedAt, 1);

        VM.expectRevert(
            abi.encodeWithSelector(
                IOracleAdapter.OracleAdapterAnswerOutOfBounds.selector, 99_999_999, 100_000_000, 2_000_000_000
            )
        );
        adapter.quote();
    }

    function testQuoteRevertsWhenBoundsEnabledAndAnswerAboveMax() public {
        VM.prank(admin);
        adapter.setValidationBounds(1, 100_000_000, true);
        feedA.setLatestRoundData(1, 100_000_001, feedAUpdatedAt, feedAUpdatedAt, 1);

        VM.expectRevert(
            abi.encodeWithSelector(IOracleAdapter.OracleAdapterAnswerOutOfBounds.selector, 100_000_001, 1, 100_000_000)
        );
        adapter.quote();
    }

    function testQuoteSucceedsWhenBoundsEnabledAndAnswerWithinRange() public {
        VM.prank(admin);
        adapter.setValidationBounds(1, 100_000_000, true);
        feedA.setLatestRoundData(1, 100_000_000, feedAUpdatedAt, feedAUpdatedAt, 1);

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == 100_000_000, "in-range answer should be accepted");
    }

    function testQuoteIgnoresBoundsWhenDisabled() public {
        VM.prank(admin);
        adapter.setValidationBounds(1, 100_000_000, false);
        feedA.setLatestRoundData(1, 1_000_000_000_000, feedAUpdatedAt, feedAUpdatedAt, 1);

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == 1_000_000_000_000, "out-of-range answer should pass when bounds are disabled");
    }
}
