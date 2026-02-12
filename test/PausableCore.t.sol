// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {PausableFixture} from "./helpers/PausableTestHarness.sol";
import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IAccessControlTime} from "../src/interfaces/IAccessControlTime.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";

contract PausableCoreTest is PausableFixture {
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event ScopePaused(bytes32 indexed scope, address indexed account);
    event ScopeUnpaused(bytes32 indexed scope, address indexed account);

    function testInitialStateUnpaused() public view {
        assertFalse(pausable.paused(), "should start unpaused");
    }

    function testScopesStartUnpaused() public view {
        assertFalse(pausable.scopePaused(pausable.betsScope()), "bets scope should start unpaused");
        assertFalse(pausable.paused(pausable.betsScope()), "effective bets pause should start false");
    }

    function testInitialAdminHasPauserRole() public view {
        assertTrue(pausable.hasRole(pausable.PAUSER_ROLE(), admin), "admin should have pauser role");
    }

    function testSupportsInterface() public view {
        assertTrue(pausable.supportsInterface(type(IERC165).interfaceId), "erc165 not supported");
        assertTrue(pausable.supportsInterface(type(IPausable).interfaceId), "pausable not supported");
        assertTrue(pausable.supportsInterface(type(IAccessControl).interfaceId), "access control not supported");
        assertTrue(
            pausable.supportsInterface(type(IAccessControlTime).interfaceId), "access control time not supported"
        );
    }

    function testNonPauserCannotPause() public {
        VM.startPrank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, pausable.PAUSER_ROLE())
        );
        pausable.pause();
        VM.stopPrank();
    }

    function testNonPauserCannotUnpause() public {
        VM.prank(admin);
        pausable.pause();

        VM.startPrank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, pausable.PAUSER_ROLE())
        );
        pausable.unpause();
        VM.stopPrank();
    }

    function testPauseAndUnpause() public {
        VM.prank(admin);
        pausable.pause();
        assertTrue(pausable.paused(), "pause should set paused state");

        VM.prank(admin);
        pausable.unpause();
        assertFalse(pausable.paused(), "unpause should clear paused state");
    }

    function testPauseScopeAndUnpauseScope() public {
        bytes32 betsScope = pausable.betsScope();

        VM.prank(admin);
        pausable.pauseScope(betsScope);
        assertTrue(pausable.scopePaused(betsScope), "scope pause should set local scope state");
        assertTrue(pausable.paused(betsScope), "scope pause should set effective paused state");

        VM.prank(admin);
        pausable.unpauseScope(betsScope);
        assertFalse(pausable.scopePaused(betsScope), "scope unpause should clear local scope state");
        assertFalse(pausable.paused(betsScope), "scope unpause should clear effective paused state");
    }

    function testPauseEmitsEvent() public {
        VM.expectEmit(true, false, false, false, address(pausable));
        emit Paused(admin);

        VM.prank(admin);
        pausable.pause();
    }

    function testUnpauseEmitsEvent() public {
        VM.prank(admin);
        pausable.pause();

        VM.expectEmit(true, false, false, false, address(pausable));
        emit Unpaused(admin);

        VM.prank(admin);
        pausable.unpause();
    }

    function testPauseScopeEmitsEvent() public {
        bytes32 betsScope = pausable.betsScope();
        VM.expectEmit(true, true, false, false, address(pausable));
        emit ScopePaused(betsScope, admin);

        VM.prank(admin);
        pausable.pauseScope(betsScope);
    }

    function testUnpauseScopeEmitsEvent() public {
        bytes32 betsScope = pausable.betsScope();

        VM.prank(admin);
        pausable.pauseScope(betsScope);

        VM.expectEmit(true, true, false, false, address(pausable));
        emit ScopeUnpaused(betsScope, admin);

        VM.prank(admin);
        pausable.unpauseScope(betsScope);
    }

    function testCannotPauseWhenPaused() public {
        VM.prank(admin);
        pausable.pause();

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        pausable.pause();
    }

    function testCannotUnpauseWhenUnpaused() public {
        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableExpectedPause.selector));
        pausable.unpause();
    }

    function testCannotPauseScopeWhenScopePaused() public {
        bytes32 betsScope = pausable.betsScope();
        VM.prank(admin);
        pausable.pauseScope(betsScope);

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, betsScope));
        pausable.pauseScope(betsScope);
    }

    function testCannotUnpauseScopeWhenScopeUnpaused() public {
        bytes32 betsScope = pausable.betsScope();

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeExpectedPause.selector, betsScope));
        pausable.unpauseScope(betsScope);
    }

    function testZeroScopeGuards() public {
        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableZeroScope.selector));
        pausable.pauseScope(bytes32(0));

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableZeroScope.selector));
        pausable.unpauseScope(bytes32(0));

        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableZeroScope.selector));
        pausable.scopedEmergencyAction(bytes32(0));
    }

    function testCriticalActionBlockedWhenPaused() public {
        VM.prank(admin);
        pausable.pause();

        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        pausable.criticalAction();
    }

    function testScopedActionBlockedWhenScopePaused() public {
        bytes32 betsScope = pausable.betsScope();
        VM.prank(admin);
        pausable.pauseScope(betsScope);

        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, betsScope));
        pausable.betsAction();
    }

    function testPauseScopeDoesNotPauseOtherScope() public {
        bytes32 betsScope = pausable.betsScope();
        bytes32 settlementScope = pausable.settlementScope();

        VM.prank(admin);
        pausable.pauseScope(betsScope);

        assertTrue(pausable.scopePaused(betsScope), "bets scope should be paused");
        assertFalse(pausable.scopePaused(settlementScope), "settlement scope should remain unpaused");
        assertTrue(pausable.settlementAction(), "settlement action should remain callable");
    }

    function testGlobalPauseOverridesScopeChecks() public {
        bytes32 settlementScope = pausable.settlementScope();
        assertFalse(pausable.scopePaused(settlementScope), "scope should start unpaused");

        VM.prank(admin);
        pausable.pause();

        assertTrue(pausable.paused(settlementScope), "effective scope pause should follow global pause");
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, settlementScope));
        pausable.settlementAction();
    }

    function testCriticalActionAllowedWhenUnpaused() public view {
        assertTrue(pausable.criticalAction(), "critical action should work when unpaused");
    }

    function testEmergencyActionRequiresPause() public {
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableExpectedPause.selector));
        pausable.emergencyAction();

        VM.prank(admin);
        pausable.pause();
        assertTrue(pausable.emergencyAction(), "emergency action should work when paused");
    }

    function testScopedEmergencyActionRequiresEffectivePause() public {
        bytes32 betsScope = pausable.betsScope();

        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeExpectedPause.selector, betsScope));
        pausable.scopedEmergencyAction(betsScope);

        VM.prank(admin);
        pausable.pauseScope(betsScope);
        assertTrue(pausable.scopedEmergencyAction(betsScope), "scope emergency should work when scope paused");
    }

    function testScopedEmergencyActionWorksDuringGlobalPause() public {
        bytes32 settlementScope = pausable.settlementScope();

        VM.prank(admin);
        pausable.pause();
        assertTrue(pausable.scopedEmergencyAction(settlementScope), "scope emergency should work when globally paused");
    }

    function testAdminCanGrantPauserRole() public {
        VM.startPrank(admin);
        pausable.grantRole(pausable.PAUSER_ROLE(), bob);
        VM.stopPrank();

        VM.prank(bob);
        pausable.pause();
        assertTrue(pausable.paused(), "granted pauser should pause");
    }

    function testNonPauserCannotPauseScope() public {
        bytes32 betsScope = pausable.betsScope();

        VM.startPrank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, pausable.PAUSER_ROLE())
        );
        pausable.pauseScope(betsScope);
        VM.stopPrank();
    }

    function testNonPauserCannotUnpauseScope() public {
        bytes32 betsScope = pausable.betsScope();
        VM.prank(admin);
        pausable.pauseScope(betsScope);

        VM.startPrank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, pausable.PAUSER_ROLE())
        );
        pausable.unpauseScope(betsScope);
        VM.stopPrank();
    }

    function testInitializePausableRevertsWhenAlreadyInitialized() public {
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableAlreadyInitialized.selector));
        pausable.initializePausable(admin);
    }
}
