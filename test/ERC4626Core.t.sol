// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626VaultBase} from "../src/interfaces/IERC4626VaultBase.sol";
import {ERC4626Vault} from "../src/vault/ERC4626Vault.sol";
import {ERC4626CoreFixture} from "./helpers/ERC4626CoreTestHarness.sol";

contract ERC4626CoreTest is ERC4626CoreFixture {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    function testPreviewAndConvertBootstrapOneToOne() public view {
        assertTrue(vault.convertToShares(8) == 8, "convertToShares bootstrap mismatch");
        assertTrue(vault.convertToAssets(8) == 8, "convertToAssets bootstrap mismatch");
        assertTrue(vault.previewDeposit(8) == 8, "previewDeposit bootstrap mismatch");
        assertTrue(vault.previewMint(8) == 8, "previewMint bootstrap mismatch");
        assertTrue(vault.previewWithdraw(8) == 8, "previewWithdraw bootstrap mismatch");
        assertTrue(vault.previewRedeem(8) == 8, "previewRedeem bootstrap mismatch");
    }

    function testPreviewAndConvertRespectRoundingDirection() public {
        _seedPosition(admin, 3, 2);

        assertTrue(vault.convertToShares(1) == 1, "convertToShares down mismatch");
        assertTrue(vault.convertToAssets(1) == 0, "convertToAssets down mismatch");
        assertTrue(vault.previewDeposit(1) == 1, "previewDeposit down mismatch");
        assertTrue(vault.previewMint(1) == 1, "previewMint up mismatch");
        assertTrue(vault.previewWithdraw(1) == 2, "previewWithdraw up mismatch");
        assertTrue(vault.previewRedeem(1) == 0, "previewRedeem down mismatch");
    }

    function testMaxFunctions() public {
        _seedPosition(bob, 3, 2);

        assertTrue(vault.maxDeposit(bob) == type(uint256).max, "maxDeposit mismatch");
        assertTrue(vault.maxMint(bob) == type(uint256).max, "maxMint mismatch");
        assertTrue(vault.maxDeposit(address(0)) == 0, "maxDeposit zero receiver mismatch");
        assertTrue(vault.maxMint(address(0)) == 0, "maxMint zero receiver mismatch");

        assertTrue(vault.maxWithdraw(bob) == 2, "maxWithdraw mismatch");
        assertTrue(vault.maxRedeem(bob) == 3, "maxRedeem mismatch");
        assertTrue(vault.maxWithdraw(address(0)) == 0, "maxWithdraw zero owner mismatch");
        assertTrue(vault.maxRedeem(address(0)) == 0, "maxRedeem zero owner mismatch");
    }

    function testDepositMintsSharesForReceiver() public {
        _approveAsset(bob, 20);

        VM.prank(bob);
        uint256 shares = vault.deposit(10, eve);

        assertTrue(shares == 10, "shares mismatch");
        assertTrue(vault.balanceOf(eve) == 10, "receiver share balance mismatch");
        assertTrue(vault.totalSupply() == 10, "total supply mismatch");
        assertTrue(vault.totalAssets() == 10, "total assets mismatch");
        assertTrue(asset.balanceOf(address(vault)) == 10, "vault asset balance mismatch");
        assertTrue(asset.balanceOf(bob) == INITIAL_ASSETS - 10, "caller asset balance mismatch");
    }

    function testDepositEmitsErc20AndErc4626Events() public {
        _approveAsset(bob, 10);

        VM.expectEmit(true, true, false, true, address(vault));
        emit Transfer(address(0), eve, 10);
        VM.expectEmit(true, true, false, true, address(vault));
        emit Deposit(bob, eve, 10, 10);

        VM.prank(bob);
        vault.deposit(10, eve);
    }

    function testMintPullsRoundedUpAssets() public {
        _seedPosition(admin, 3, 2);
        _approveAsset(bob, 10);

        VM.prank(bob);
        uint256 assetsUsed = vault.mint(2, eve);

        assertTrue(assetsUsed == 2, "assets used mismatch");
        assertTrue(vault.balanceOf(eve) == 2, "receiver share balance mismatch");
        assertTrue(vault.totalSupply() == 5, "total supply mismatch");
        assertTrue(vault.totalAssets() == 4, "total assets mismatch");
        assertTrue(asset.balanceOf(address(vault)) == 4, "vault asset balance mismatch");
    }

    function testWithdrawBurnsOwnerSharesAndTransfersAssets() public {
        _seedPosition(bob, 10, 10);

        VM.prank(bob);
        uint256 burnedShares = vault.withdraw(4, eve, bob);

        assertTrue(burnedShares == 4, "burned shares mismatch");
        assertTrue(vault.balanceOf(bob) == 6, "owner share balance mismatch");
        assertTrue(vault.totalSupply() == 6, "total supply mismatch");
        assertTrue(vault.totalAssets() == 6, "total assets mismatch");
        assertTrue(asset.balanceOf(eve) == INITIAL_ASSETS + 4, "receiver asset balance mismatch");
    }

    function testWithdrawEmitsErc20AndErc4626Events() public {
        _seedPosition(bob, 10, 10);

        VM.expectEmit(true, true, false, true, address(vault));
        emit Transfer(bob, address(0), 4);
        VM.expectEmit(true, true, true, true, address(vault));
        emit Withdraw(bob, eve, bob, 4, 4);

        VM.prank(bob);
        vault.withdraw(4, eve, bob);
    }

    function testWithdrawByApprovedSpenderUsesOwnerAllowance() public {
        _seedPosition(bob, 10, 10);

        VM.prank(bob);
        vault.approve(eve, 5);

        VM.prank(eve);
        uint256 burnedShares = vault.withdraw(4, admin, bob);

        assertTrue(burnedShares == 4, "burned shares mismatch");
        assertTrue(vault.allowance(bob, eve) == 1, "allowance mismatch");
        assertTrue(vault.balanceOf(bob) == 6, "owner share balance mismatch");
        assertTrue(asset.balanceOf(admin) == 4, "receiver asset balance mismatch");
    }

    function testWithdrawWithoutAllowanceReverts() public {
        _seedPosition(bob, 10, 10);

        VM.prank(eve);
        VM.expectRevert(
            abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultInsufficientAllowance.selector, bob, eve, 0, 1)
        );
        vault.withdraw(1, eve, bob);
    }

    function testRedeemBurnsSharesAndReturnsAssets() public {
        _seedPosition(bob, 10, 10);

        VM.prank(bob);
        uint256 assetsOut = vault.redeem(3, eve, bob);

        assertTrue(assetsOut == 3, "assets out mismatch");
        assertTrue(vault.balanceOf(bob) == 7, "owner share balance mismatch");
        assertTrue(vault.totalSupply() == 7, "total supply mismatch");
        assertTrue(vault.totalAssets() == 7, "total assets mismatch");
        assertTrue(asset.balanceOf(eve) == INITIAL_ASSETS + 3, "receiver asset balance mismatch");
    }

    function testRedeemByApprovedSpenderUsesOwnerAllowance() public {
        _seedPosition(bob, 10, 10);

        VM.prank(bob);
        vault.approve(eve, 4);

        VM.prank(eve);
        uint256 assetsOut = vault.redeem(4, admin, bob);

        assertTrue(assetsOut == 4, "assets out mismatch");
        assertTrue(vault.allowance(bob, eve) == 0, "allowance mismatch");
        assertTrue(vault.balanceOf(bob) == 6, "owner share balance mismatch");
        assertTrue(asset.balanceOf(admin) == 4, "receiver asset balance mismatch");
    }

    function testRedeemWithoutAllowanceReverts() public {
        _seedPosition(bob, 10, 10);

        VM.prank(eve);
        VM.expectRevert(
            abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultInsufficientAllowance.selector, bob, eve, 0, 1)
        );
        vault.redeem(1, eve, bob);
    }

    function testShareApproveAndTransferFromFlow() public {
        _seedPosition(bob, 8, 8);

        VM.expectEmit(true, true, false, true, address(vault));
        emit Approval(bob, eve, 3);
        VM.prank(bob);
        vault.approve(eve, 3);

        VM.prank(eve);
        bool transferSuccess = vault.transferFrom(bob, admin, 2);

        assertTrue(transferSuccess, "transferFrom should succeed");
        assertTrue(vault.balanceOf(bob) == 6, "owner share balance mismatch");
        assertTrue(vault.balanceOf(admin) == 2, "recipient share balance mismatch");
        assertTrue(vault.allowance(bob, eve) == 1, "allowance mismatch");
    }

    function testZeroAddressGuards() public {
        _approveAsset(bob, 10);
        _seedPosition(bob, 1, 1);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultZeroAddress.selector));
        vault.deposit(1, address(0));

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultZeroAddress.selector));
        vault.mint(1, address(0));

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultZeroAddress.selector));
        vault.withdraw(1, address(0), bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultZeroAddress.selector));
        vault.withdraw(1, eve, address(0));

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultZeroAddress.selector));
        vault.redeem(1, address(0), bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultZeroAddress.selector));
        vault.redeem(1, eve, address(0));
    }

    function testZeroValueGuards() public {
        _approveAsset(bob, 10);
        _seedPosition(bob, 1, 1);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(ERC4626Vault.ERC4626VaultZeroAssets.selector));
        vault.deposit(0, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(ERC4626Vault.ERC4626VaultZeroShares.selector));
        vault.mint(0, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(ERC4626Vault.ERC4626VaultZeroAssets.selector));
        vault.withdraw(0, bob, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(ERC4626Vault.ERC4626VaultZeroShares.selector));
        vault.redeem(0, bob, bob);
    }

    function testDepositRevertsWhenTransferFromFails() public {
        _approveAsset(bob, 10);
        asset.setFailTransferFrom(true);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(ERC4626Vault.ERC4626VaultAssetTransferFromFailed.selector));
        vault.deposit(1, bob);
    }

    function testWithdrawRevertsWhenTransferFails() public {
        _seedPosition(bob, 5, 5);
        asset.setFailTransfer(true);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(ERC4626Vault.ERC4626VaultAssetTransferFailed.selector));
        vault.withdraw(1, bob, bob);
    }

    function testRedeemRevertsWhenRoundedAssetsIsZero() public {
        _seedPosition(bob, 3, 2);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(ERC4626Vault.ERC4626VaultZeroAssets.selector));
        vault.redeem(1, bob, bob);
    }
}
