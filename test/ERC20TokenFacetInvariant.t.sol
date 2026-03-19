// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20TokenFacet} from "../src/interfaces/IERC20TokenFacet.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {ERC20TokenFacetInvariantFixture} from "./helpers/ERC20TokenFacetInvariantTestHarness.sol";

contract ERC20TokenFacetInvariantTest is ERC20TokenFacetInvariantFixture {
    function targetContracts() external view returns (address[] memory contracts) {
        contracts = new address[](1);
        contracts[0] = address(this);
    }

    function actionApprove(uint8 ownerSeed, uint8 spenderSeed, uint96 valueRaw) external {
        address owner = _actor(ownerSeed);
        address spender = _actor(spenderSeed);
        if (owner == spender) {
            return;
        }

        bytes32 approvalScope = IERC20TokenFacet(address(facet)).ERC20_APPROVAL_SCOPE();
        uint256 value = uint256(valueRaw);
        if (IERC20TokenFacet(address(facet)).scopePaused(approvalScope)) {
            AccountingSnapshot memory snapshot = _snapshotAccounting();
            VM.startPrank(owner);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, approvalScope));
            IERC20TokenFacet(address(facet)).approve(spender, value);
            VM.stopPrank();
            _assertAccountingUnchanged(snapshot, "paused approval should not mutate accounting");
            return;
        }

        VM.prank(owner);
        IERC20TokenFacet(address(facet)).approve(spender, value);
    }

    function actionPermit(uint8 ownerSeed, uint8 spenderSeed, uint96 valueRaw, uint32 deadlineOffsetRaw) external {
        address owner = _actor(ownerSeed);
        address spender = _actor(spenderSeed);
        if (owner == spender) {
            return;
        }

        bytes32 approvalScope = IERC20TokenFacet(address(facet)).ERC20_APPROVAL_SCOPE();
        uint256 value = uint256(valueRaw);
        uint256 deadline = block.timestamp + uint256(deadlineOffsetRaw) + 1;
        uint256 nonce = IERC20TokenFacet(address(facet)).nonces(owner);
        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(_actorKey(ownerSeed), address(facet), owner, spender, value, nonce, deadline);

        if (IERC20TokenFacet(address(facet)).scopePaused(approvalScope)) {
            AccountingSnapshot memory snapshot = _snapshotAccounting();
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, approvalScope));
            IERC20TokenFacet(address(facet)).permit(owner, spender, value, deadline, v, r, s);
            _assertAccountingUnchanged(snapshot, "paused permit should not mutate accounting");
            return;
        }

        IERC20TokenFacet(address(facet)).permit(owner, spender, value, deadline, v, r, s);
        trackedPermitSuccesses[owner] += 1;
    }

    function actionTransfer(uint8 fromSeed, uint8 toSeed, uint96 valueRaw) external {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        if (from == to) {
            return;
        }

        bytes32 transferScope = IERC20TokenFacet(address(facet)).ERC20_TRANSFER_SCOPE();
        uint256 value = _boundAmount(valueRaw, IERC20TokenFacet(address(facet)).balanceOf(from));
        if (value == 0) {
            return;
        }

        if (IERC20TokenFacet(address(facet)).scopePaused(transferScope)) {
            AccountingSnapshot memory snapshot = _snapshotAccounting();
            VM.startPrank(from);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
            IERC20TokenFacet(address(facet)).transfer(to, value);
            VM.stopPrank();
            _assertAccountingUnchanged(snapshot, "paused transfer should not mutate accounting");
            return;
        }

        VM.prank(from);
        IERC20TokenFacet(address(facet)).transfer(to, value);
    }

    function actionTransferFrom(uint8 spenderSeed, uint8 ownerSeed, uint8 toSeed, uint96 valueRaw) external {
        address spender = _actor(spenderSeed);
        address owner = _actor(ownerSeed);
        address to = _actor(toSeed);
        if (owner == to || spender == owner) {
            return;
        }

        uint256 allowance = IERC20TokenFacet(address(facet)).allowance(owner, spender);
        uint256 balance = IERC20TokenFacet(address(facet)).balanceOf(owner);
        uint256 value = _boundAmount(valueRaw, allowance < balance ? allowance : balance);
        if (value == 0) {
            return;
        }

        bytes32 transferScope = IERC20TokenFacet(address(facet)).ERC20_TRANSFER_SCOPE();
        bytes32 approvalScope = IERC20TokenFacet(address(facet)).ERC20_APPROVAL_SCOPE();
        if (
            IERC20TokenFacet(address(facet)).scopePaused(transferScope)
                || IERC20TokenFacet(address(facet)).scopePaused(approvalScope)
        ) {
            bytes32 expectedScope =
                IERC20TokenFacet(address(facet)).scopePaused(approvalScope) ? approvalScope : transferScope;
            AccountingSnapshot memory snapshot = _snapshotAccounting();
            VM.startPrank(spender);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, expectedScope));
            IERC20TokenFacet(address(facet)).transferFrom(owner, to, value);
            VM.stopPrank();
            _assertAccountingUnchanged(snapshot, "paused transferFrom should not mutate accounting");
            return;
        }

        VM.prank(spender);
        IERC20TokenFacet(address(facet)).transferFrom(owner, to, value);
    }

    function actionMint(uint8 actorSeed, uint96 valueRaw) external {
        bytes32 transferScope = IERC20TokenFacet(address(facet)).ERC20_TRANSFER_SCOPE();
        uint256 value = uint256(valueRaw);
        if (value == 0) {
            return;
        }

        if (IERC20TokenFacet(address(facet)).scopePaused(transferScope)) {
            AccountingSnapshot memory snapshot = _snapshotAccounting();
            VM.prank(admin);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
            IERC20TokenFacet(address(facet)).mint(_actor(actorSeed), value);
            _assertAccountingUnchanged(snapshot, "paused mint should not mutate accounting");
            return;
        }

        VM.prank(admin);
        IERC20TokenFacet(address(facet)).mint(_actor(actorSeed), value);
    }

    function actionBurn(uint8 actorSeed, uint96 valueRaw) external {
        address actor = _actor(actorSeed);
        bytes32 transferScope = IERC20TokenFacet(address(facet)).ERC20_TRANSFER_SCOPE();
        uint256 value = _boundAmount(valueRaw, IERC20TokenFacet(address(facet)).balanceOf(actor));
        if (value == 0) {
            return;
        }

        if (IERC20TokenFacet(address(facet)).scopePaused(transferScope)) {
            AccountingSnapshot memory snapshot = _snapshotAccounting();
            VM.prank(admin);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
            IERC20TokenFacet(address(facet)).burn(actor, value);
            _assertAccountingUnchanged(snapshot, "paused burn should not mutate accounting");
            return;
        }

        VM.prank(admin);
        IERC20TokenFacet(address(facet)).burn(actor, value);
    }

    function actionSetApprovalScopePaused(bool paused_) external {
        bytes32 approvalScope = IERC20TokenFacet(address(facet)).ERC20_APPROVAL_SCOPE();
        bool isPaused = IERC20TokenFacet(address(facet)).scopePaused(approvalScope);
        if (paused_ && !isPaused) {
            VM.prank(admin);
            IERC20TokenFacet(address(facet)).pauseScope(approvalScope);
        } else if (!paused_ && isPaused) {
            VM.prank(admin);
            IERC20TokenFacet(address(facet)).unpauseScope(approvalScope);
        }
    }

    function actionSetTransferScopePaused(bool paused_) external {
        bytes32 transferScope = IERC20TokenFacet(address(facet)).ERC20_TRANSFER_SCOPE();
        bool isPaused = IERC20TokenFacet(address(facet)).scopePaused(transferScope);
        if (paused_ && !isPaused) {
            VM.prank(admin);
            IERC20TokenFacet(address(facet)).pauseScope(transferScope);
        } else if (!paused_ && isPaused) {
            VM.prank(admin);
            IERC20TokenFacet(address(facet)).unpauseScope(transferScope);
        }
    }

    function invariantTotalSupplyEqualsTrackedBalances() public view {
        assertTrue(
            IERC20TokenFacet(address(facet)).totalSupply() == _sumTrackedBalances(),
            "total supply must equal tracked balances"
        );
    }

    function invariantTrackedPermitNoncesMatchSuccessfulCalls() public view {
        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            address actor = actors[i];
            assertTrue(
                IERC20TokenFacet(address(facet)).nonces(actor) == trackedPermitSuccesses[actor],
                "tracked permit nonces must match successful permit calls"
            );
        }
    }
}
