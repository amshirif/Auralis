// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IAccessControlTime} from "../src/interfaces/IAccessControlTime.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IERC4626} from "../src/interfaces/IERC4626.sol";
import {IERC4626VaultBase} from "../src/interfaces/IERC4626VaultBase.sol";
import {IERC4626VaultControls} from "../src/interfaces/IERC4626VaultControls.sol";
import {IERC4626VaultControlsFacet} from "../src/interfaces/IERC4626VaultControlsFacet.sol";
import {IERC4626VaultFacet} from "../src/interfaces/IERC4626VaultFacet.sol";
import {IERC7535VaultFacet} from "../src/interfaces/IERC7535VaultFacet.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {IReentrancyGuard} from "../src/interfaces/IReentrancyGuard.sol";
import {LibVaultFacetSelectors} from "../src/vault/libraries/LibVaultFacetSelectors.sol";
import {LibVaultAsset} from "../src/vault/libraries/LibVaultAsset.sol";
import {LibERC4626VaultStorage} from "../src/vault/storage/LibERC4626VaultStorage.sol";
import {ERC4626VaultControlsFacetFixture} from "./helpers/ERC4626VaultControlsFacetTestHarness.sol";

contract ERC4626VaultControlsFacetCoreTest is ERC4626VaultControlsFacetFixture {
    function testDirectControlsFacetReadWriteAndInterfaceSupportAfterTestInit() public {
        _initializeDirectControlsFacet();

        assertTrue(controlsFacet.hasRole(controlsFacet.DEFAULT_ADMIN_ROLE(), admin), "missing default admin role");
        assertTrue(controlsFacet.hasRole(controlsFacet.PAUSER_ROLE(), admin), "missing pauser role");
        assertTrue(controlsFacet.hasRole(controlsFacet.VAULT_MANAGER_ROLE(), admin), "missing vault manager role");
        assertFalse(controlsFacet.reentrancyGuardEntered(), "reentrancy guard should be idle");

        (uint16 depositFeeBps, uint16 withdrawFeeBps, address feeRecipient) = controlsFacet.feeConfig();
        assertTrue(depositFeeBps == 0, "unexpected deposit fee");
        assertTrue(withdrawFeeBps == 0, "unexpected withdraw fee");
        assertTrue(feeRecipient == admin, "unexpected fee recipient");

        (uint128 maxTotalAssets, uint128 maxDeposit, uint128 maxMint, uint128 maxWithdraw, uint128 maxRedeem) =
            controlsFacet.limitConfig();
        assertTrue(maxTotalAssets == 0, "unexpected max total assets");
        assertTrue(maxDeposit == 0, "unexpected max deposit");
        assertTrue(maxMint == 0, "unexpected max mint");
        assertTrue(maxWithdraw == 0, "unexpected max withdraw");
        assertTrue(maxRedeem == 0, "unexpected max redeem");

        assertTrue(controlsFacet.supportsInterface(type(IERC165).interfaceId), "erc165 unsupported");
        assertTrue(controlsFacet.supportsInterface(type(IERC4626VaultControls).interfaceId), "controls unsupported");
        assertTrue(
            controlsFacet.supportsInterface(type(IERC4626VaultControlsFacet).interfaceId), "controls facet unsupported"
        );
        assertTrue(controlsFacet.supportsInterface(type(IAccessControl).interfaceId), "access control unsupported");
        assertTrue(
            controlsFacet.supportsInterface(type(IAccessControlTime).interfaceId), "access control time unsupported"
        );
        assertTrue(controlsFacet.supportsInterface(type(IPausable).interfaceId), "pausable unsupported");
        assertTrue(controlsFacet.supportsInterface(type(IReentrancyGuard).interfaceId), "reentrancy unsupported");
        assertFalse(controlsFacet.supportsInterface(type(IERC4626).interfaceId), "erc4626 should not be reported");

        VM.prank(admin);
        controlsFacet.setFeeConfig(500, 250, eve);
        VM.prank(admin);
        controlsFacet.setLimitConfig(1_000, 500, 300, 200, 100);

        (depositFeeBps, withdrawFeeBps, feeRecipient) = controlsFacet.feeConfig();
        assertTrue(depositFeeBps == 500, "deposit fee not updated");
        assertTrue(withdrawFeeBps == 250, "withdraw fee not updated");
        assertTrue(feeRecipient == eve, "fee recipient not updated");

        (maxTotalAssets, maxDeposit, maxMint, maxWithdraw, maxRedeem) = controlsFacet.limitConfig();
        assertTrue(maxTotalAssets == 1_000, "max total assets not updated");
        assertTrue(maxDeposit == 500, "max deposit not updated");
        assertTrue(maxMint == 300, "max mint not updated");
        assertTrue(maxWithdraw == 200, "max withdraw not updated");
        assertTrue(maxRedeem == 100, "max redeem not updated");
    }

    function testDirectControlsFacetStorageLayoutRemainsFrozenForFeesAndLimits() public {
        _initializeDirectControlsFacet();

        VM.prank(admin);
        controlsFacet.setFeeConfig(500, 250, eve);
        VM.prank(admin);
        controlsFacet.setLimitConfig(1_000, 500, 300, 200, 100);

        bytes32 baseSlot = LibERC4626VaultStorage.STORAGE_SLOT;

        uint256 feeSlot = uint256(VM.load(address(controlsFacet), bytes32(uint256(baseSlot) + 7)));
        uint256 expectedFeeSlot = uint256(500) | (uint256(250) << 16) | (uint256(uint160(eve)) << 32);
        assertTrue(feeSlot == expectedFeeSlot, "fee config slot mismatch");

        uint256 limitSlot0 = uint256(VM.load(address(controlsFacet), bytes32(uint256(baseSlot) + 8)));
        uint256 expectedLimitSlot0 = uint256(uint128(1_000)) | (uint256(uint128(500)) << 128);
        assertTrue(limitSlot0 == expectedLimitSlot0, "limit config slot 0 mismatch");

        uint256 limitSlot1 = uint256(VM.load(address(controlsFacet), bytes32(uint256(baseSlot) + 9)));
        uint256 expectedLimitSlot1 = uint256(uint128(300)) | (uint256(uint128(200)) << 128);
        assertTrue(limitSlot1 == expectedLimitSlot1, "limit config slot 1 mismatch");

        assertTrue(
            VM.load(address(controlsFacet), bytes32(uint256(baseSlot) + 10)) == bytes32(uint256(100)),
            "limit config slot 2 mismatch"
        );
    }

    function testDirectControlsFacetRejectsInvalidFeeConfigAndNonManagerCalls() public {
        _initializeDirectControlsFacet();

        VM.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorized.selector, eve, controlsFacet.VAULT_MANAGER_ROLE()
            )
        );
        VM.prank(eve);
        controlsFacet.setFeeConfig(100, 0, eve);

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultInvalidFeeBps.selector, 10_000));
        controlsFacet.setFeeConfig(10_000, 0, admin);

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultInvalidFeeRecipient.selector));
        controlsFacet.setFeeConfig(100, 0, address(0));
    }

    function testDirectControlsFacetPauseAndRoleWindowSmoke() public {
        _initializeDirectControlsFacet();
        bytes32 scope = keccak256("ops");

        VM.prank(admin);
        controlsFacet.pauseScope(scope);
        assertTrue(controlsFacet.scopePaused(scope), "scope should be paused");
        assertTrue(controlsFacet.paused(scope), "effective scope pause mismatch");
        assertFalse(controlsFacet.paused(), "global pause should remain unset");

        VM.prank(admin);
        controlsFacet.unpauseScope(scope);
        assertFalse(controlsFacet.scopePaused(scope), "scope should be unpaused");

        VM.prank(admin);
        controlsFacet.pause();
        assertTrue(controlsFacet.paused(), "global pause should be set");

        VM.prank(admin);
        controlsFacet.unpause();
        assertFalse(controlsFacet.paused(), "global pause should clear");

        bytes32 managerRole = controlsFacet.VAULT_MANAGER_ROLE();

        VM.prank(admin);
        controlsFacet.grantRoleWithWindow(managerRole, eve, 100, 200);
        assertTrue(controlsFacet.hasRole(managerRole, eve), "manager role missing");

        (uint64 start, uint64 end, bool exists) = controlsFacet.getRoleWindow(managerRole, eve);
        assertTrue(exists, "window should exist");
        assertTrue(start == 100, "window start mismatch");
        assertTrue(end == 200, "window end mismatch");

        VM.warp(99);
        assertFalse(controlsFacet.hasActiveRole(managerRole, eve), "window should be inactive");
        VM.warp(100);
        assertTrue(controlsFacet.hasActiveRole(managerRole, eve), "window should be active");
        VM.warp(200);
        assertFalse(controlsFacet.hasActiveRole(managerRole, eve), "window should expire");
    }

    function testDiamondSelectorsSplitBetweenCoreAndControlsFacets() public {
        _installHostedVaultFacetsToDiamond();
        _initializeDiamondVault();

        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultCoreSelectors(), address(coreFacet));
        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultControlsSelectors(), address(controlsFacet));

        assertTrue(
            IDiamondLoupe(address(diamond)).facetFunctionSelectors(address(coreFacet)).length
                == LibVaultFacetSelectors.vaultCoreSelectors().length,
            "unexpected core selector count"
        );
        assertTrue(
            IDiamondLoupe(address(diamond)).facetFunctionSelectors(address(controlsFacet)).length
                == LibVaultFacetSelectors.vaultControlsSelectors().length,
            "unexpected controls selector count"
        );
        assertTrue(
            IDiamondLoupe(address(diamond)).facetAddress(IERC4626VaultFacet.initializeVault.selector)
                == address(coreFacet),
            "initializer owner mismatch"
        );

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultAlreadyInitialized.selector));
        IERC4626VaultFacet(address(diamond)).initializeVault(address(asset), "Vault Share", "vSHARE", admin);
    }

    function testDiamondControlsConfigReshapesCoreRouting() public {
        _installHostedVaultFacetsToDiamond();
        _initializeDiamondVault();
        _approveAsset(bob, address(diamond), 200);

        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).setFeeConfig(1_000, 1_000, eve);
        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).setLimitConfig(60, 50, 40, 25, 20);

        assertTrue(IERC4626VaultFacet(address(diamond)).previewDeposit(100) == 90, "previewDeposit mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).previewMint(50) == 56, "previewMint mismatch");

        VM.prank(bob);
        uint256 shares = IERC4626VaultFacet(address(diamond)).deposit(50, bob);
        assertTrue(shares == 45, "deposit shares mismatch");
        assertTrue(asset.balanceOf(eve) == INITIAL_ASSETS + 5, "fee recipient balance mismatch");

        assertTrue(IERC4626VaultFacet(address(diamond)).maxDeposit(bob) == 16, "maxDeposit mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).maxMint(bob) == 15, "maxMint mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).maxWithdraw(bob) == 25, "maxWithdraw mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).maxRedeem(bob) == 20, "maxRedeem mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).previewWithdraw(20) == 22, "previewWithdraw mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).previewRedeem(20) == 18, "previewRedeem mismatch");

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultDepositLimitExceeded.selector, 17, 16));
        IERC4626VaultFacet(address(diamond)).deposit(17, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultMintLimitExceeded.selector, 16, 15));
        IERC4626VaultFacet(address(diamond)).mint(16, bob);

        VM.prank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultWithdrawLimitExceeded.selector, 26, 25)
        );
        IERC4626VaultFacet(address(diamond)).withdraw(26, bob, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultRedeemLimitExceeded.selector, 21, 20));
        IERC4626VaultFacet(address(diamond)).redeem(21, bob, bob);
    }

    function testDiamondGlobalPauseBlocksVaultEntrypointsButNotShareTokenFlows() public {
        _installHostedVaultFacetsToDiamond();
        _initializeDiamondVault();
        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        IERC4626VaultFacet(address(diamond)).deposit(40, bob);

        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).pause();

        assertTrue(IERC4626VaultFacet(address(diamond)).maxDeposit(bob) == 0, "maxDeposit should pause");
        assertTrue(IERC4626VaultFacet(address(diamond)).maxMint(bob) == 0, "maxMint should pause");
        assertTrue(IERC4626VaultFacet(address(diamond)).maxWithdraw(bob) == 0, "maxWithdraw should pause");
        assertTrue(IERC4626VaultFacet(address(diamond)).maxRedeem(bob) == 0, "maxRedeem should pause");

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        IERC4626VaultFacet(address(diamond)).deposit(1, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        IERC4626VaultFacet(address(diamond)).mint(1, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        IERC4626VaultFacet(address(diamond)).withdraw(1, bob, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        IERC4626VaultFacet(address(diamond)).redeem(1, bob, bob);

        VM.prank(bob);
        IERC4626VaultFacet(address(diamond)).approve(eve, 15);
        VM.prank(eve);
        IERC4626VaultFacet(address(diamond)).transferFrom(bob, admin, 10);
        VM.prank(bob);
        IERC4626VaultFacet(address(diamond)).transfer(admin, 5);

        assertTrue(IERC4626VaultFacet(address(diamond)).allowance(bob, eve) == 5, "allowance mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).balanceOf(bob) == 25, "bob balance mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).balanceOf(admin) == 15, "admin balance mismatch");
    }

    function testDiamondNativeDepositAppliesConfiguredFee() public {
        _installHostedVaultNativeFacetsToDiamond();

        VM.prank(admin);
        IERC4626VaultFacet(address(diamond))
            .initializeVault(LibVaultAsset.NATIVE_ASSET_SENTINEL, "Vault Share", "vSHARE", admin);

        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).setFeeConfig(1_000, 0, eve);

        VM.deal(bob, 100);
        VM.prank(bob);
        uint256 shares = IERC7535VaultFacet(address(diamond)).depositNative{value: 100}(bob);

        assertTrue(shares == 90, "native deposit shares mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == 90, "native total assets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).balanceOf(bob) == 90, "native share balance mismatch");
        assertTrue(eve.balance == 10, "native fee recipient balance mismatch");
        assertTrue(address(diamond).balance == 90, "native vault balance mismatch");
    }

    function testDiamondNativeMintAppliesConfiguredFee() public {
        _installHostedVaultNativeFacetsToDiamond();

        VM.prank(admin);
        IERC4626VaultFacet(address(diamond))
            .initializeVault(LibVaultAsset.NATIVE_ASSET_SENTINEL, "Vault Share", "vSHARE", admin);

        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).setFeeConfig(1_000, 0, eve);

        VM.deal(bob, 100);
        VM.prank(bob);
        uint256 assetsIn = IERC7535VaultFacet(address(diamond)).mintNative{value: 56}(50, bob);

        assertTrue(assetsIn == 56, "native mint assets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == 50, "native total assets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).balanceOf(bob) == 50, "native share balance mismatch");
        assertTrue(eve.balance == 6, "native fee recipient balance mismatch");
        assertTrue(address(diamond).balance == 50, "native vault balance mismatch");
    }

    function testDiamondNativeControlsConfigReshapesNativeRouting() public {
        _installHostedVaultNativeFacetsToDiamond();

        VM.prank(admin);
        IERC4626VaultFacet(address(diamond))
            .initializeVault(LibVaultAsset.NATIVE_ASSET_SENTINEL, "Vault Share", "vSHARE", admin);

        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).setFeeConfig(1_000, 1_000, eve);
        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).setLimitConfig(60, 0, 15, 25, 20);

        VM.deal(bob, 100);
        VM.prank(bob);
        uint256 shares = IERC7535VaultFacet(address(diamond)).depositNative{value: 50}(bob);
        assertTrue(shares == 45, "native deposit shares mismatch");
        assertTrue(eve.balance == 5, "native fee recipient balance mismatch");

        assertTrue(IERC4626VaultFacet(address(diamond)).previewDeposit(100) == 90, "native previewDeposit mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).previewMint(50) == 56, "native previewMint mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).maxDeposit(bob) == 16, "native maxDeposit mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).maxMint(bob) == 15, "native maxMint mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).maxWithdraw(bob) == 25, "native maxWithdraw mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).maxRedeem(bob) == 20, "native maxRedeem mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).previewWithdraw(20) == 22, "native previewWithdraw mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).previewRedeem(20) == 18, "native previewRedeem mismatch");

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultDepositLimitExceeded.selector, 17, 16));
        IERC7535VaultFacet(address(diamond)).depositNative{value: 17}(bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultMintLimitExceeded.selector, 16, 15));
        IERC7535VaultFacet(address(diamond)).mintNative{value: 0}(16, bob);

        VM.prank(bob);
        VM.expectRevert(
            abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultWithdrawLimitExceeded.selector, 26, 25)
        );
        IERC4626VaultFacet(address(diamond)).withdraw(26, bob, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultControls.ERC4626VaultRedeemLimitExceeded.selector, 21, 20));
        IERC4626VaultFacet(address(diamond)).redeem(21, bob, bob);
    }

    function testDiamondNativeGlobalPauseBlocksVaultEntrypointsButNotShareTokenFlows() public {
        _installHostedVaultNativeFacetsToDiamond();

        VM.prank(admin);
        IERC4626VaultFacet(address(diamond))
            .initializeVault(LibVaultAsset.NATIVE_ASSET_SENTINEL, "Vault Share", "vSHARE", admin);

        VM.deal(bob, 100);
        VM.prank(bob);
        IERC7535VaultFacet(address(diamond)).depositNative{value: 40}(bob);

        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).pause();

        assertTrue(IERC4626VaultFacet(address(diamond)).maxDeposit(bob) == 0, "native maxDeposit should pause");
        assertTrue(IERC4626VaultFacet(address(diamond)).maxMint(bob) == 0, "native maxMint should pause");
        assertTrue(IERC4626VaultFacet(address(diamond)).maxWithdraw(bob) == 0, "native maxWithdraw should pause");
        assertTrue(IERC4626VaultFacet(address(diamond)).maxRedeem(bob) == 0, "native maxRedeem should pause");

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        IERC7535VaultFacet(address(diamond)).depositNative{value: 1}(bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        IERC7535VaultFacet(address(diamond)).mintNative{value: 1}(1, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        IERC4626VaultFacet(address(diamond)).withdraw(1, bob, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        IERC4626VaultFacet(address(diamond)).redeem(1, bob, bob);

        VM.prank(bob);
        IERC4626VaultFacet(address(diamond)).approve(eve, 15);
        VM.prank(eve);
        IERC4626VaultFacet(address(diamond)).transferFrom(bob, admin, 10);
        VM.prank(bob);
        IERC4626VaultFacet(address(diamond)).transfer(admin, 5);

        assertTrue(IERC4626VaultFacet(address(diamond)).allowance(bob, eve) == 5, "native allowance mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).balanceOf(bob) == 25, "native bob balance mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).balanceOf(admin) == 15, "native admin balance mismatch");
    }

    function testDiamondScopePauseRoutesButDoesNotBlockVaultEntrypoints() public {
        _installHostedVaultFacetsToDiamond();
        _initializeDiamondVault();
        _approveAsset(bob, address(diamond), 100);
        bytes32 scope = keccak256("vault-ops");

        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).pauseScope(scope);

        assertTrue(IERC4626VaultControlsFacet(address(diamond)).scopePaused(scope), "scope pause mismatch");
        assertTrue(IERC4626VaultControlsFacet(address(diamond)).paused(scope), "effective scope pause mismatch");
        assertFalse(IERC4626VaultControlsFacet(address(diamond)).paused(), "global pause should remain unset");

        VM.prank(bob);
        uint256 shares = IERC4626VaultFacet(address(diamond)).deposit(10, bob);
        assertTrue(shares == 10, "scope pause should not block deposit");
    }

    function testDiamondTimeWindowSelectorsRouteForManagerDelegation() public {
        _installHostedVaultFacetsToDiamond();
        _initializeDiamondVault();

        bytes32 managerRole = IERC4626VaultControlsFacet(address(diamond)).VAULT_MANAGER_ROLE();

        VM.prank(admin);
        IERC4626VaultControlsFacet(address(diamond)).grantRoleWithWindow(managerRole, eve, 100, 200);

        (uint64 start, uint64 end, bool exists) =
            IERC4626VaultControlsFacet(address(diamond)).getRoleWindow(managerRole, eve);
        assertTrue(exists, "window should exist");
        assertTrue(start == 100, "window start mismatch");
        assertTrue(end == 200, "window end mismatch");

        VM.warp(150);
        assertTrue(
            IERC4626VaultControlsFacet(address(diamond)).hasActiveRole(managerRole, eve), "window should be active"
        );
    }

    function _assertSelectorsOwnedByFacet(bytes4[] memory selectors, address expectedFacet) internal view {
        for (uint256 i = 0; i < selectors.length; i++) {
            assertTrue(
                IDiamondLoupe(address(diamond)).facetAddress(selectors[i]) == expectedFacet, "selector owner mismatch"
            );
        }
    }
}
