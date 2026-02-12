// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControlFixture} from "./helpers/AccessControlTestHarness.sol";

contract AccessControlFuzzTest is AccessControlFixture {
    function testFuzzGrantRevokeRoundTrip(bytes32 role, address account) public {
        VM.assume(account != address(0));

        VM.prank(admin);
        ac.grantRole(role, account);
        assertTrue(ac.hasRole(role, account), "role should be granted");

        VM.prank(admin);
        ac.revokeRole(role, account);
        assertFalse(ac.hasRole(role, account), "role should be revoked");
    }

    function testFuzzGrantRoleIdempotent(bytes32 role, address account) public {
        VM.assume(account != address(0));
        VM.assume(role != ac.DEFAULT_ADMIN_ROLE());

        VM.prank(admin);
        ac.grantRole(role, account);
        VM.prank(admin);
        ac.grantRole(role, account);

        assertTrue(ac.hasRole(role, account), "role should remain granted");
        assertTrue(ac.getRoleMemberCount(role) == 1, "duplicate grant should not duplicate member");
    }

    function testFuzzSetRoleWindowRoundTrip(bytes32 role, address account, uint64 start, uint32 rawDuration) public {
        VM.assume(account != address(0));

        uint64 duration = uint64((rawDuration % 30 days) + 1);
        if (start > type(uint64).max - duration) {
            start = type(uint64).max - duration;
        }
        uint64 end = start + duration;

        VM.prank(admin);
        ac.setRoleWindow(role, account, start, end);

        (uint64 readStart, uint64 readEnd, bool exists) = ac.getRoleWindow(role, account);
        assertTrue(exists, "window should exist");
        assertTrue(readStart == start, "window start should match");
        assertTrue(readEnd == end, "window end should match");
    }
}

