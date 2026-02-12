// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {PausableFixture} from "./helpers/PausableTestHarness.sol";
import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";

contract PausableFuzzTest is PausableFixture {
    function testFuzzPauseScopeRoundTrip(bytes32 scope) public {
        VM.assume(scope != bytes32(0));

        VM.prank(admin);
        pausable.pauseScope(scope);
        assertTrue(pausable.scopePaused(scope), "scope should be paused");
        assertTrue(pausable.paused(scope), "effective scope pause should be true");

        VM.prank(admin);
        pausable.unpauseScope(scope);
        assertFalse(pausable.scopePaused(scope), "scope should be unpaused");
        assertFalse(pausable.paused(scope), "effective scope pause should be false");
    }

    function testFuzzGlobalPauseOverridesAnyScope(bytes32 scope) public {
        VM.assume(scope != bytes32(0));

        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeExpectedPause.selector, scope));
        pausable.scopedEmergencyAction(scope);

        VM.prank(admin);
        pausable.pause();

        assertTrue(pausable.paused(scope), "global pause should force effective scope pause");
        assertTrue(pausable.scopedEmergencyAction(scope), "scoped emergency action should pass during global pause");
    }

    function testFuzzDistinctScopeIsolation(bytes32 scopeA, bytes32 scopeB) public {
        VM.assume(scopeA != bytes32(0));
        VM.assume(scopeB != bytes32(0));
        VM.assume(scopeA != scopeB);

        VM.prank(admin);
        pausable.pauseScope(scopeA);

        assertTrue(pausable.scopePaused(scopeA), "scopeA should be paused");
        assertFalse(pausable.scopePaused(scopeB), "scopeB should remain unpaused");
        assertFalse(pausable.paused(scopeB), "effective scopeB pause should remain false");

        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeExpectedPause.selector, scopeB));
        pausable.scopedEmergencyAction(scopeB);
        assertTrue(pausable.scopedEmergencyAction(scopeA), "scopeA emergency action should pass");
    }

    function testFuzzUnauthorizedScopePauseReverts(address actor, bytes32 scope) public {
        VM.assume(actor != address(0));
        VM.assume(actor != admin);
        VM.assume(scope != bytes32(0));

        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, actor, pausable.PAUSER_ROLE())
        );
        VM.prank(actor);
        pausable.pauseScope(scope);
    }
}

