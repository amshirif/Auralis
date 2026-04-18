// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibERC7540RequestAccounting} from "../../src/vault/libraries/LibERC7540RequestAccounting.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

contract ERC7540VaultFoundationHarness {
    function aggregateRequestId() external pure returns (uint256 requestId) {
        return LibERC7540RequestAccounting.aggregateRequestId();
    }

    function requireAggregateRequestId(uint256 requestId) external pure {
        LibERC7540RequestAccounting.requireAggregateRequestId(requestId);
    }

    function pendingDepositRequest(uint256 requestId, address controller) external view returns (uint256 assets) {
        return LibERC7540RequestAccounting.pendingDepositRequest(requestId, controller);
    }

    function claimableDepositRequest(uint256 requestId, address controller) external view returns (uint256 assets) {
        return LibERC7540RequestAccounting.claimableDepositRequest(requestId, controller);
    }

    function pendingRedeemRequest(uint256 requestId, address controller) external view returns (uint256 shares) {
        return LibERC7540RequestAccounting.pendingRedeemRequest(requestId, controller);
    }

    function claimableRedeemRequest(uint256 requestId, address controller) external view returns (uint256 shares) {
        return LibERC7540RequestAccounting.claimableRedeemRequest(requestId, controller);
    }

    function isOperator(address controller, address operator) external view returns (bool status) {
        return LibERC7540RequestAccounting.isOperator(controller, operator);
    }

    function setOperator(address operator, bool approved) external returns (bool success) {
        LibERC7540RequestAccounting.setOperator(msg.sender, operator, approved);
        return true;
    }

    function increasePendingDeposit(address controller, uint256 assets) external {
        LibERC7540RequestAccounting.increasePendingDeposit(controller, assets);
    }

    function movePendingDepositToClaimable(address controller, uint256 assets) external {
        LibERC7540RequestAccounting.movePendingDepositToClaimable(controller, assets);
    }

    function consumeClaimableDeposit(address controller, uint256 assets) external {
        LibERC7540RequestAccounting.consumeClaimableDeposit(controller, assets);
    }

    function increasePendingRedeem(address controller, uint256 shares) external {
        LibERC7540RequestAccounting.increasePendingRedeem(controller, shares);
    }

    function movePendingRedeemToClaimable(address controller, uint256 shares) external {
        LibERC7540RequestAccounting.movePendingRedeemToClaimable(controller, shares);
    }

    function consumeClaimableRedeem(address controller, uint256 shares) external {
        LibERC7540RequestAccounting.consumeClaimableRedeem(controller, shares);
    }

    function totalPendingDepositRequestAssets() external view returns (uint256 assets) {
        return LibERC7540RequestAccounting.totalPendingDepositRequestAssets();
    }

    function totalClaimableDepositRequestAssets() external view returns (uint256 assets) {
        return LibERC7540RequestAccounting.totalClaimableDepositRequestAssets();
    }

    function totalPendingRedeemRequestShares() external view returns (uint256 shares) {
        return LibERC7540RequestAccounting.totalPendingRedeemRequestShares();
    }

    function totalClaimableRedeemRequestShares() external view returns (uint256 shares) {
        return LibERC7540RequestAccounting.totalClaimableRedeemRequestShares();
    }
}

abstract contract ERC7540VaultFoundationFixture is TestBase {
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA401);
    address internal eve = address(0xE11E);

    ERC7540VaultFoundationHarness internal harness;

    function setUp() public virtual {
        harness = new ERC7540VaultFoundationHarness();
    }
}
