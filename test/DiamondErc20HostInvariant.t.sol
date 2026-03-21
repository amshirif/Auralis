// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20TokenFacet} from "../src/interfaces/IERC20TokenFacet.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {DiamondTokenHostHardeningFixture} from "./helpers/DiamondTokenHostHardeningTestHarness.sol";

contract DiamondErc20HostInvariantTest is DiamondTokenHostHardeningFixture {
    struct AccountingSnapshot {
        uint256 totalSupply;
        uint256 totalTrackedBalances;
    }

    uint256 internal constant ACTOR_COUNT = 5;
    uint256 internal constant INITIAL_BALANCE = 1_000_000;

    address[ACTOR_COUNT] internal actors;
    mapping(address => uint256) internal trackedPermitSuccesses;

    function setUp() public override {
        super.setUp();
        _installErc20HostFacet(address(erc20Facet));
        _erc20InitDiamond();

        actors[0] = admin;
        actors[1] = bob;
        actors[2] = eve;
        actors[3] = carol;
        actors[4] = dave;

        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            VM.prank(admin);
            IERC20TokenFacet(address(diamond)).mint(actors[i], INITIAL_BALANCE);
        }
    }

    function targetContracts() external view returns (address[] memory contracts) {
        contracts = new address[](1);
        contracts[0] = address(this);
    }

    function actionApprove(uint8 ownerSeed, uint8 spenderSeed, uint96 valueRaw) external {
        IERC20TokenFacet token = IERC20TokenFacet(address(diamond));
        address owner = _actor(ownerSeed);
        address spender = _actorExcluding(owner, spenderSeed);
        bytes32 approvalScope = token.ERC20_APPROVAL_SCOPE();
        uint256 value = uint256(valueRaw);

        if (token.scopePaused(approvalScope)) {
            AccountingSnapshot memory snapshot = _snapshotAccounting();
            VM.startPrank(owner);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, approvalScope));
            token.approve(spender, value);
            VM.stopPrank();
            _assertAccountingUnchanged(snapshot, "paused approve should not mutate accounting");
            return;
        }

        VM.prank(owner);
        token.approve(spender, value);
    }

    function actionPermit(uint8 ownerSeed, uint8 spenderSeed, uint96 valueRaw, uint32 deadlineOffsetRaw) external {
        IERC20TokenFacet token = IERC20TokenFacet(address(diamond));
        address owner = _actor(ownerSeed);
        address spender = _actorExcluding(owner, spenderSeed);
        bytes32 approvalScope = token.ERC20_APPROVAL_SCOPE();
        uint256 value = uint256(valueRaw);
        uint256 deadline = block.timestamp + uint256(deadlineOffsetRaw) + 1;
        uint256 nonce = token.nonces(owner);
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(address(diamond), owner, spender, value, nonce, deadline);

        if (token.scopePaused(approvalScope)) {
            AccountingSnapshot memory snapshot = _snapshotAccounting();
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, approvalScope));
            token.permit(owner, spender, value, deadline, v, r, s);
            _assertAccountingUnchanged(snapshot, "paused permit should not mutate accounting");
            return;
        }

        token.permit(owner, spender, value, deadline, v, r, s);
        trackedPermitSuccesses[owner] += 1;
    }

    function actionTransfer(uint8 fromSeed, uint8 toSeed, uint96 valueRaw) external {
        IERC20TokenFacet token = IERC20TokenFacet(address(diamond));
        address from = _actor(fromSeed);
        address to = _actorExcluding(from, toSeed);
        bytes32 transferScope = token.ERC20_TRANSFER_SCOPE();
        uint256 value = _boundAmount(valueRaw, token.balanceOf(from));
        if (value == 0) return;

        if (token.scopePaused(transferScope)) {
            AccountingSnapshot memory snapshot = _snapshotAccounting();
            VM.startPrank(from);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
            token.transfer(to, value);
            VM.stopPrank();
            _assertAccountingUnchanged(snapshot, "paused transfer should not mutate accounting");
            return;
        }

        VM.prank(from);
        token.transfer(to, value);
    }

    function actionTransferFrom(uint8 spenderSeed, uint8 ownerSeed, uint8 toSeed, uint96 valueRaw) external {
        IERC20TokenFacet token = IERC20TokenFacet(address(diamond));
        address spender = _actor(spenderSeed);
        address owner = _actor(ownerSeed);
        address to = _actorExcluding(owner, toSeed);
        if (spender == owner) return;

        uint256 allowance = token.allowance(owner, spender);
        uint256 balance = token.balanceOf(owner);
        uint256 value = _boundAmount(valueRaw, allowance < balance ? allowance : balance);
        if (value == 0) return;

        bytes32 transferScope = token.ERC20_TRANSFER_SCOPE();
        bytes32 approvalScope = token.ERC20_APPROVAL_SCOPE();
        if (token.scopePaused(transferScope) || token.scopePaused(approvalScope)) {
            bytes32 expectedScope = token.scopePaused(approvalScope) ? approvalScope : transferScope;
            AccountingSnapshot memory snapshot = _snapshotAccounting();
            VM.startPrank(spender);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, expectedScope));
            token.transferFrom(owner, to, value);
            VM.stopPrank();
            _assertAccountingUnchanged(snapshot, "paused transferFrom should not mutate accounting");
            return;
        }

        VM.prank(spender);
        token.transferFrom(owner, to, value);
    }

    function actionMint(uint8 actorSeed, uint96 valueRaw) external {
        IERC20TokenFacet token = IERC20TokenFacet(address(diamond));
        bytes32 transferScope = token.ERC20_TRANSFER_SCOPE();
        uint256 value = uint256(valueRaw);
        if (value == 0) return;

        if (token.scopePaused(transferScope)) {
            AccountingSnapshot memory snapshot = _snapshotAccounting();
            VM.prank(admin);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
            token.mint(_actor(actorSeed), value);
            _assertAccountingUnchanged(snapshot, "paused mint should not mutate accounting");
            return;
        }

        VM.prank(admin);
        token.mint(_actor(actorSeed), value);
    }

    function actionBurn(uint8 actorSeed, uint96 valueRaw) external {
        IERC20TokenFacet token = IERC20TokenFacet(address(diamond));
        address actor = _actor(actorSeed);
        bytes32 transferScope = token.ERC20_TRANSFER_SCOPE();
        uint256 value = _boundAmount(valueRaw, token.balanceOf(actor));
        if (value == 0) return;

        if (token.scopePaused(transferScope)) {
            AccountingSnapshot memory snapshot = _snapshotAccounting();
            VM.prank(admin);
            VM.expectRevert(abi.encodeWithSelector(IPausable.PausableScopeEnforcedPause.selector, transferScope));
            token.burn(actor, value);
            _assertAccountingUnchanged(snapshot, "paused burn should not mutate accounting");
            return;
        }

        VM.prank(admin);
        token.burn(actor, value);
    }

    function actionSetApprovalScopePaused(bool paused_) external {
        IERC20TokenFacet token = IERC20TokenFacet(address(diamond));
        bytes32 approvalScope = token.ERC20_APPROVAL_SCOPE();
        bool isPaused = token.scopePaused(approvalScope);
        if (paused_ && !isPaused) {
            VM.prank(admin);
            token.pauseScope(approvalScope);
        } else if (!paused_ && isPaused) {
            VM.prank(admin);
            token.unpauseScope(approvalScope);
        }
    }

    function actionSetTransferScopePaused(bool paused_) external {
        IERC20TokenFacet token = IERC20TokenFacet(address(diamond));
        bytes32 transferScope = token.ERC20_TRANSFER_SCOPE();
        bool isPaused = token.scopePaused(transferScope);
        if (paused_ && !isPaused) {
            VM.prank(admin);
            token.pauseScope(transferScope);
        } else if (!paused_ && isPaused) {
            VM.prank(admin);
            token.unpauseScope(transferScope);
        }
    }

    function invariantTotalSupplyEqualsTrackedBalances() public view {
        assertTrue(
            IERC20TokenFacet(address(diamond)).totalSupply() == _sumTrackedBalances(),
            "host total supply must equal tracked balances"
        );
    }

    function invariantTrackedPermitNoncesMatchSuccessfulCalls() public view {
        IERC20TokenFacet token = IERC20TokenFacet(address(diamond));
        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            address actor = actors[i];
            assertTrue(
                token.nonces(actor) == trackedPermitSuccesses[actor],
                "host permit nonces must match successful permit calls"
            );
        }
    }

    function _boundAmount(uint256 raw, uint256 max) internal pure returns (uint256) {
        if (max == 0) return 0;
        return (raw % max) + 1;
    }

    function _sumTrackedBalances() internal view returns (uint256 sum) {
        IERC20TokenFacet token = IERC20TokenFacet(address(diamond));
        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            sum += token.balanceOf(actors[i]);
        }
    }

    function _snapshotAccounting() internal view returns (AccountingSnapshot memory snapshot) {
        IERC20TokenFacet token = IERC20TokenFacet(address(diamond));
        snapshot.totalSupply = token.totalSupply();
        snapshot.totalTrackedBalances = _sumTrackedBalances();
    }

    function _assertAccountingUnchanged(AccountingSnapshot memory snapshot, string memory reason) internal view {
        IERC20TokenFacet token = IERC20TokenFacet(address(diamond));
        assertTrue(token.totalSupply() == snapshot.totalSupply, reason);
        assertTrue(_sumTrackedBalances() == snapshot.totalTrackedBalances, reason);
    }
}
