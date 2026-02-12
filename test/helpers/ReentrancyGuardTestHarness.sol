// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ReentrancyGuard} from "../../src/security/ReentrancyGuard.sol";
import {Pausable} from "../../src/access/Pausable.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

interface IReentrantCallback {
    function onReentrantCallback() external;
}

contract ReentrancyGuardHarness is ReentrancyGuard {
    uint256 public counter;

    constructor() ReentrancyGuard() {}

    function initializeReentrancyGuardExternal() external {
        _initializeReentrancyGuard();
    }

    function guardedIncrement() external nonReentrant {
        counter += 1;
    }

    function guardedCall(address callback) external nonReentrant {
        counter += 1;
        if (callback != address(0)) {
            IReentrantCallback(callback).onReentrantCallback();
        }
    }

    function guardedOuter() external nonReentrant {
        guardedInner();
    }

    function guardedInner() public nonReentrant {
        counter += 1;
    }

    function unguardedIncrement() external {
        counter += 1;
    }

    function unguardedRead() external view returns (uint256) {
        return counter;
    }
}

contract ReentrantAttacker is IReentrantCallback {
    ReentrancyGuardHarness internal immutable target;

    constructor(ReentrancyGuardHarness target_) {
        target = target_;
    }

    function attack() external {
        target.guardedCall(address(this));
    }

    function onReentrantCallback() external {
        target.guardedIncrement();
    }
}

contract GuardedPausableHarness is Pausable, ReentrancyGuard {
    uint256 public writes;

    constructor(address initialAdmin) Pausable(initialAdmin) ReentrancyGuard() {}

    function guardedCriticalAction() external nonReentrant whenNotPaused returns (bool) {
        writes += 1;
        return true;
    }

    function guardedRoleAction() external nonReentrant onlyRole(PAUSER_ROLE) returns (bool) {
        writes += 1;
        return true;
    }

    function supportsInterface(bytes4 interfaceId) public view override(Pausable, ReentrancyGuard) returns (bool) {
        return Pausable.supportsInterface(interfaceId) || ReentrancyGuard.supportsInterface(interfaceId);
    }
}

abstract contract ReentrancyGuardFixture is TestBase {
    address internal admin = address(0xA11CE);

    ReentrancyGuardHarness internal guard;
    ReentrantAttacker internal attacker;
    GuardedPausableHarness internal guardedPausable;

    function setUp() public virtual {
        guard = new ReentrancyGuardHarness();
        attacker = new ReentrantAttacker(guard);
        guardedPausable = new GuardedPausableHarness(admin);
    }
}
