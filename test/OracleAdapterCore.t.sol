// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {OracleAdapterFixture, OracleAdapterHarness} from "./helpers/OracleAdapterTestHarness.sol";
import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IAccessControlTime} from "../src/interfaces/IAccessControlTime.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IOracleAdapter} from "../src/interfaces/IOracleAdapter.sol";

contract OracleAdapterCoreTest is OracleAdapterFixture {
    event OracleSourceUpdated(address indexed previousSource, address indexed newSource, address indexed sender);
    event OracleMaxStalenessUpdated(uint64 previousMaxStaleness, uint64 newMaxStaleness, address indexed sender);
    event OracleValidationBoundsUpdated(
        int256 previousMinAnswer,
        int256 previousMaxAnswer,
        bool previousBoundsEnabled,
        int256 newMinAnswer,
        int256 newMaxAnswer,
        bool newBoundsEnabled,
        address indexed sender
    );
    event OracleCircuitBreakerTripped(address indexed sender);
    event OracleCircuitBreakerReset(address indexed sender);
    event OracleFallbackModeUpdated(
        IOracleAdapter.FallbackMode previousMode, IOracleAdapter.FallbackMode newMode, address indexed sender
    );
    event OracleFallbackQuoteUpdated(int256 value, uint64 updatedAt, uint8 decimals, address indexed sender);
    event OracleFallbackQuoteCleared(address indexed sender);

    function testInitialConfig() public view {
        assertTrue(adapter.oracleSource() == address(feedA), "initial source should match constructor");
        assertTrue(adapter.maxStaleness() == maxStaleness, "initial max staleness should match constructor");
        (int256 minAnswer, int256 maxAnswer, bool boundsEnabled) = adapter.validationBounds();
        assertTrue(minAnswer == type(int256).min, "initial min should be int256 min");
        assertTrue(maxAnswer == type(int256).max, "initial max should be int256 max");
        assertFalse(boundsEnabled, "bounds should start disabled");
        assertFalse(adapter.circuitBreakerActive(), "breaker should start inactive");
        assertTrue(
            adapter.fallbackMode() == IOracleAdapter.FallbackMode.StrictRevert, "fallback mode should start strict"
        );
        (, bool configured) = adapter.fallbackQuote();
        assertFalse(configured, "fallback quote should start unset");
    }

    function testInitialOracleRoleAssignmentsAndHierarchy() public view {
        assertTrue(adapter.hasRole(adapter.ORACLE_ADMIN_ROLE(), admin), "initial admin should have oracle admin role");
        assertTrue(
            adapter.hasRole(adapter.ORACLE_GUARDIAN_ROLE(), admin), "initial admin should have oracle guardian role"
        );
        assertTrue(
            adapter.getRoleAdmin(adapter.ORACLE_ADMIN_ROLE()) == adapter.DEFAULT_ADMIN_ROLE(),
            "oracle admin role should be governed by default admin role"
        );
        assertTrue(
            adapter.getRoleAdmin(adapter.ORACLE_GUARDIAN_ROLE()) == adapter.ORACLE_ADMIN_ROLE(),
            "oracle guardian role should be governed by oracle admin role"
        );
    }

    function testOracleAdminCanGrantGuardianRole() public {
        bytes32 oracleAdminRole = adapter.ORACLE_ADMIN_ROLE();
        bytes32 oracleGuardianRole = adapter.ORACLE_GUARDIAN_ROLE();

        VM.prank(admin);
        adapter.grantRole(oracleAdminRole, bob);

        VM.prank(bob);
        adapter.grantRole(oracleGuardianRole, eve);

        assertTrue(adapter.hasRole(oracleGuardianRole, eve), "oracle admin should grant guardian role");
    }

    function testSupportsInterface() public view {
        assertTrue(adapter.supportsInterface(type(IERC165).interfaceId), "erc165 not supported");
        assertTrue(adapter.supportsInterface(type(IOracleAdapter).interfaceId), "oracle adapter not supported");
        assertTrue(adapter.supportsInterface(type(IAccessControl).interfaceId), "access control not supported");
        assertTrue(adapter.supportsInterface(type(IAccessControlTime).interfaceId), "access control time not supported");
    }

    function testInitializeRevertsWhenAlreadyInitialized() public {
        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterAlreadyInitialized.selector));
        adapter.initializeOracleAdapterExternal(address(feedA), maxStaleness);
    }

    function testZeroSourceRevertsOnConstruction() public {
        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterZeroSource.selector));
        new OracleAdapterHarness(admin, address(0), maxStaleness);
    }

    function testAdminCanSetOracleSource() public {
        VM.prank(admin);
        adapter.setOracleSource(address(feedB));
        assertTrue(adapter.oracleSource() == address(feedB), "source should update");
    }

    function testSetOracleSourceEmitsEvent() public {
        VM.expectEmit(true, true, true, false, address(adapter));
        emit OracleSourceUpdated(address(feedA), address(feedB), admin);

        VM.prank(admin);
        adapter.setOracleSource(address(feedB));
    }

    function testNonAdminCannotSetOracleSource() public {
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, adapter.ORACLE_ADMIN_ROLE())
        );
        VM.prank(bob);
        adapter.setOracleSource(address(feedB));
    }

    function testSetOracleSourceRejectsZeroAddress() public {
        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterZeroSource.selector));
        VM.prank(admin);
        adapter.setOracleSource(address(0));
    }

    function testAdminCanSetMaxStaleness() public {
        VM.prank(admin);
        adapter.setMaxStaleness(2 hours);
        assertTrue(adapter.maxStaleness() == 2 hours, "max staleness should update");
    }

    function testSetMaxStalenessEmitsEvent() public {
        VM.expectEmit(true, true, true, true, address(adapter));
        emit OracleMaxStalenessUpdated(maxStaleness, 2 hours, admin);

        VM.prank(admin);
        adapter.setMaxStaleness(2 hours);
    }

    function testNonAdminCannotSetMaxStaleness() public {
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, adapter.ORACLE_ADMIN_ROLE())
        );
        VM.prank(bob);
        adapter.setMaxStaleness(2 hours);
    }

    function testAdminCanSetValidationBounds() public {
        VM.prank(admin);
        adapter.setValidationBounds(1, 2_000_000_000, true);

        (int256 minAnswer, int256 maxAnswer, bool boundsEnabled) = adapter.validationBounds();
        assertTrue(minAnswer == 1, "min should update");
        assertTrue(maxAnswer == 2_000_000_000, "max should update");
        assertTrue(boundsEnabled, "bounds should be enabled");
    }

    function testSetValidationBoundsEmitsEvent() public {
        VM.expectEmit(true, true, true, true, address(adapter));
        emit OracleValidationBoundsUpdated(type(int256).min, type(int256).max, false, 1, 2_000_000_000, true, admin);

        VM.prank(admin);
        adapter.setValidationBounds(1, 2_000_000_000, true);
    }

    function testNonAdminCannotSetValidationBounds() public {
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, adapter.ORACLE_ADMIN_ROLE())
        );
        VM.prank(bob);
        adapter.setValidationBounds(1, 2_000_000_000, true);
    }

    function testSetValidationBoundsRejectsInvalidRange() public {
        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterInvalidValidationBounds.selector, 2, 1));
        VM.prank(admin);
        adapter.setValidationBounds(2, 1, true);
    }

    function testAdminCanTripAndResetCircuitBreaker() public {
        VM.prank(admin);
        adapter.tripCircuitBreaker();
        assertTrue(adapter.circuitBreakerActive(), "breaker should be active");

        VM.prank(admin);
        adapter.resetCircuitBreaker();
        assertFalse(adapter.circuitBreakerActive(), "breaker should be inactive");
    }

    function testTripAndResetCircuitBreakerEmitEvents() public {
        VM.expectEmit(true, true, true, true, address(adapter));
        emit OracleCircuitBreakerTripped(admin);

        VM.prank(admin);
        adapter.tripCircuitBreaker();

        VM.expectEmit(true, true, true, true, address(adapter));
        emit OracleCircuitBreakerReset(admin);

        VM.prank(admin);
        adapter.resetCircuitBreaker();
    }

    function testTripCircuitBreakerRevertsWhenAlreadyActive() public {
        VM.prank(admin);
        adapter.tripCircuitBreaker();

        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterBreakerAlreadyActive.selector));
        VM.prank(admin);
        adapter.tripCircuitBreaker();
    }

    function testResetCircuitBreakerRevertsWhenAlreadyInactive() public {
        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterBreakerAlreadyInactive.selector));
        VM.prank(admin);
        adapter.resetCircuitBreaker();
    }

    function testNonAdminCannotManageCircuitBreaker() public {
        VM.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorized.selector, bob, adapter.ORACLE_GUARDIAN_ROLE()
            )
        );
        VM.prank(bob);
        adapter.tripCircuitBreaker();

        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, adapter.ORACLE_ADMIN_ROLE())
        );
        VM.prank(bob);
        adapter.resetCircuitBreaker();
    }

    function testOracleGuardianCanTripButCannotReset() public {
        bytes32 oracleAdminRole = adapter.ORACLE_ADMIN_ROLE();
        bytes32 oracleGuardianRole = adapter.ORACLE_GUARDIAN_ROLE();

        VM.prank(admin);
        adapter.grantRole(oracleGuardianRole, bob);
        VM.prank(admin);
        adapter.revokeRole(oracleAdminRole, bob);

        VM.prank(bob);
        adapter.tripCircuitBreaker();
        assertTrue(adapter.circuitBreakerActive(), "guardian should trip breaker");

        VM.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, oracleAdminRole));
        VM.prank(bob);
        adapter.resetCircuitBreaker();
    }

    function testOracleAdminCannotTripWithoutGuardianRole() public {
        bytes32 oracleAdminRole = adapter.ORACLE_ADMIN_ROLE();
        bytes32 oracleGuardianRole = adapter.ORACLE_GUARDIAN_ROLE();

        VM.prank(admin);
        adapter.grantRole(oracleAdminRole, bob);

        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, oracleGuardianRole)
        );
        VM.prank(bob);
        adapter.tripCircuitBreaker();
    }

    function testAdminCanSetFallbackMode() public {
        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);
        assertTrue(
            adapter.fallbackMode() == IOracleAdapter.FallbackMode.UseConfiguredQuote, "fallback mode should update"
        );
    }

    function testSetFallbackModeEmitsEvent() public {
        VM.expectEmit(true, true, true, true, address(adapter));
        emit OracleFallbackModeUpdated(
            IOracleAdapter.FallbackMode.StrictRevert, IOracleAdapter.FallbackMode.UseConfiguredQuote, admin
        );

        VM.prank(admin);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);
    }

    function testNonAdminCannotSetFallbackMode() public {
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, adapter.ORACLE_ADMIN_ROLE())
        );
        VM.prank(bob);
        adapter.setFallbackMode(IOracleAdapter.FallbackMode.UseConfiguredQuote);
    }

    function testAdminCanSetAndClearFallbackQuote() public {
        VM.prank(admin);
        adapter.setFallbackQuote(42, 999_000, 8);

        (IOracleAdapter.OracleQuote memory configuredQuote, bool configured) = adapter.fallbackQuote();
        assertTrue(configured, "fallback should be configured");
        assertTrue(configuredQuote.value == 42, "fallback value should match");
        assertTrue(configuredQuote.updatedAt == 999_000, "fallback updatedAt should match");
        assertTrue(configuredQuote.decimals == 8, "fallback decimals should match");

        VM.prank(admin);
        adapter.clearFallbackQuote();

        (, configured) = adapter.fallbackQuote();
        assertFalse(configured, "fallback should be cleared");
    }

    function testSetFallbackQuoteEmitsEvent() public {
        VM.expectEmit(true, true, true, true, address(adapter));
        emit OracleFallbackQuoteUpdated(42, 999_000, 8, admin);

        VM.prank(admin);
        adapter.setFallbackQuote(42, 999_000, 8);
    }

    function testClearFallbackQuoteEmitsEvent() public {
        VM.prank(admin);
        adapter.setFallbackQuote(42, 999_000, 8);

        VM.expectEmit(true, true, true, true, address(adapter));
        emit OracleFallbackQuoteCleared(admin);

        VM.prank(admin);
        adapter.clearFallbackQuote();
    }

    function testSetFallbackQuoteRejectsZeroUpdatedAt() public {
        VM.expectRevert(abi.encodeWithSelector(IOracleAdapter.OracleAdapterInvalidFallbackQuote.selector, 0));
        VM.prank(admin);
        adapter.setFallbackQuote(1, 0, 8);
    }

    function testNonAdminCannotSetOrClearFallbackQuote() public {
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, adapter.ORACLE_ADMIN_ROLE())
        );
        VM.prank(bob);
        adapter.setFallbackQuote(42, 999_000, 8);

        VM.prank(admin);
        adapter.setFallbackQuote(42, 999_000, 8);

        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, adapter.ORACLE_ADMIN_ROLE())
        );
        VM.prank(bob);
        adapter.clearFallbackQuote();
    }

    function testQuoteReturnsNormalizedPayload() public view {
        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == 100_000_000, "value should match source answer");
        assertTrue(readQuote.updatedAt == feedAUpdatedAt, "updatedAt should match source");
        assertTrue(readQuote.decimals == 8, "decimals should match source");
    }

    function testQuoteReflectsSourceChange() public {
        VM.prank(admin);
        adapter.setOracleSource(address(feedB));

        IOracleAdapter.OracleQuote memory readQuote = adapter.quote();
        assertTrue(readQuote.value == 2_000_000_000_000_000_000, "value should match new source");
        assertTrue(readQuote.updatedAt == feedBUpdatedAt, "updatedAt should match new source");
        assertTrue(readQuote.decimals == 18, "decimals should match new source");
    }

    function testQuoteRevertsOnUpdatedAtOverflow() public {
        feedA.setLatestRoundData(1, 100_000_000, feedAUpdatedAt, uint256(type(uint64).max) + 1, 1);

        VM.expectRevert(
            abi.encodeWithSelector(IOracleAdapter.OracleAdapterInvalidUpdatedAt.selector, uint256(type(uint64).max) + 1)
        );
        adapter.quote();
    }
}
