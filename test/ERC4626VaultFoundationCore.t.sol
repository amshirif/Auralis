// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC4626VaultFixture, MockAssetWithDecimals, NoMetadataAsset} from "./helpers/ERC4626VaultTestHarness.sol";
import {ERC4626VaultHarness} from "./helpers/ERC4626VaultTestHarness.sol";
import {IERC4626VaultBase} from "../src/interfaces/IERC4626VaultBase.sol";

contract ERC4626VaultFoundationCoreTest is ERC4626VaultFixture {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function testInitializeSetsVaultStorage() public {
        _initializeVault();

        assertTrue(vault.isVaultInitialized(), "vault not initialized");
        assertTrue(vault.asset() == address(asset), "asset mismatch");
        assertTrue(keccak256(bytes(vault.name())) == keccak256(bytes("Vault Share")), "name mismatch");
        assertTrue(keccak256(bytes(vault.symbol())) == keccak256(bytes("vSHARE")), "symbol mismatch");
        assertTrue(vault.decimals() == 6, "decimals mismatch");
    }

    function testInitializeDefaultsDecimalsWhenMetadataMissing() public {
        NoMetadataAsset noMetadataAsset = new NoMetadataAsset();

        vault.initialize(address(noMetadataAsset), "Vault Share", "vSHARE");

        assertTrue(vault.decimals() == 18, "missing metadata should default to 18 decimals");
    }

    function testInitializeRevertsOnZeroAsset() public {
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultZeroAsset.selector));
        vault.initialize(address(0), "Vault Share", "vSHARE");
    }

    function testInitializeRevertsWhenAlreadyInitialized() public {
        _initializeVault();

        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultAlreadyInitialized.selector));
        vault.initialize(address(asset), "Vault Share", "vSHARE");
    }

    function testHelpersRevertBeforeInitialize() public {
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultNotInitialized.selector));
        vault.mintShares(bob, 1);

        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultNotInitialized.selector));
        vault.addManagedAssets(1);
    }

    function testMintSharesUpdatesSupplyAndBalances() public {
        _initializeVault();

        vault.mintShares(bob, 10);

        assertTrue(vault.totalSupply() == 10, "total supply mismatch");
        assertTrue(vault.balanceOf(bob) == 10, "balance mismatch");
    }

    function testMintSharesEmitsTransfer() public {
        _initializeVault();

        VM.expectEmit(true, true, false, true, address(vault));
        emit Transfer(address(0), bob, 10);
        vault.mintShares(bob, 10);
    }

    function testBurnSharesUpdatesSupplyAndBalances() public {
        _initializeVault();
        vault.mintShares(bob, 10);

        vault.burnShares(bob, 4);

        assertTrue(vault.totalSupply() == 6, "total supply mismatch after burn");
        assertTrue(vault.balanceOf(bob) == 6, "balance mismatch after burn");
    }

    function testBurnSharesEmitsTransfer() public {
        _initializeVault();
        vault.mintShares(bob, 10);

        VM.expectEmit(true, true, false, true, address(vault));
        emit Transfer(bob, address(0), 4);
        vault.burnShares(bob, 4);
    }

    function testBurnSharesRevertsOnInsufficientBalance() public {
        _initializeVault();

        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultInsufficientBalance.selector, bob, 0, 1));
        vault.burnShares(bob, 1);
    }

    function testTransferFromUsesAllowanceAndUpdatesBalances() public {
        _initializeVault();
        vault.mintShares(bob, 10);

        VM.prank(bob);
        vault.approve(eve, 7);

        VM.prank(eve);
        bool success = vault.transferFrom(bob, admin, 6);
        assertTrue(success, "transferFrom should succeed");

        assertTrue(vault.allowance(bob, eve) == 1, "allowance mismatch");
        assertTrue(vault.balanceOf(bob) == 4, "sender balance mismatch");
        assertTrue(vault.balanceOf(admin) == 6, "receiver balance mismatch");
    }

    function testApproveEmitsEvent() public {
        _initializeVault();

        VM.expectEmit(true, true, false, true, address(vault));
        emit Approval(bob, eve, 7);

        VM.prank(bob);
        vault.approve(eve, 7);
    }

    function testTransferFromRevertsOnInsufficientAllowance() public {
        _initializeVault();
        vault.mintShares(bob, 10);

        VM.prank(bob);
        vault.approve(eve, 2);

        VM.prank(eve);
        VM.expectRevert(
            abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultInsufficientAllowance.selector, bob, eve, 2, 3)
        );
        vault.transferFromNoReturn(bob, admin, 3);
    }

    function testManagedAssetAccountingHelpers() public {
        _initializeVault();

        vault.addManagedAssets(100);
        vault.removeManagedAssets(45);

        assertTrue(vault.totalManagedAssets() == 55, "managed assets mismatch");
    }

    function testManagedAssetAccountingRevertsOnUnderflow() public {
        _initializeVault();

        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultManagedAssetsUnderflow.selector, 0, 1));
        vault.removeManagedAssets(1);
    }

    function testConversionHelpersBootstrapOneToOne() public {
        _initializeVault();

        assertTrue(vault.convertToSharesDown(5) == 5, "bootstrap shares conversion mismatch");
        assertTrue(vault.convertToAssetsDown(5) == 5, "bootstrap assets conversion mismatch");
    }

    function testConversionHelpersApplyRounding() public {
        _initializeVault();
        vault.mintShares(bob, 3);
        vault.addManagedAssets(2);

        assertTrue(vault.convertToAssetsDown(1) == 0, "round down assets mismatch");
        assertTrue(vault.convertToAssetsUp(1) == 1, "round up assets mismatch");

        assertTrue(vault.convertToSharesDown(1) == 1, "round down shares mismatch");
        assertTrue(vault.convertToSharesUp(1) == 2, "round up shares mismatch");
    }

    function testInfiniteAllowanceIsNotDecremented() public {
        _initializeVault();
        vault.mintShares(bob, 10);

        VM.prank(bob);
        vault.approve(eve, type(uint256).max);

        VM.prank(eve);
        bool success = vault.transferFrom(bob, admin, 3);
        assertTrue(success, "transferFrom should succeed");

        assertTrue(vault.allowance(bob, eve) == type(uint256).max, "infinite allowance should remain unchanged");
    }

    function testZeroAddressGuardsForMintAndApprove() public {
        _initializeVault();

        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultZeroAddress.selector));
        vault.mintShares(address(0), 1);

        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultZeroAddress.selector));
        vault.approve(address(0), 1);
    }

    function testAssetDecimalsCanBeUpdatedAtSourceWithoutChangingVaultMetadata() public {
        _initializeVault();

        MockAssetWithDecimals newAsset = new MockAssetWithDecimals(12);
        ERC4626VaultHarness secondVault = new ERC4626VaultHarness();
        secondVault.initialize(address(newAsset), "Second Vault", "sVAULT");

        assertTrue(secondVault.decimals() == 12, "second vault decimals mismatch");
        assertTrue(vault.decimals() == 6, "original vault decimals should remain unchanged");
    }
}
