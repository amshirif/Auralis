// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {UpgradeGuardrailsFixture} from "./helpers/UpgradeGuardrailsTestHarness.sol";
import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IAccessControlTime} from "../src/interfaces/IAccessControlTime.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IUpgradeGuardrails} from "../src/interfaces/IUpgradeGuardrails.sol";

contract UpgradeGuardrailsCoreTest is UpgradeGuardrailsFixture {
    event UpgradeIntentQueued(address indexed implementation, uint64 executeAfter, address indexed sender);
    event UpgradeIntentCancelled(address indexed implementation, address indexed sender);
    event UpgradeExecuted(address indexed implementation, address indexed sender);

    function testInitialAdminHasUpgraderRole() public view {
        assertTrue(guardNoDelay.hasRole(guardNoDelay.UPGRADER_ROLE(), admin), "admin should have upgrader role");
    }

    function testSupportsInterface() public view {
        assertTrue(guardNoDelay.supportsInterface(type(IERC165).interfaceId), "erc165 not supported");
        assertTrue(
            guardNoDelay.supportsInterface(type(IUpgradeGuardrails).interfaceId), "upgrade interface not supported"
        );
        assertTrue(guardNoDelay.supportsInterface(type(IAccessControl).interfaceId), "access control not supported");
        assertTrue(
            guardNoDelay.supportsInterface(type(IAccessControlTime).interfaceId), "access control time not supported"
        );
    }

    function testMinUpgradeDelaySetAtInitialization() public view {
        assertTrue(guardNoDelay.minUpgradeDelay() == 0, "no-delay guard should have zero delay");
        assertTrue(guardDelayed.minUpgradeDelay() == DELAY_SECONDS, "delayed guard should keep configured delay");
    }

    function testInitializeRevertsWhenAlreadyInitialized() public {
        VM.expectRevert(abi.encodeWithSelector(IUpgradeGuardrails.UpgradeGuardrailsAlreadyInitialized.selector));
        guardNoDelay.initializeUpgradeGuardrailsExternal(admin, 0);
    }

    function testUnauthorizedCannotQueueUpgradeIntent() public {
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, guardNoDelay.UPGRADER_ROLE())
        );
        VM.prank(bob);
        guardNoDelay.queueUpgradeIntent(implementationA);
    }

    function testUnauthorizedCannotCancelUpgradeIntent() public {
        VM.prank(admin);
        guardNoDelay.queueUpgradeIntent(implementationA);

        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, guardNoDelay.UPGRADER_ROLE())
        );
        VM.prank(bob);
        guardNoDelay.cancelUpgradeIntent();
    }

    function testUnauthorizedCannotExecuteUpgrade() public {
        VM.prank(admin);
        guardNoDelay.queueUpgradeIntent(implementationA);

        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, guardNoDelay.UPGRADER_ROLE())
        );
        VM.prank(bob);
        guardNoDelay.executeUpgrade(implementationA);
    }

    function testQueueUpgradeIntentRejectsZeroImplementation() public {
        VM.expectRevert(abi.encodeWithSelector(IUpgradeGuardrails.UpgradeGuardrailsZeroImplementation.selector));
        VM.prank(admin);
        guardNoDelay.queueUpgradeIntent(address(0));
    }

    function testQueueUpgradeIntentEmitsEvent() public {
        uint64 expectedExecuteAfter = uint64(block.timestamp) + guardNoDelay.minUpgradeDelay();
        VM.expectEmit(true, true, false, true, address(guardNoDelay));
        emit UpgradeIntentQueued(implementationA, expectedExecuteAfter, admin);

        VM.prank(admin);
        guardNoDelay.queueUpgradeIntent(implementationA);
    }

    function testCancelUpgradeIntentWithoutQueueReverts() public {
        VM.expectRevert(abi.encodeWithSelector(IUpgradeGuardrails.UpgradeGuardrailsNoUpgradeIntent.selector));
        VM.prank(admin);
        guardNoDelay.cancelUpgradeIntent();
    }

    function testCancelUpgradeIntentEmitsEvent() public {
        VM.prank(admin);
        guardNoDelay.queueUpgradeIntent(implementationA);

        VM.expectEmit(true, true, false, false, address(guardNoDelay));
        emit UpgradeIntentCancelled(implementationA, admin);

        VM.prank(admin);
        guardNoDelay.cancelUpgradeIntent();
    }

    function testExecuteUpgradeWithoutQueueReverts() public {
        VM.expectRevert(abi.encodeWithSelector(IUpgradeGuardrails.UpgradeGuardrailsNoUpgradeIntent.selector));
        VM.prank(admin);
        guardNoDelay.executeUpgrade(implementationA);
    }

    function testExecuteUpgradeMismatchedImplementationReverts() public {
        VM.prank(admin);
        guardNoDelay.queueUpgradeIntent(implementationA);

        VM.expectRevert(
            abi.encodeWithSelector(
                IUpgradeGuardrails.UpgradeGuardrailsImplementationNotQueued.selector, implementationA, implementationB
            )
        );
        VM.prank(admin);
        guardNoDelay.executeUpgrade(implementationB);
    }

    function testExecuteUpgradeRejectsZeroImplementation() public {
        VM.expectRevert(abi.encodeWithSelector(IUpgradeGuardrails.UpgradeGuardrailsZeroImplementation.selector));
        VM.prank(admin);
        guardNoDelay.executeUpgrade(address(0));
    }

    function testExecuteUpgradeWithZeroDelaySucceeds() public {
        VM.prank(admin);
        guardNoDelay.queueUpgradeIntent(implementationA);

        VM.prank(admin);
        guardNoDelay.executeUpgrade(implementationA);

        assertTrue(guardNoDelay.implementation() == implementationA, "implementation should be updated");
        assertTrue(guardNoDelay.executionCount() == 1, "execution count should increment");

        (address implementation, uint64 executeAfter, bool exists) = guardNoDelay.getUpgradeIntent();
        assertTrue(implementation == address(0) && executeAfter == 0, "intent values should reset");
        assertFalse(exists, "intent should be cleared");
    }

    function testExecuteUpgradeEmitsEvent() public {
        VM.prank(admin);
        guardNoDelay.queueUpgradeIntent(implementationA);

        VM.expectEmit(true, true, false, false, address(guardNoDelay));
        emit UpgradeExecuted(implementationA, admin);

        VM.prank(admin);
        guardNoDelay.executeUpgrade(implementationA);
    }

    function testQueueIntentCanBeReplaced() public {
        VM.prank(admin);
        guardNoDelay.queueUpgradeIntent(implementationA);

        VM.prank(admin);
        guardNoDelay.queueUpgradeIntent(implementationB);

        (address implementation, uint64 executeAfter, bool exists) = guardNoDelay.getUpgradeIntent();
        assertTrue(exists, "intent should exist");
        assertTrue(implementation == implementationB, "latest intent should replace prior one");
        assertTrue(executeAfter == uint64(block.timestamp), "executeAfter should be current timestamp for zero delay");
    }
}

