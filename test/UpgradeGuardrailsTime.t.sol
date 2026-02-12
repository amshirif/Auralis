// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {UpgradeGuardrailsFixture} from "./helpers/UpgradeGuardrailsTestHarness.sol";
import {IUpgradeGuardrails} from "../src/interfaces/IUpgradeGuardrails.sol";

contract UpgradeGuardrailsTimeTest is UpgradeGuardrailsFixture {
    function testQueueUpgradeIntentSetsDelayedExecuteAfter() public {
        uint64 expectedExecuteAfter = uint64(block.timestamp) + DELAY_SECONDS;

        VM.prank(admin);
        guardDelayed.queueUpgradeIntent(implementationA);

        (address implementation, uint64 executeAfter, bool exists) = guardDelayed.getUpgradeIntent();
        assertTrue(exists, "intent should exist");
        assertTrue(implementation == implementationA, "implementation should match queued value");
        assertTrue(executeAfter == expectedExecuteAfter, "executeAfter should include delay");
    }

    function testExecuteUpgradeBeforeDelayReverts() public {
        VM.prank(admin);
        guardDelayed.queueUpgradeIntent(implementationA);
        (, uint64 executeAfter,) = guardDelayed.getUpgradeIntent();

        VM.expectRevert(
            abi.encodeWithSelector(
                IUpgradeGuardrails.UpgradeGuardrailsUpgradeNotReady.selector, executeAfter, uint64(block.timestamp)
            )
        );
        VM.prank(admin);
        guardDelayed.executeUpgrade(implementationA);
    }

    function testExecuteUpgradeSucceedsAtDelayBoundary() public {
        VM.prank(admin);
        guardDelayed.queueUpgradeIntent(implementationA);
        (, uint64 executeAfter,) = guardDelayed.getUpgradeIntent();

        VM.warp(executeAfter);
        VM.prank(admin);
        guardDelayed.executeUpgrade(implementationA);

        assertTrue(guardDelayed.implementation() == implementationA, "implementation should be updated");
        assertTrue(guardDelayed.executionCount() == 1, "execution count should increment");
    }

    function testExecuteUpgradeSucceedsAfterDelayBoundary() public {
        VM.prank(admin);
        guardDelayed.queueUpgradeIntent(implementationA);
        (, uint64 executeAfter,) = guardDelayed.getUpgradeIntent();

        VM.warp(executeAfter + 5);
        VM.prank(admin);
        guardDelayed.executeUpgrade(implementationA);

        assertTrue(guardDelayed.implementation() == implementationA, "implementation should be updated");
        assertTrue(guardDelayed.executionCount() == 1, "execution count should increment");
    }

    function testCancelIntentThenRequeueResetsDelay() public {
        VM.prank(admin);
        guardDelayed.queueUpgradeIntent(implementationA);

        VM.prank(admin);
        guardDelayed.cancelUpgradeIntent();

        VM.warp(block.timestamp + 10);
        uint64 expectedExecuteAfter = uint64(block.timestamp) + DELAY_SECONDS;

        VM.prank(admin);
        guardDelayed.queueUpgradeIntent(implementationB);
        (address implementation, uint64 executeAfter, bool exists) = guardDelayed.getUpgradeIntent();
        assertTrue(exists, "intent should exist");
        assertTrue(implementation == implementationB, "implementation should match latest queue");
        assertTrue(executeAfter == expectedExecuteAfter, "delay should be recalculated from new queue time");
    }
}

