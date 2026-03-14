// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {
    MalformedDecimalsFeed,
    MalformedRoundDataFeed,
    OracleAdapterFixture
} from "./helpers/OracleAdapterTestHarness.sol";
import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IOracleAdapter} from "../src/interfaces/IOracleAdapter.sol";

contract SystemOracleFailureScenariosTest is OracleAdapterFixture {
    function testHealthyToStaleBreakerFallbackResetRecoverySequence() public {
        bytes32 oracleGuardianRole = adapter.ORACLE_GUARDIAN_ROLE();

        IOracleAdapter.OracleQuote memory healthyQuote = adapter.quote();
        _assertQuote(healthyQuote, 100_000_000, feedAUpdatedAt, 8, "healthy source should be used initially");

        uint64 staleUpdatedAt = currentTime - maxStaleness - 1;
        feedA.setLatestRoundData(1, 100_000_000, staleUpdatedAt, staleUpdatedAt, 1);

        VM.expectRevert(
            abi.encodeWithSelector(
                IOracleAdapter.OracleAdapterStaleQuote.selector, staleUpdatedAt, currentTime, maxStaleness
            )
        );
        adapter.quote();

        VM.prank(admin);
        adapter.setFallbackQuote(91, 888_000, 8);
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);
        VM.prank(admin);
        adapter.grantRole(oracleGuardianRole, bob);

        VM.prank(bob);
        adapter.tripCircuitBreaker();

        IOracleAdapter.OracleQuote memory breakerQuote = adapter.quote();
        _assertQuote(breakerQuote, 91, 888_000, 8, "breaker should return configured fallback quote");

        VM.prank(admin);
        adapter.resetCircuitBreaker();

        IOracleAdapter.OracleQuote memory degradedQuote = adapter.quote();
        _assertQuote(degradedQuote, 91, 888_000, 8, "stale source should still fall back after reset");

        VM.prank(admin);
        adapter.setOracleSource(address(feedB));

        IOracleAdapter.OracleQuote memory recoveredQuote = adapter.quote();
        _assertQuote(
            recoveredQuote, 2_000_000_000_000_000_000, feedBUpdatedAt, 18, "healthy rotated source should recover"
        );
    }

    function testGuardianAndAdminIncidentRolesRemainSeparatedDuringFailureHandling() public {
        bytes32 oracleAdminRole = adapter.ORACLE_ADMIN_ROLE();
        bytes32 oracleGuardianRole = adapter.ORACLE_GUARDIAN_ROLE();

        VM.prank(admin);
        adapter.grantRole(oracleGuardianRole, bob);

        VM.prank(bob);
        adapter.tripCircuitBreaker();
        assertTrue(adapter.circuitBreakerActive(), "guardian should be able to trip the breaker");

        VM.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, oracleAdminRole));
        VM.prank(bob);
        adapter.resetCircuitBreaker();

        VM.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, oracleAdminRole));
        VM.prank(bob);
        adapter.setOracleSource(address(feedB));

        VM.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, oracleAdminRole));
        VM.prank(bob);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);

        VM.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, oracleAdminRole));
        VM.prank(bob);
        adapter.setFallbackQuote(1, 1, 8);

        VM.prank(admin);
        adapter.setFallbackQuote(77, 700_000, 8);
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);
        VM.prank(admin);
        adapter.resetCircuitBreaker();

        assertFalse(adapter.circuitBreakerActive(), "admin should retain reset authority");
    }

    function testMalformedSourceRotationStillFailsClosedInStrictMode() public {
        MalformedRoundDataFeed malformedRoundFeed = new MalformedRoundDataFeed();
        MalformedDecimalsFeed malformedDecimalsFeed = new MalformedDecimalsFeed();

        VM.prank(admin);
        adapter.setOracleSource(address(malformedRoundFeed));

        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterLiveReadFailed.selector));
        adapter.quote();

        VM.prank(admin);
        adapter.setOracleSource(address(malformedDecimalsFeed));

        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterLiveReadFailed.selector));
        adapter.quote();

        VM.prank(admin);
        adapter.setOracleSource(address(feedB));

        IOracleAdapter.OracleQuote memory recoveredQuote = adapter.quote();
        _assertQuote(
            recoveredQuote,
            2_000_000_000_000_000_000,
            feedBUpdatedAt,
            18,
            "strict mode should recover only after a healthy source rotation"
        );
    }

    function testFallbackModeRequiresConfiguredQuoteAcrossFailureTransitions() public {
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);
        feedA.setRevertLatestRoundData(true);

        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterFallbackUnavailable.selector));
        adapter.quote();

        VM.prank(admin);
        adapter.setFallbackQuote(55, 777_000, 8);

        IOracleAdapter.OracleQuote memory liveFailureFallbackQuote = adapter.quote();
        _assertQuote(liveFailureFallbackQuote, 55, 777_000, 8, "configured fallback should serve failed live reads");

        VM.prank(admin);
        adapter.tripCircuitBreaker();

        IOracleAdapter.OracleQuote memory breakerFallbackQuote = adapter.quote();
        _assertQuote(breakerFallbackQuote, 55, 777_000, 8, "same fallback should serve breaker conditions");

        VM.prank(admin);
        adapter.clearFallbackQuote();

        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterFallbackUnavailable.selector));
        adapter.quote();
    }

    function testBoundsAndSourceChangesDoNotBypassValidationPolicy() public {
        VM.prank(admin);
        adapter.setValidationBounds(90_000_000, 110_000_000, true);

        IOracleAdapter.OracleQuote memory inRangeQuote = adapter.quote();
        _assertQuote(inRangeQuote, 100_000_000, feedAUpdatedAt, 8, "in-range live quote should succeed");

        VM.prank(admin);
        adapter.setOracleSource(address(feedB));

        VM.expectRevert(
            abi.encodeWithSelector(
                IOracleAdapter.OracleAdapterAnswerOutOfBounds.selector,
                int256(2_000_000_000_000_000_000),
                int256(90_000_000),
                int256(110_000_000)
            )
        );
        adapter.quote();

        VM.prank(admin);
        adapter.setFallbackQuote(101_000_000, 777_100, 8);
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);

        IOracleAdapter.OracleQuote memory fallbackQuote = adapter.quote();
        _assertQuote(fallbackQuote, 101_000_000, 777_100, 8, "fallback mode should still reject unhealthy live data");

        VM.prank(admin);
        adapter.setOracleSource(address(feedA));

        IOracleAdapter.OracleQuote memory recoveredQuote = adapter.quote();
        _assertQuote(recoveredQuote, 100_000_000, feedAUpdatedAt, 8, "healthy source should restore live reads");
    }

    function _assertQuote(
        IOracleAdapter.OracleQuote memory observed,
        int256 expectedValue,
        uint64 expectedUpdatedAt,
        uint8 expectedDecimals,
        string memory reason
    ) internal pure {
        require(
            observed.value == expectedValue && observed.updatedAt == expectedUpdatedAt
                && observed.decimals == expectedDecimals,
            reason
        );
    }
}
