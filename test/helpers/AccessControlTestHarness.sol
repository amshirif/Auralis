// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "../../src/access/AccessControl.sol";

interface Vm {
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function assume(bool) external;
    function addr(uint256) external returns (address);
    function deal(address who, uint256 newBalance) external;
    function sign(uint256, bytes32) external returns (uint8, bytes32, bytes32);
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
    function expectEmit(bool, bool, bool, bool) external;
    function expectEmit(bool, bool, bool, bool, address) external;
    function warp(uint256) external;
}

contract TestBase {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertTrue(bool condition, string memory message) internal pure {
        require(condition, message);
    }

    function assertFalse(bool condition, string memory message) internal pure {
        require(!condition, message);
    }
}

contract AccessControlHarness is AccessControl {
    constructor(address initialAdmin) AccessControl(initialAdmin) {}

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRoleAdmin(role, adminRole);
    }

    function initialize(address initialAdmin) external {
        _initializeAccessControl(initialAdmin);
    }

    function gatedAction(bytes32 role) external view onlyActiveRole(role) returns (bool) {
        return true;
    }
}

abstract contract AccessControlFixture is TestBase {
    bytes32 internal constant WRITER_ROLE = keccak256("WRITER_ROLE");
    bytes32 internal constant SPECIAL_ADMIN_ROLE = keccak256("SPECIAL_ADMIN_ROLE");

    address internal admin = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal eve = address(0xE11E);

    AccessControlHarness internal ac;

    function setUp() public virtual {
        ac = new AccessControlHarness(admin);
    }

    function _roleHasMember(bytes32 role, address member) internal view returns (bool) {
        uint256 count = ac.getRoleMemberCount(role);
        for (uint256 i = 0; i < count; i++) {
            if (ac.getRoleMember(role, i) == member) {
                return true;
            }
        }
        return false;
    }
}
