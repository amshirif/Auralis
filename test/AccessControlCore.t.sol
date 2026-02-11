// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControlHarness, AccessControlFixture} from "./helpers/AccessControlTestHarness.sol";
import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IAccessControlTime} from "../src/interfaces/IAccessControlTime.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";

contract AccessControlCoreTest is AccessControlFixture {
    function testDefaultAdminRoleAssigned() public view {
        assertTrue(ac.hasRole(ac.DEFAULT_ADMIN_ROLE(), admin), "admin missing default role");
    }

    function testDefaultAdminIsSelfAdmin() public view {
        assertTrue(
            ac.getRoleAdmin(ac.DEFAULT_ADMIN_ROLE()) == ac.DEFAULT_ADMIN_ROLE(), "default admin should self-admin"
        );
    }

    function testZeroAdminReverts() public {
        VM.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlZeroAdmin.selector));
        new AccessControlHarness(address(0));
    }

    function testInitializeRevertsWhenAlreadyInitialized() public {
        VM.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlAlreadyInitialized.selector));
        ac.initialize(admin);
    }

    function testSupportsInterface() public view {
        assertTrue(ac.supportsInterface(type(IERC165).interfaceId), "erc165 not supported");
        assertTrue(ac.supportsInterface(type(IAccessControl).interfaceId), "access control not supported");
        assertTrue(ac.supportsInterface(type(IAccessControlTime).interfaceId), "access control time not supported");
        assertTrue(!ac.supportsInterface(0xffffffff), "unexpected interface supported");
    }

    function testNonAdminCannotGrant() public {
        VM.startPrank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, bob, ac.getRoleAdmin(WRITER_ROLE))
        );
        ac.grantRole(WRITER_ROLE, bob);
        VM.stopPrank();
    }

    function testAdminCanGrantAndRevoke() public {
        VM.prank(admin);
        ac.grantRole(WRITER_ROLE, bob);
        assertTrue(ac.hasRole(WRITER_ROLE, bob), "grant failed");

        VM.prank(admin);
        ac.revokeRole(WRITER_ROLE, bob);
        assertTrue(!ac.hasRole(WRITER_ROLE, bob), "revoke failed");
    }

    function testRenounceRoleSelfOnly() public {
        VM.prank(admin);
        ac.grantRole(WRITER_ROLE, bob);

        VM.startPrank(admin);
        VM.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlRenounceSelfOnly.selector));
        ac.renounceRole(WRITER_ROLE, bob);
        VM.stopPrank();

        VM.prank(bob);
        ac.renounceRole(WRITER_ROLE, bob);
        assertTrue(!ac.hasRole(WRITER_ROLE, bob), "renounce failed");
    }

    function testRoleAdminChange() public {
        VM.prank(admin);
        ac.setRoleAdmin(WRITER_ROLE, SPECIAL_ADMIN_ROLE);

        VM.startPrank(admin);
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, admin, SPECIAL_ADMIN_ROLE)
        );
        ac.grantRole(WRITER_ROLE, bob);
        VM.stopPrank();

        VM.prank(admin);
        ac.grantRole(SPECIAL_ADMIN_ROLE, admin);

        VM.prank(admin);
        ac.grantRole(WRITER_ROLE, bob);
        assertTrue(ac.hasRole(WRITER_ROLE, bob), "grant after admin change failed");
    }

    function testRoleEnumeration() public {
        VM.prank(admin);
        ac.grantRole(WRITER_ROLE, admin);
        VM.prank(admin);
        ac.grantRole(WRITER_ROLE, bob);

        uint256 count = ac.getRoleMemberCount(WRITER_ROLE);
        assertTrue(count == 2, "count should be 2");
        assertTrue(_roleHasMember(WRITER_ROLE, admin), "admin missing from enumeration");
        assertTrue(_roleHasMember(WRITER_ROLE, bob), "bob missing from enumeration");

        VM.prank(admin);
        ac.revokeRole(WRITER_ROLE, bob);
        count = ac.getRoleMemberCount(WRITER_ROLE);
        assertTrue(count == 1, "count should be 1 after revoke");
        assertTrue(!_roleHasMember(WRITER_ROLE, bob), "bob should be removed");
    }

    function testRoleEnumerationEmpty() public view {
        bytes32 emptyRole = keccak256("EMPTY_ROLE");
        assertTrue(ac.getRoleMemberCount(emptyRole) == 0, "empty role should have zero members");
        assertTrue(!_roleHasMember(emptyRole, admin), "empty role should not contain admin");
    }

    function testRoleEnumerationSwapOnRevoke() public {
        VM.prank(admin);
        ac.grantRole(WRITER_ROLE, admin);
        VM.prank(admin);
        ac.grantRole(WRITER_ROLE, bob);

        VM.prank(admin);
        ac.revokeRole(WRITER_ROLE, admin);

        uint256 count = ac.getRoleMemberCount(WRITER_ROLE);
        assertTrue(count == 1, "count should be 1 after revoke");
        assertTrue(ac.getRoleMember(WRITER_ROLE, 0) == bob, "bob should be swapped into index 0");
    }

    function testGrantAndRevokeIdempotent() public {
        VM.prank(admin);
        ac.grantRole(WRITER_ROLE, bob);
        VM.prank(admin);
        ac.grantRole(WRITER_ROLE, bob);

        uint256 count = ac.getRoleMemberCount(WRITER_ROLE);
        assertTrue(count == 1, "duplicate grant should not add member");

        VM.prank(admin);
        ac.revokeRole(WRITER_ROLE, bob);
        VM.prank(admin);
        ac.revokeRole(WRITER_ROLE, bob);

        count = ac.getRoleMemberCount(WRITER_ROLE);
        assertTrue(count == 0, "duplicate revoke should not add member");
        assertTrue(!ac.hasRole(WRITER_ROLE, bob), "role should be revoked");
    }

    function testZeroAddressRoleMutationGuards() public {
        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlZeroAddressAccount.selector));
        ac.grantRole(WRITER_ROLE, address(0));

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlZeroAddressAccount.selector));
        ac.revokeRole(WRITER_ROLE, address(0));
    }
}
