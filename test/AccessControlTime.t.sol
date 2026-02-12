// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControlFixture} from "./helpers/AccessControlTestHarness.sol";
import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IAccessControlTime} from "../src/interfaces/IAccessControlTime.sol";

contract AccessControlTimeTest is AccessControlFixture {
    event RoleWindowSet(
        bytes32 indexed role, address indexed account, uint64 start, uint64 end, address indexed sender
    );
    event RoleWindowCleared(bytes32 indexed role, address indexed account, address indexed sender);

    function testNonAdminCannotSetRoleWindow() public {
        VM.startPrank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, ac.getRoleAdmin(WRITER_ROLE))
        );
        ac.setRoleWindow(WRITER_ROLE, bob, 100, 200);
        VM.stopPrank();
    }

    function testNonAdminCannotClearRoleWindow() public {
        VM.prank(admin);
        ac.setRoleWindow(WRITER_ROLE, bob, 100, 200);

        VM.startPrank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, ac.getRoleAdmin(WRITER_ROLE))
        );
        ac.clearRoleWindow(WRITER_ROLE, bob);
        VM.stopPrank();
    }

    function testRoleWindowAdminHandoff() public {
        VM.prank(admin);
        ac.setRoleWindow(WRITER_ROLE, bob, 100, 200);

        VM.prank(admin);
        ac.setRoleAdmin(WRITER_ROLE, SPECIAL_ADMIN_ROLE);

        VM.startPrank(admin);
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, admin, SPECIAL_ADMIN_ROLE)
        );
        ac.setRoleWindow(WRITER_ROLE, bob, 200, 300);
        VM.stopPrank();

        VM.startPrank(admin);
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, admin, SPECIAL_ADMIN_ROLE)
        );
        ac.clearRoleWindow(WRITER_ROLE, bob);
        VM.stopPrank();

        VM.prank(admin);
        ac.grantRole(SPECIAL_ADMIN_ROLE, eve);

        VM.prank(eve);
        ac.setRoleWindow(WRITER_ROLE, bob, 300, 400);
        (uint64 start, uint64 end, bool exists) = ac.getRoleWindow(WRITER_ROLE, bob);
        assertTrue(start == 300 && end == 400 && exists, "new role admin should update window");

        VM.prank(eve);
        ac.clearRoleWindow(WRITER_ROLE, bob);
        (,, exists) = ac.getRoleWindow(WRITER_ROLE, bob);
        assertFalse(exists, "new role admin should clear window");
    }

    function testInvalidRoleWindowReverts() public {
        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IAccessControlTime.AccessControlInvalidRoleWindow.selector, 100, 100));
        ac.setRoleWindow(WRITER_ROLE, bob, 100, 100);
    }

    function testSetRoleWindowEmitsEvent() public {
        VM.expectEmit(true, true, true, true, address(ac));
        emit RoleWindowSet(WRITER_ROLE, bob, 100, 200, admin);

        VM.prank(admin);
        ac.setRoleWindow(WRITER_ROLE, bob, 100, 200);
    }

    function testClearRoleWindowEmitsEvent() public {
        VM.prank(admin);
        ac.setRoleWindow(WRITER_ROLE, bob, 100, 200);

        VM.expectEmit(true, true, true, false, address(ac));
        emit RoleWindowCleared(WRITER_ROLE, bob, admin);

        VM.prank(admin);
        ac.clearRoleWindow(WRITER_ROLE, bob);
    }

    function testRevokeRoleEmitsRoleWindowClearedEvent() public {
        VM.prank(admin);
        ac.grantRole(WRITER_ROLE, bob);
        VM.prank(admin);
        ac.setRoleWindow(WRITER_ROLE, bob, 100, 200);

        VM.expectEmit(true, true, true, false, address(ac));
        emit RoleWindowCleared(WRITER_ROLE, bob, admin);

        VM.prank(admin);
        ac.revokeRole(WRITER_ROLE, bob);
    }

    function testZeroAddressWindowGuards() public {
        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlZeroAddressAccount.selector));
        ac.setRoleWindow(WRITER_ROLE, address(0), 100, 200);

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlZeroAddressAccount.selector));
        ac.clearRoleWindow(WRITER_ROLE, address(0));

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlZeroAddressAccount.selector));
        ac.grantRoleWithWindow(WRITER_ROLE, address(0), 100, 200);
    }

    function testHasRoleWithoutWindowIsNotActive() public {
        VM.prank(admin);
        ac.grantRole(WRITER_ROLE, bob);
        assertFalse(ac.hasActiveRole(WRITER_ROLE, bob), "role without window should be inactive");
    }

    function testRoleWindowBoundariesAndOnlyActiveRole() public {
        VM.prank(admin);
        ac.grantRole(WRITER_ROLE, bob);
        VM.prank(admin);
        ac.setRoleWindow(WRITER_ROLE, bob, 100, 200);

        VM.warp(99);
        assertFalse(ac.hasActiveRole(WRITER_ROLE, bob), "should be inactive before start");
        VM.startPrank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControlTime.AccessControlRoleNotActive.selector, bob, WRITER_ROLE)
        );
        ac.gatedAction(WRITER_ROLE);
        VM.stopPrank();

        VM.warp(100);
        assertTrue(ac.hasActiveRole(WRITER_ROLE, bob), "should be active at start");
        VM.prank(bob);
        assertTrue(ac.gatedAction(WRITER_ROLE), "gated action should succeed in active window");

        VM.warp(199);
        assertTrue(ac.hasActiveRole(WRITER_ROLE, bob), "should remain active before end");

        VM.warp(200);
        assertFalse(ac.hasActiveRole(WRITER_ROLE, bob), "should be inactive at end boundary");
    }

    function testOpenEndedRoleWindow() public {
        VM.prank(admin);
        ac.grantRole(WRITER_ROLE, bob);
        VM.prank(admin);
        ac.setRoleWindow(WRITER_ROLE, bob, 500, 0);

        VM.warp(499);
        assertFalse(ac.hasActiveRole(WRITER_ROLE, bob), "open-ended window should respect start");
        VM.warp(500);
        assertTrue(ac.hasActiveRole(WRITER_ROLE, bob), "open-ended window should activate at start");
        VM.warp(10_000);
        assertTrue(ac.hasActiveRole(WRITER_ROLE, bob), "open-ended window should stay active");
    }

    function testClearRoleWindow() public {
        VM.prank(admin);
        ac.grantRole(WRITER_ROLE, bob);
        VM.prank(admin);
        ac.setRoleWindow(WRITER_ROLE, bob, 100, 200);

        VM.prank(admin);
        ac.clearRoleWindow(WRITER_ROLE, bob);
        (uint64 start, uint64 end, bool exists) = ac.getRoleWindow(WRITER_ROLE, bob);
        assertTrue(start == 0 && end == 0, "cleared window should reset values");
        assertFalse(exists, "cleared window should not exist");
    }

    function testRevokeRoleClearsRoleWindow() public {
        VM.prank(admin);
        ac.grantRole(WRITER_ROLE, bob);
        VM.prank(admin);
        ac.setRoleWindow(WRITER_ROLE, bob, 100, 200);

        VM.prank(admin);
        ac.revokeRole(WRITER_ROLE, bob);
        (,, bool exists) = ac.getRoleWindow(WRITER_ROLE, bob);
        assertFalse(exists, "role revoke should clear role window");
    }

    function testGrantRoleWithWindow() public {
        VM.prank(admin);
        ac.grantRoleWithWindow(WRITER_ROLE, bob, 100, 200);

        assertTrue(ac.hasRole(WRITER_ROLE, bob), "role should be granted");
        (uint64 start, uint64 end, bool exists) = ac.getRoleWindow(WRITER_ROLE, bob);
        assertTrue(start == 100 && end == 200, "window values should match");
        assertTrue(exists, "window should exist");

        VM.warp(150);
        assertTrue(ac.hasActiveRole(WRITER_ROLE, bob), "role should be active inside window");
    }
}
