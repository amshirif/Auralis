// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAMMLpToken} from "../src/interfaces/IAMMLpToken.sol";
import {AMMFoundationFixture} from "./helpers/AMMTestHarness.sol";

contract AMMFoundationCoreTest is AMMFoundationFixture {
    function testInitializationSucceedsOnceAndCachesDomainSeparator() public {
        lpToken.initializeAmmLpToken();

        assertTrue(lpToken.initialized(), "lp token should initialize");
        assertTrue(keccak256(bytes(lpToken.name())) == keccak256(bytes("Auralis V2 LP")), "name mismatch");
        assertTrue(keccak256(bytes(lpToken.symbol())) == keccak256(bytes("AUR-V2-LP")), "symbol mismatch");
        assertTrue(lpToken.decimals() == 18, "decimals mismatch");
        assertTrue(lpToken.DOMAIN_SEPARATOR() == _domainSeparator(address(lpToken)), "domain separator mismatch");

        VM.expectRevert(IAMMLpToken.AMMLpAlreadyInitialized.selector);
        lpToken.initializeAmmLpToken();
    }

    function testMintTransferApproveTransferFromAndBurn() public {
        lpToken.initializeAmmLpToken();

        lpToken.mint(alice, 100);
        assertTrue(lpToken.totalSupply() == 100, "total supply mismatch");
        assertTrue(lpToken.balanceOf(alice) == 100, "alice balance mismatch");

        VM.prank(alice);
        assertTrue(lpToken.transfer(bob, 40), "transfer should succeed");
        assertTrue(lpToken.balanceOf(alice) == 60, "alice post-transfer mismatch");
        assertTrue(lpToken.balanceOf(bob) == 40, "bob post-transfer mismatch");

        VM.prank(alice);
        assertTrue(lpToken.approve(bob, 25), "approve should succeed");
        assertTrue(lpToken.allowance(alice, bob) == 25, "allowance mismatch");

        VM.prank(bob);
        assertTrue(lpToken.transferFrom(alice, carol, 20), "transferFrom should succeed");
        assertTrue(lpToken.balanceOf(carol) == 20, "carol balance mismatch");
        assertTrue(lpToken.allowance(alice, bob) == 5, "allowance post-transferFrom mismatch");

        lpToken.burn(carol, 10);
        assertTrue(lpToken.balanceOf(carol) == 10, "carol post-burn mismatch");
        assertTrue(lpToken.totalSupply() == 90, "total supply post-burn mismatch");
    }

    function testPermitSetsAllowanceAndIncrementsNonce() public {
        lpToken.initializeAmmLpToken();

        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(ALICE_PK, address(lpToken), alice, bob, 55, 0, deadline);

        lpToken.permit(alice, bob, 55, deadline, v, r, s);

        assertTrue(lpToken.allowance(alice, bob) == 55, "permit allowance mismatch");
        assertTrue(lpToken.nonces(alice) == 1, "permit nonce mismatch");
    }

    function testPermitReplayReverts() public {
        lpToken.initializeAmmLpToken();

        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(ALICE_PK, address(lpToken), alice, bob, 55, 0, deadline);

        lpToken.permit(alice, bob, 55, deadline, v, r, s);

        address replaySigner = _recoverPermitSigner(address(lpToken), alice, bob, 55, 1, deadline, v, r, s);
        VM.expectRevert(abi.encodeWithSelector(IAMMLpToken.AMMLpPermitInvalidSigner.selector, replaySigner, alice));
        lpToken.permit(alice, bob, 55, deadline, v, r, s);
    }

    function testPermitRevertsOnExpiredDeadline() public {
        lpToken.initializeAmmLpToken();

        uint256 deadline = block.timestamp;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(ALICE_PK, address(lpToken), alice, bob, 33, 0, deadline);

        VM.warp(deadline + 1);
        VM.expectRevert(abi.encodeWithSelector(IAMMLpToken.AMMLpPermitExpired.selector, deadline, block.timestamp));
        lpToken.permit(alice, bob, 33, deadline, v, r, s);
    }

    function testPermitRevertsOnWrongPayload() public {
        lpToken.initializeAmmLpToken();

        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(ALICE_PK, address(lpToken), alice, bob, 55, 0, deadline);

        address wrongSpenderSigner = _recoverPermitSigner(address(lpToken), alice, carol, 55, 0, deadline, v, r, s);
        VM.expectRevert(
            abi.encodeWithSelector(IAMMLpToken.AMMLpPermitInvalidSigner.selector, wrongSpenderSigner, alice)
        );
        lpToken.permit(alice, carol, 55, deadline, v, r, s);
    }

    function testPermitRejectsInvalidVAndHighS() public {
        lpToken.initializeAmmLpToken();

        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(ALICE_PK, address(lpToken), alice, bob, 77, 0, deadline);

        VM.expectRevert(abi.encodeWithSelector(IAMMLpToken.AMMLpPermitInvalidSigner.selector, address(0), alice));
        lpToken.permit(alice, bob, 77, deadline, v + 2, r, s);

        VM.expectRevert(abi.encodeWithSelector(IAMMLpToken.AMMLpPermitInvalidSigner.selector, address(0), alice));
        lpToken.permit(alice, bob, 77, deadline, v, r, _invalidHighS(s));
    }

    function testZeroAddressTransferRevertsAndZeroSpenderApproveIsAllowed() public {
        lpToken.initializeAmmLpToken();
        lpToken.mint(alice, 10);

        VM.prank(alice);
        (bool success, bytes memory returndata) =
            address(lpToken).call(abi.encodeCall(lpToken.transfer, (address(0), 1)));
        assertFalse(success, "zero-address transfer should revert");

        bytes4 revertSelector;
        assembly {
            revertSelector := mload(add(returndata, 0x20))
        }
        assertTrue(revertSelector == IAMMLpToken.AMMLpZeroAddress.selector, "unexpected revert selector");

        VM.prank(alice);
        assertTrue(lpToken.approve(address(0), 7), "approve zero spender should succeed");
        assertTrue(lpToken.allowance(alice, address(0)) == 7, "zero spender allowance mismatch");
    }

    function testMutatingActionsRevertBeforeInitialization() public {
        VM.expectRevert(IAMMLpToken.AMMLpNotInitialized.selector);
        lpToken.mint(alice, 1);

        VM.prank(alice);
        VM.expectRevert(IAMMLpToken.AMMLpNotInitialized.selector);
        lpToken.approve(bob, 1);
    }

    function testMathHelpersMatchExpectedValues() public pure {
        assertTrue(_mathMin(4, 9) == 4, "min mismatch");
        assertTrue(_mathSqrt(0) == 0, "sqrt(0) mismatch");
        assertTrue(_mathSqrt(1) == 1, "sqrt(1) mismatch");
        assertTrue(_mathSqrt(2) == 1, "sqrt(2) mismatch");
        assertTrue(_mathSqrt(15) == 3, "sqrt(15) mismatch");
        assertTrue(_mathSqrt(16) == 4, "sqrt(16) mismatch");
    }

    function testFixedPointHelpersMatchUQ112x112Expectations() public pure {
        uint224 q112 = uint224(1) << 112;

        assertTrue(_encodeUq112x112(5) == 5 * q112, "encode mismatch");
        assertTrue(_uqdiv(10, 2) == 5 * q112, "uqdiv mismatch");
    }
}
