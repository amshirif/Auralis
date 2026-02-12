// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {UpgradeGuardrailsFixture, UpgradeGuardrailsHarness} from "./helpers/UpgradeGuardrailsTestHarness.sol";
import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IUpgradeGuardrails} from "../src/interfaces/IUpgradeGuardrails.sol";

contract UpgradeGuardrailsFuzzTest is UpgradeGuardrailsFixture {
    function testFuzzQueueSetsExecuteAfter(uint32 rawDelay, address implementation) public {
        VM.assume(implementation != address(0));
        uint64 delay = uint64(rawDelay);
        UpgradeGuardrailsHarness guard = new UpgradeGuardrailsHarness(admin, delay);
        uint64 expectedExecuteAfter = uint64(block.timestamp) + delay;

        VM.prank(admin);
        guard.queueUpgradeIntent(implementation);

        (address queuedImplementation, uint64 executeAfter, bool exists) = guard.getUpgradeIntent();
        assertTrue(exists, "intent should exist");
        assertTrue(queuedImplementation == implementation, "implementation should match queue input");
        assertTrue(executeAfter == expectedExecuteAfter, "executeAfter should equal queue time + delay");
    }

    function testFuzzExecuteAfterDelaySucceeds(uint32 rawDelay, address implementation, uint16 extraSeconds) public {
        VM.assume(implementation != address(0));
        uint64 delay = uint64((rawDelay % 7 days) + 1);
        UpgradeGuardrailsHarness guard = new UpgradeGuardrailsHarness(admin, delay);

        VM.prank(admin);
        guard.queueUpgradeIntent(implementation);
        (, uint64 executeAfter,) = guard.getUpgradeIntent();

        VM.warp(uint256(executeAfter) + uint256(extraSeconds));
        VM.prank(admin);
        guard.executeUpgrade(implementation);

        assertTrue(guard.implementation() == implementation, "implementation should update after ready time");
    }

    function testFuzzExecuteBeforeDelayReverts(uint32 rawDelay, address implementation) public {
        VM.assume(implementation != address(0));
        uint64 delay = uint64((rawDelay % 7 days) + 1);
        UpgradeGuardrailsHarness guard = new UpgradeGuardrailsHarness(admin, delay);

        VM.prank(admin);
        guard.queueUpgradeIntent(implementation);
        (, uint64 executeAfter,) = guard.getUpgradeIntent();

        uint64 earlyTime = executeAfter - 1;
        VM.warp(earlyTime);
        VM.expectRevert(
            abi.encodeWithSelector(
                IUpgradeGuardrails.UpgradeGuardrailsUpgradeNotReady.selector, executeAfter, earlyTime
            )
        );
        VM.prank(admin);
        guard.executeUpgrade(implementation);
    }

    function testFuzzQueueIntentReplacement(address implA, address implB) public {
        VM.assume(implA != address(0));
        VM.assume(implB != address(0));
        VM.assume(implA != implB);

        VM.prank(admin);
        guardNoDelay.queueUpgradeIntent(implA);
        VM.prank(admin);
        guardNoDelay.queueUpgradeIntent(implB);

        (address queuedImplementation,, bool exists) = guardNoDelay.getUpgradeIntent();
        assertTrue(exists, "intent should exist");
        assertTrue(queuedImplementation == implB, "latest intent should replace previous implementation");
    }

    function testFuzzUnauthorizedQueueReverts(address actor, address implementation) public {
        VM.assume(actor != address(0));
        VM.assume(actor != admin);
        VM.assume(implementation != address(0));

        VM.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorized.selector, actor, guardNoDelay.UPGRADER_ROLE()
            )
        );
        VM.prank(actor);
        guardNoDelay.queueUpgradeIntent(implementation);
    }
}

