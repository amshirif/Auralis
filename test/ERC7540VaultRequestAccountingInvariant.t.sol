// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC7540VaultFoundationFixture} from "./helpers/ERC7540VaultFoundationTestHarness.sol";

contract ERC7540VaultRequestAccountingInvariantTest is ERC7540VaultFoundationFixture {
    address[] internal controllers;
    address[] internal operators;

    mapping(address controller => uint256 assets) internal expectedPendingDeposit;
    mapping(address controller => uint256 assets) internal expectedClaimableDeposit;
    mapping(address controller => uint256 shares) internal expectedPendingRedeem;
    mapping(address controller => uint256 shares) internal expectedClaimableRedeem;
    mapping(address controller => mapping(address operator => bool approved)) internal expectedOperators;

    function setUp() public override {
        super.setUp();

        controllers = new address[](3);
        controllers[0] = bob;
        controllers[1] = carol;
        controllers[2] = eve;

        operators = new address[](3);
        operators[0] = address(0xA11CE);
        operators[1] = address(0xD00D);
        operators[2] = address(0xF00D);
    }

    function targetContracts() external view returns (address[] memory contracts) {
        contracts = new address[](1);
        contracts[0] = address(this);
    }

    function actionIncreasePendingDeposit(uint8 controllerSeed, uint96 assetsRaw) external {
        address controller = _controller(controllerSeed);
        uint256 assets = _boundedAmount(assetsRaw);

        harness.increasePendingDeposit(controller, assets);
        expectedPendingDeposit[controller] += assets;
    }

    function actionMovePendingDepositToClaimable(uint8 controllerSeed, uint96 assetsRaw) external {
        address controller = _controller(controllerSeed);
        uint256 assets = _boundedExistingAmount(assetsRaw, expectedPendingDeposit[controller]);
        if (assets == 0) {
            return;
        }

        harness.movePendingDepositToClaimable(controller, assets);
        expectedPendingDeposit[controller] -= assets;
        expectedClaimableDeposit[controller] += assets;
    }

    function actionConsumeClaimableDeposit(uint8 controllerSeed, uint96 assetsRaw) external {
        address controller = _controller(controllerSeed);
        uint256 assets = _boundedExistingAmount(assetsRaw, expectedClaimableDeposit[controller]);
        if (assets == 0) {
            return;
        }

        harness.consumeClaimableDeposit(controller, assets);
        expectedClaimableDeposit[controller] -= assets;
    }

    function actionIncreasePendingRedeem(uint8 controllerSeed, uint96 sharesRaw) external {
        address controller = _controller(controllerSeed);
        uint256 shares = _boundedAmount(sharesRaw);

        harness.increasePendingRedeem(controller, shares);
        expectedPendingRedeem[controller] += shares;
    }

    function actionMovePendingRedeemToClaimable(uint8 controllerSeed, uint96 sharesRaw) external {
        address controller = _controller(controllerSeed);
        uint256 shares = _boundedExistingAmount(sharesRaw, expectedPendingRedeem[controller]);
        if (shares == 0) {
            return;
        }

        harness.movePendingRedeemToClaimable(controller, shares);
        expectedPendingRedeem[controller] -= shares;
        expectedClaimableRedeem[controller] += shares;
    }

    function actionConsumeClaimableRedeem(uint8 controllerSeed, uint96 sharesRaw) external {
        address controller = _controller(controllerSeed);
        uint256 shares = _boundedExistingAmount(sharesRaw, expectedClaimableRedeem[controller]);
        if (shares == 0) {
            return;
        }

        harness.consumeClaimableRedeem(controller, shares);
        expectedClaimableRedeem[controller] -= shares;
    }

    function actionSetOperator(uint8 controllerSeed, uint8 operatorSeed, bool approved) external {
        address controller = _controller(controllerSeed);
        address operator = _operator(operatorSeed);

        VM.prank(controller);
        harness.setOperator(operator, approved);
        expectedOperators[controller][operator] = approved;
    }

    function invariantAggregateDepositTotalsMatchTrackedControllers() public view {
        uint256 pendingTotal;
        uint256 claimableTotal;
        for (uint256 i = 0; i < controllers.length; i++) {
            address controller = controllers[i];
            pendingTotal += expectedPendingDeposit[controller];
            claimableTotal += expectedClaimableDeposit[controller];

            assertTrue(
                harness.pendingDepositRequest(0, controller) == expectedPendingDeposit[controller],
                "pending deposit controller bucket mismatch"
            );
            assertTrue(
                harness.claimableDepositRequest(0, controller) == expectedClaimableDeposit[controller],
                "claimable deposit controller bucket mismatch"
            );
        }

        assertTrue(harness.totalPendingDepositRequestAssets() == pendingTotal, "pending deposit total mismatch");
        assertTrue(harness.totalClaimableDepositRequestAssets() == claimableTotal, "claimable deposit total mismatch");
    }

    function invariantAggregateRedeemTotalsMatchTrackedControllers() public view {
        uint256 pendingTotal;
        uint256 claimableTotal;
        for (uint256 i = 0; i < controllers.length; i++) {
            address controller = controllers[i];
            pendingTotal += expectedPendingRedeem[controller];
            claimableTotal += expectedClaimableRedeem[controller];

            assertTrue(
                harness.pendingRedeemRequest(0, controller) == expectedPendingRedeem[controller],
                "pending redeem controller bucket mismatch"
            );
            assertTrue(
                harness.claimableRedeemRequest(0, controller) == expectedClaimableRedeem[controller],
                "claimable redeem controller bucket mismatch"
            );
        }

        assertTrue(harness.totalPendingRedeemRequestShares() == pendingTotal, "pending redeem total mismatch");
        assertTrue(harness.totalClaimableRedeemRequestShares() == claimableTotal, "claimable redeem total mismatch");
    }

    function invariantUnsupportedRequestIdsAlwaysReadZero() public view {
        for (uint256 i = 0; i < controllers.length; i++) {
            address controller = controllers[i];
            assertTrue(harness.pendingDepositRequest(1, controller) == 0, "nonzero pending deposit id should be zero");
            assertTrue(
                harness.claimableDepositRequest(2, controller) == 0, "nonzero claimable deposit id should be zero"
            );
            assertTrue(harness.pendingRedeemRequest(3, controller) == 0, "nonzero pending redeem id should be zero");
            assertTrue(harness.claimableRedeemRequest(4, controller) == 0, "nonzero claimable redeem id should be zero");
        }
    }

    function invariantDepositAndRedeemBucketsStayIsolated() public view {
        address untouched = address(0xDEAD);
        assertTrue(harness.pendingDepositRequest(0, untouched) == 0, "untouched pending deposit should stay zero");
        assertTrue(harness.claimableDepositRequest(0, untouched) == 0, "untouched claimable deposit should stay zero");
        assertTrue(harness.pendingRedeemRequest(0, untouched) == 0, "untouched pending redeem should stay zero");
        assertTrue(harness.claimableRedeemRequest(0, untouched) == 0, "untouched claimable redeem should stay zero");
    }

    function invariantOperatorApprovalsArePairScoped() public view {
        for (uint256 i = 0; i < controllers.length; i++) {
            for (uint256 j = 0; j < operators.length; j++) {
                address controller = controllers[i];
                address operator = operators[j];
                assertTrue(
                    harness.isOperator(controller, operator) == expectedOperators[controller][operator],
                    "operator approval mismatch"
                );
            }
        }
    }

    function _controller(uint8 seed) internal view returns (address) {
        return controllers[uint256(seed) % controllers.length];
    }

    function _operator(uint8 seed) internal view returns (address) {
        return operators[uint256(seed) % operators.length];
    }

    function _boundedAmount(uint256 raw) internal pure returns (uint256) {
        return (raw % 1_000) + 1;
    }

    function _boundedExistingAmount(uint256 raw, uint256 available) internal pure returns (uint256) {
        if (available == 0) {
            return 0;
        }
        return (raw % available) + 1;
    }
}
