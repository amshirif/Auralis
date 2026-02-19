// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {IERC4626VaultControls} from "../src/interfaces/IERC4626VaultControls.sol";
import {ERC4626VaultControlsFixture, ERC4626VaultControlsHarness} from "./helpers/ERC4626VaultControlsTestHarness.sol";

contract ERC4626VaultControlsCoreTest is ERC4626VaultControlsFixture {
    event VaultFeeConfigUpdated(
        uint16 previousDepositFeeBps,
        uint16 previousWithdrawFeeBps,
        address indexed previousFeeRecipient,
        uint16 newDepositFeeBps,
        uint16 newWithdrawFeeBps,
        address indexed newFeeRecipient,
        address indexed sender
    );

    event VaultLimitConfigUpdated(
        uint128 maxTotalAssets,
        uint128 maxDeposit,
        uint128 maxMint,
        uint128 maxWithdraw,
        uint128 maxRedeem,
        address indexed sender
    );

    function testInitialRolesAndDefaults() public view {
        assertTrue(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), admin), "missing default admin role");
        assertTrue(vault.hasRole(vault.PAUSER_ROLE(), admin), "missing pauser role");
        assertTrue(vault.hasRole(vault.VAULT_MANAGER_ROLE(), admin), "missing vault manager role");

        (uint16 depositFeeBps, uint16 withdrawFeeBps, address feeRecipient) = vault.feeConfig();
        assertTrue(depositFeeBps == 0, "unexpected default deposit fee");
        assertTrue(withdrawFeeBps == 0, "unexpected default withdraw fee");
        assertTrue(feeRecipient == admin, "unexpected default fee recipient");

        (uint128 maxTotalAssets, uint128 maxDeposit, uint128 maxMint, uint128 maxWithdraw, uint128 maxRedeem) =
            vault.limitConfig();
        assertTrue(maxTotalAssets == 0, "unexpected default max total assets");
        assertTrue(maxDeposit == 0, "unexpected default max deposit");
        assertTrue(maxMint == 0, "unexpected default max mint");
        assertTrue(maxWithdraw == 0, "unexpected default max withdraw");
        assertTrue(maxRedeem == 0, "unexpected default max redeem");
    }

    function testManagerCanSetFeeConfigAndEmitEvent() public {
        VM.expectEmit(false, false, true, true, address(vault));
        emit VaultFeeConfigUpdated(0, 0, admin, 500, 250, eve, admin);

        VM.prank(admin);
        vault.setFeeConfig(500, 250, eve);

        (uint16 depositFeeBps, uint16 withdrawFeeBps, address feeRecipient) = vault.feeConfig();
        assertTrue(depositFeeBps == 500, "deposit fee not updated");
        assertTrue(withdrawFeeBps == 250, "withdraw fee not updated");
        assertTrue(feeRecipient == eve, "fee recipient not updated");
    }

    function testNonManagerCannotSetFeeConfig() public {
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, eve, vault.VAULT_MANAGER_ROLE())
        );
        VM.prank(eve);
        vault.setFeeConfig(200, 100, eve);
    }

    function testInvalidFeeConfigReverts() public {
        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultInvalidFeeBps.selector, 10_000));
        vault.setFeeConfig(10_000, 0, admin);

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultInvalidFeeRecipient.selector));
        vault.setFeeConfig(100, 0, address(0));
    }

    function testManagerCanSetLimitConfigAndEmitEvent() public {
        VM.expectEmit(false, false, false, true, address(vault));
        emit VaultLimitConfigUpdated(1_000, 500, 300, 200, 100, admin);

        VM.prank(admin);
        vault.setLimitConfig(1_000, 500, 300, 200, 100);

        (uint128 maxTotalAssets, uint128 maxDeposit, uint128 maxMint, uint128 maxWithdraw, uint128 maxRedeem) =
            vault.limitConfig();
        assertTrue(maxTotalAssets == 1_000, "maxTotalAssets not updated");
        assertTrue(maxDeposit == 500, "maxDeposit not updated");
        assertTrue(maxMint == 300, "maxMint not updated");
        assertTrue(maxWithdraw == 200, "maxWithdraw not updated");
        assertTrue(maxRedeem == 100, "maxRedeem not updated");
    }

    function testNonManagerCannotSetLimitConfig() public {
        VM.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorized.selector, eve, vault.VAULT_MANAGER_ROLE())
        );
        VM.prank(eve);
        vault.setLimitConfig(1_000, 500, 300, 200, 100);
    }

    function testDepositAppliesConfiguredFee() public {
        VM.prank(admin);
        vault.setFeeConfig(1_000, 0, eve);

        _approveAsset(bob, 100);

        VM.prank(bob);
        uint256 shares = vault.deposit(100, bob);

        assertTrue(shares == 90, "deposit shares mismatch");
        assertTrue(vault.totalAssets() == 90, "total assets mismatch");
        assertTrue(vault.balanceOf(bob) == 90, "share balance mismatch");
        assertTrue(asset.balanceOf(eve) == INITIAL_ASSETS + 10, "fee recipient balance mismatch");
    }

    function testMintAppliesConfiguredFee() public {
        VM.prank(admin);
        vault.setFeeConfig(1_000, 0, eve);

        _approveAsset(bob, 1_000);

        VM.prank(bob);
        uint256 assetsIn = vault.mint(50, bob);

        assertTrue(assetsIn == 56, "mint assets mismatch");
        assertTrue(vault.totalAssets() == 50, "total assets mismatch");
        assertTrue(vault.balanceOf(bob) == 50, "share balance mismatch");
        assertTrue(asset.balanceOf(eve) == INITIAL_ASSETS + 6, "fee recipient balance mismatch");
    }

    function testWithdrawAppliesConfiguredFee() public {
        _seedPosition(bob, 100);

        VM.prank(admin);
        vault.setFeeConfig(0, 1_000, eve);

        VM.prank(bob);
        uint256 sharesBurned = vault.withdraw(20, bob, bob);

        assertTrue(sharesBurned == 22, "withdraw burned shares mismatch");
        assertTrue(vault.totalAssets() == 78, "total assets mismatch");
        assertTrue(vault.balanceOf(bob) == 78, "share balance mismatch");
        assertTrue(asset.balanceOf(eve) == INITIAL_ASSETS + 2, "fee recipient balance mismatch");
    }

    function testRedeemAppliesConfiguredFee() public {
        _seedPosition(bob, 100);

        VM.prank(admin);
        vault.setFeeConfig(0, 1_000, eve);

        VM.prank(bob);
        uint256 assetsOut = vault.redeem(20, bob, bob);

        assertTrue(assetsOut == 18, "redeem assets mismatch");
        assertTrue(vault.totalAssets() == 80, "total assets mismatch");
        assertTrue(vault.balanceOf(bob) == 80, "share balance mismatch");
        assertTrue(asset.balanceOf(eve) == INITIAL_ASSETS + 2, "fee recipient balance mismatch");
    }

    function testDepositLimitEnforced() public {
        VM.prank(admin);
        vault.setLimitConfig(0, 50, 0, 0, 0);

        _approveAsset(bob, 100);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultDepositLimitExceeded.selector, 51, 50));
        vault.deposit(51, bob);
    }

    function testMintLimitEnforced() public {
        VM.prank(admin);
        vault.setLimitConfig(0, 0, 30, 0, 0);

        _approveAsset(bob, 100);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultMintLimitExceeded.selector, 31, 30));
        vault.mint(31, bob);
    }

    function testWithdrawLimitEnforced() public {
        _seedPosition(bob, 100);

        VM.prank(admin);
        vault.setLimitConfig(0, 0, 0, 25, 0);

        VM.prank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultWithdrawLimitExceeded.selector, 26, 25)
        );
        vault.withdraw(26, bob, bob);
    }

    function testRedeemLimitEnforced() public {
        _seedPosition(bob, 100);

        VM.prank(admin);
        vault.setLimitConfig(0, 0, 0, 0, 20);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultRedeemLimitExceeded.selector, 21, 20));
        vault.redeem(21, bob, bob);
    }

    function testTotalAssetsCapShapesMaxDepositAndEnforcesDepositFlow() public {
        VM.prank(admin);
        vault.setLimitConfig(60, 0, 0, 0, 0);

        _approveAsset(bob, 100);

        VM.prank(bob);
        vault.deposit(50, bob);

        assertTrue(vault.maxDeposit(bob) == 10, "maxDeposit should honor remaining cap");

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultDepositLimitExceeded.selector, 11, 10));
        vault.deposit(11, bob);
    }

    function testPauseBlocksMutatingVaultFlows() public {
        _seedPosition(bob, 100);
        _approveAsset(bob, 100);

        VM.prank(admin);
        vault.pause();

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        vault.deposit(10, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        vault.mint(10, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        vault.withdraw(10, bob, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        vault.redeem(10, bob, bob);
    }

    function testReentrantAttemptDuringDepositIsBlocked() public {
        bytes memory payload = abi.encodeCall(ERC4626VaultControlsHarness.probeNonReentrant, ());
        asset.configureReentry(address(vault), payload, true);

        _approveAsset(bob, 100);

        VM.prank(bob);
        uint256 shares = vault.deposit(10, bob);

        assertTrue(shares == 10, "deposit should succeed");
        assertTrue(asset.reentryAttemptBlocked(), "expected reentry attempt to be blocked");
    }
}
