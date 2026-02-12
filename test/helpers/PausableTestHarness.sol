// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Pausable} from "../../src/access/Pausable.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

contract PausableHarness is Pausable {
    bytes32 internal constant BETS_SCOPE = keccak256("BETS_SCOPE");
    bytes32 internal constant SETTLEMENT_SCOPE = keccak256("SETTLEMENT_SCOPE");

    constructor(address initialAdmin) Pausable(initialAdmin) {}

    function initializePausable(address initialPauser) external {
        _initializePausable(initialPauser);
    }

    function criticalAction() external view whenNotPaused returns (bool) {
        return true;
    }

    function emergencyAction() external view whenPaused returns (bool) {
        return true;
    }

    function betsAction() external view whenScopeNotPaused(BETS_SCOPE) returns (bool) {
        return true;
    }

    function settlementAction() external view whenScopeNotPaused(SETTLEMENT_SCOPE) returns (bool) {
        return true;
    }

    function scopedEmergencyAction(bytes32 scope) external view whenScopePaused(scope) returns (bool) {
        return true;
    }

    function betsScope() external pure returns (bytes32) {
        return BETS_SCOPE;
    }

    function settlementScope() external pure returns (bytes32) {
        return SETTLEMENT_SCOPE;
    }
}

abstract contract PausableFixture is TestBase {
    address internal admin = address(0xA11CE);
    address internal bob = address(0xB0B);

    PausableHarness internal pausable;

    function setUp() public virtual {
        pausable = new PausableHarness(admin);
    }
}
