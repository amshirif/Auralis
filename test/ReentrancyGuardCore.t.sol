// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ReentrancyGuardFixture} from "./helpers/ReentrancyGuardTestHarness.sol";
import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IReentrancyGuard} from "../src/interfaces/IReentrancyGuard.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";

contract ReentrancyGuardCoreTest is ReentrancyGuardFixture {
    address internal bob = address(0xB0B);

    function testSupportsInterface() public view {
        assertTrue(guard.supportsInterface(type(IERC165).interfaceId), "erc165 not supported");
        assertTrue(guard.supportsInterface(type(IReentrancyGuard).interfaceId), "reentrancy interface not supported");

        assertTrue(guardedPausable.supportsInterface(type(IERC165).interfaceId), "erc165 not supported");
        assertTrue(
            guardedPausable.supportsInterface(type(IReentrancyGuard).interfaceId),
            "composed contract should support reentrancy interface"
        );
        assertTrue(guardedPausable.supportsInterface(type(IPausable).interfaceId), "composed contract missing pausable");
        assertTrue(
            guardedPausable.supportsInterface(type(IAccessControl).interfaceId),
            "composed contract missing access control"
        );
    }

    function testNonReentrantValidCallSucceeds() public {
        guard.guardedIncrement();
        assertTrue(guard.counter() == 1, "first guarded call should succeed");

        guard.guardedIncrement();
        assertTrue(guard.counter() == 2, "second guarded call should succeed");
        assertFalse(guard.reentrancyGuardEntered(), "guard should reset after call");
    }

    function testDirectReentrantCallReverts() public {
        VM.expectRevert(abi.encodeWithSelector(IReentrancyGuard.ReentrancyGuardReentrantCall.selector));
        attacker.attack();
    }

    function testNestedGuardedCallReverts() public {
        VM.expectRevert(abi.encodeWithSelector(IReentrancyGuard.ReentrancyGuardReentrantCall.selector));
        guard.guardedOuter();
    }

    function testUnguardedPathsRemainUnaffected() public {
        guard.unguardedIncrement();
        assertTrue(guard.unguardedRead() == 1, "unguarded writes should remain unaffected");

        guard.guardedIncrement();
        assertTrue(guard.unguardedRead() == 2, "guarded and unguarded paths should compose");
    }

    function testInitializeRevertsWhenAlreadyInitialized() public {
        VM.expectRevert(abi.encodeWithSelector(IReentrancyGuard.ReentrancyGuardAlreadyInitialized.selector));
        guard.initializeReentrancyGuardExternal();
    }

    function testComposedGuardAndPauseBehavior() public {
        assertTrue(guardedPausable.guardedCriticalAction(), "unguarded paused state should allow action");

        VM.prank(admin);
        guardedPausable.pause();

        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        guardedPausable.guardedCriticalAction();
    }

    function testComposedGuardAndAccessControlBehavior() public {
        VM.prank(admin);
        assertTrue(guardedPausable.guardedRoleAction(), "authorized role should call action");

        VM.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorized.selector, bob, guardedPausable.PAUSER_ROLE()
            )
        );
        VM.prank(bob);
        guardedPausable.guardedRoleAction();
    }
}
