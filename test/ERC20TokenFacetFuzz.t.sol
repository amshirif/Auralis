// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IERC20TokenFacet} from "../src/interfaces/IERC20TokenFacet.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {ERC20TokenFacetFixture} from "./helpers/ERC20TokenFacetTestHarness.sol";

contract ERC20TokenFacetFuzzTest is ERC20TokenFacetFixture {
    function testFuzzPermitSetsAllowanceAndIncrementsNonce(uint96 valueRaw, uint40 deadlineOffsetRaw) public {
        _erc20Init(address(facet));

        uint256 value = uint256(valueRaw);
        uint256 deadline = block.timestamp + uint256(deadlineOffsetRaw) + 1;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(BOB_PK, address(facet), bob, eve, value, 0, deadline);

        IERC20TokenFacet(address(facet)).permit(bob, eve, value, deadline, v, r, s);

        assertTrue(IERC20TokenFacet(address(facet)).allowance(bob, eve) == value, "permit allowance mismatch");
        assertTrue(IERC20TokenFacet(address(facet)).nonces(bob) == 1, "permit nonce mismatch");
    }

    function testFuzzPermitReplayReverts(uint96 valueRaw, uint40 deadlineOffsetRaw) public {
        _erc20Init(address(facet));

        uint256 value = uint256(valueRaw);
        uint256 deadline = block.timestamp + uint256(deadlineOffsetRaw) + 1;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(BOB_PK, address(facet), bob, eve, value, 0, deadline);

        IERC20TokenFacet(address(facet)).permit(bob, eve, value, deadline, v, r, s);

        address replaySigner = _recoverPermitSigner(address(facet), bob, eve, value, 1, deadline, v, r, s);
        VM.expectRevert(abi.encodeWithSelector(IERC20TokenFacet.ERC20PermitInvalidSigner.selector, replaySigner, bob));
        IERC20TokenFacet(address(facet)).permit(bob, eve, value, deadline, v, r, s);
    }

    function testFuzzTransferFromConsumesAllowanceAfterPermit(uint96 allowanceRaw, uint96 spendRaw) public {
        _erc20Init(address(facet));

        uint256 allowance = uint256(allowanceRaw) + 1;
        uint256 spend = _boundAmount(spendRaw, allowance);
        uint256 mintAmount = allowance + 100;

        VM.prank(admin);
        IERC20TokenFacet(address(facet)).mint(bob, mintAmount);

        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(BOB_PK, address(facet), bob, eve, allowance, 0, deadline);
        IERC20TokenFacet(address(facet)).permit(bob, eve, allowance, deadline, v, r, s);

        VM.prank(eve);
        IERC20TokenFacet(address(facet)).transferFrom(bob, admin, spend);

        assertTrue(
            IERC20TokenFacet(address(facet)).allowance(bob, eve) == allowance - spend,
            "permit allowance should decrement"
        );
    }

    function testFuzzPausedApprovalScopeBlocksPermit(uint96 valueRaw) public {
        _erc20Init(address(facet));
        bytes32 approvalScope = IERC20TokenFacet(address(facet)).ERC20_APPROVAL_SCOPE();
        uint256 value = uint256(valueRaw);
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(BOB_PK, address(facet), bob, eve, value, 0, deadline);

        VM.prank(admin);
        IERC20TokenFacet(address(facet)).pauseScope(approvalScope);

        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, approvalScope));
        IERC20TokenFacet(address(facet)).permit(bob, eve, value, deadline, v, r, s);
    }

    function testFuzzMintBurnSupplyAccounting(uint96 mintRaw, uint96 burnRaw) public {
        _erc20Init(address(facet));

        uint256 mintAmount = uint256(mintRaw) + 1;
        VM.prank(admin);
        IERC20TokenFacet(address(facet)).mint(bob, mintAmount);

        uint256 burnAmount = _boundAmount(burnRaw, mintAmount);
        VM.prank(admin);
        IERC20TokenFacet(address(facet)).burn(bob, burnAmount);

        assertTrue(IERC20TokenFacet(address(facet)).totalSupply() == mintAmount - burnAmount, "total supply mismatch");
        assertTrue(IERC20TokenFacet(address(facet)).balanceOf(bob) == mintAmount - burnAmount, "balance mismatch");
    }

    function testFuzzPausedTransferScopeBlocksMutations(uint96 mintRaw, uint96 burnRaw, uint96 transferRaw) public {
        _erc20Init(address(facet));
        bytes32 transferScope = IERC20TokenFacet(address(facet)).ERC20_TRANSFER_SCOPE();
        uint256 initialMint = uint256(mintRaw) + 1;

        VM.prank(admin);
        IERC20TokenFacet(address(facet)).mint(bob, initialMint);
        VM.prank(admin);
        IERC20TokenFacet(address(facet)).pauseScope(transferScope);

        uint256 transferAmount = _boundAmount(transferRaw, initialMint);
        VM.startPrank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
        IERC20TokenFacet(address(facet)).transfer(eve, transferAmount);
        VM.stopPrank();

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
        IERC20TokenFacet(address(facet)).mint(eve, 1);

        uint256 burnAmount = _boundAmount(burnRaw, initialMint);
        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
        IERC20TokenFacet(address(facet)).burn(bob, burnAmount);
    }

    function _boundAmount(uint256 raw, uint256 max) internal pure returns (uint256) {
        if (max == 0) {
            return 0;
        }
        return (raw % max) + 1;
    }
}
