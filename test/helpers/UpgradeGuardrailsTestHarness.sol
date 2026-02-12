// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {UpgradeGuardrails} from "../../src/upgrade/UpgradeGuardrails.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

contract UpgradeGuardrailsHarness is UpgradeGuardrails {
    address public implementation;
    uint256 public executionCount;

    constructor(address initialAdmin, uint64 minDelaySeconds) UpgradeGuardrails(initialAdmin, minDelaySeconds) {}

    function initializeUpgradeGuardrailsExternal(address initialUpgrader, uint64 minDelaySeconds) external {
        _initializeUpgradeGuardrails(initialUpgrader, minDelaySeconds);
    }

    function _applyUpgrade(address newImplementation) internal override {
        implementation = newImplementation;
        executionCount += 1;
    }
}

abstract contract UpgradeGuardrailsFixture is TestBase {
    uint64 internal constant DELAY_SECONDS = 1 days;

    address internal admin = address(0xA11CE);
    address internal bob = address(0xB0B);

    address internal implementationA = address(0x1000A);
    address internal implementationB = address(0x1000B);

    UpgradeGuardrailsHarness internal guardNoDelay;
    UpgradeGuardrailsHarness internal guardDelayed;

    function setUp() public virtual {
        guardNoDelay = new UpgradeGuardrailsHarness(admin, 0);
        guardDelayed = new UpgradeGuardrailsHarness(admin, DELAY_SECONDS);
    }
}

