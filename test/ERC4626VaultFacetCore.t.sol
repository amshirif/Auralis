// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IERC4626} from "../src/interfaces/IERC4626.sol";
import {IERC4626VaultBase} from "../src/interfaces/IERC4626VaultBase.sol";
import {IERC4626VaultFacet} from "../src/interfaces/IERC4626VaultFacet.sol";
import {IERC7535VaultFacet} from "../src/interfaces/IERC7535VaultFacet.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {ERC4626Vault} from "../src/vault/ERC4626Vault.sol";
import {LibVaultAsset} from "../src/vault/libraries/LibVaultAsset.sol";
import {LibVaultFacetSelectors} from "../src/vault/libraries/LibVaultFacetSelectors.sol";
import {
    ERC4626VaultFacetFixture,
    ERC4626VaultFacetHarness,
    RejectingNativeReceiver
} from "./helpers/ERC4626VaultFacetTestHarness.sol";

contract ERC4626VaultFacetCoreTest is ERC4626VaultFacetFixture {
    function testInitializeVaultSeedsMetadataAndControlPlane() public {
        _initializeHostedVault(address(facet));

        assertTrue(facet.isVaultInitialized(), "vault should initialize");
        assertTrue(facet.asset() == address(asset), "asset mismatch");
        assertTrue(keccak256(bytes(facet.name())) == keccak256(bytes("Vault Share")), "name mismatch");
        assertTrue(keccak256(bytes(facet.symbol())) == keccak256(bytes("vSHARE")), "symbol mismatch");
        assertTrue(facet.decimals() == 6, "decimals mismatch");
        assertTrue(facet.feeRecipient() == admin, "fee recipient mismatch");
        assertTrue(facet.hasRole(facet.DEFAULT_ADMIN_ROLE(), admin), "missing default admin role");
        assertTrue(facet.hasRole(facet.PAUSER_ROLE(), admin), "missing pauser role");
        assertTrue(facet.hasRole(facet.VAULT_MANAGER_ROLE(), admin), "missing vault manager role");
        assertFalse(facet.reentrancyGuardEntered(), "reentrancy guard should be idle");
    }

    function testInitializeVaultRevertsOnZeroAsset() public {
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultZeroAsset.selector));
        facet.initializeVault(address(0), "Vault Share", "vSHARE", admin);
    }

    function testInitializeVaultRevertsWhenCalledTwice() public {
        _initializeHostedVault(address(facet));

        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultAlreadyInitialized.selector));
        _initializeHostedVault(address(facet));
    }

    function testCoreFlowsAndShareTokenRoutingWorkOnFacet() public {
        _initializeHostedVault(address(facet));

        assertTrue(facet.previewDeposit(8) == 8, "preview deposit mismatch");
        assertTrue(facet.previewMint(8) == 8, "preview mint mismatch");

        _approveAsset(bob, address(facet), 100);
        _approveAsset(eve, address(facet), 100);

        VM.prank(bob);
        uint256 bobDepositShares = facet.deposit(40, bob);
        VM.prank(eve);
        uint256 eveMintAssets = facet.mint(10, eve);

        VM.prank(bob);
        bool approveSuccess = facet.approve(eve, 15);
        VM.prank(eve);
        bool transferFromSuccess = facet.transferFrom(bob, admin, 10);
        VM.prank(bob);
        bool transferSuccess = facet.transfer(admin, 5);

        VM.prank(bob);
        uint256 bobWithdrawShares = facet.withdraw(10, bob, bob);
        VM.prank(eve);
        uint256 eveRedeemAssets = facet.redeem(5, eve, eve);

        assertTrue(bobDepositShares == 40, "deposit shares mismatch");
        assertTrue(eveMintAssets == 10, "mint assets mismatch");
        assertTrue(approveSuccess, "approve should succeed");
        assertTrue(transferFromSuccess, "transferFrom should succeed");
        assertTrue(transferSuccess, "transfer should succeed");
        assertTrue(bobWithdrawShares == 10, "withdraw shares mismatch");
        assertTrue(eveRedeemAssets == 5, "redeem assets mismatch");

        assertTrue(facet.totalAssets() == 35, "total assets mismatch");
        assertTrue(facet.totalManagedAssets() == 35, "managed assets mismatch");
        assertTrue(facet.totalSupply() == 35, "total supply mismatch");
        assertTrue(facet.balanceOf(bob) == 15, "bob balance mismatch");
        assertTrue(facet.balanceOf(admin) == 15, "admin balance mismatch");
        assertTrue(facet.balanceOf(eve) == 5, "eve balance mismatch");
        assertTrue(facet.allowance(bob, eve) == 5, "allowance mismatch");
        assertTrue(asset.balanceOf(address(facet)) == 35, "vault asset balance mismatch");
        assertTrue(asset.balanceOf(bob) == INITIAL_ASSETS - 30, "bob asset balance mismatch");
        assertTrue(asset.balanceOf(eve) == INITIAL_ASSETS - 5, "eve asset balance mismatch");
    }

    function testPauseBlocksVaultEntrypointsButLeavesShareTokenFlowsAvailable() public {
        _initializeHostedVault(address(facet));
        _approveAsset(bob, address(facet), 100);

        VM.prank(bob);
        facet.deposit(40, bob);

        VM.prank(admin);
        facet.pause();

        assertTrue(facet.maxDeposit(bob) == 0, "maxDeposit should pause");
        assertTrue(facet.maxMint(bob) == 0, "maxMint should pause");
        assertTrue(facet.maxWithdraw(bob) == 0, "maxWithdraw should pause");
        assertTrue(facet.maxRedeem(bob) == 0, "maxRedeem should pause");

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        facet.deposit(1, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        facet.mint(1, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        facet.withdraw(1, bob, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(IPausable.PausableEnforcedPause.selector));
        facet.redeem(1, bob, bob);

        VM.prank(bob);
        facet.approve(eve, 15);
        VM.prank(eve);
        facet.transferFrom(bob, admin, 10);
        VM.prank(bob);
        facet.transfer(admin, 5);

        assertTrue(facet.allowance(bob, eve) == 5, "allowance mismatch");
        assertTrue(facet.balanceOf(bob) == 25, "bob share balance mismatch");
        assertTrue(facet.balanceOf(admin) == 15, "admin share balance mismatch");
    }

    function testReentrantAttemptDuringDepositIsBlocked() public {
        _initializeHostedVault(address(facet));
        bytes memory payload = abi.encodeCall(ERC4626VaultFacetHarness.probeNonReentrant, ());
        asset.configureReentry(address(facet), payload, true);

        _approveAsset(bob, address(facet), 100);

        VM.prank(bob);
        uint256 shares = facet.deposit(10, bob);

        assertTrue(shares == 10, "deposit should succeed");
        assertTrue(asset.reentryAttemptBlocked(), "expected reentry attempt to be blocked");
        assertFalse(facet.reentrancyGuardEntered(), "reentrancy guard should reset");
    }

    function testDiamondRoutingAndInitWorkThroughFallback() public {
        _installVaultCoreFacetToDiamond();

        VM.prank(admin);
        IERC4626VaultFacet(address(diamond)).initializeVault(address(asset), "Vault Share", "vSHARE", admin);

        assertTrue(IERC4626VaultFacet(address(diamond)).isVaultInitialized(), "diamond vault should initialize");
        assertTrue(IERC4626VaultFacet(address(diamond)).asset() == address(asset), "diamond asset mismatch");
        assertTrue(
            keccak256(bytes(IERC4626VaultFacet(address(diamond)).name())) == keccak256(bytes("Vault Share")),
            "diamond name mismatch"
        );
        assertTrue(
            keccak256(bytes(IERC4626VaultFacet(address(diamond)).symbol())) == keccak256(bytes("vSHARE")),
            "diamond symbol mismatch"
        );

        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        uint256 shares = IERC4626VaultFacet(address(diamond)).deposit(25, bob);

        VM.prank(bob);
        bool approveSuccess = IERC4626VaultFacet(address(diamond)).approve(eve, 10);
        VM.prank(eve);
        bool transferFromSuccess = IERC4626VaultFacet(address(diamond)).transferFrom(bob, admin, 5);
        VM.prank(bob);
        uint256 withdrawnShares = IERC4626VaultFacet(address(diamond)).withdraw(10, bob, bob);

        assertTrue(shares == 25, "diamond deposit shares mismatch");
        assertTrue(approveSuccess, "diamond approve should succeed");
        assertTrue(transferFromSuccess, "diamond transferFrom should succeed");
        assertTrue(withdrawnShares == 10, "diamond withdrawn shares mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).previewDeposit(8) == 8, "diamond preview mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == 15, "diamond total assets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 15, "diamond managed assets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).balanceOf(bob) == 10, "diamond bob share balance mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).balanceOf(admin) == 5, "diamond admin share balance mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).allowance(bob, eve) == 5, "diamond allowance mismatch");

        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultCoreSelectors(), address(facet));
        assertTrue(
            IDiamondLoupe(address(diamond)).facetFunctionSelectors(address(facet)).length
                == LibVaultFacetSelectors.vaultCoreSelectors().length,
            "diamond core selector count mismatch"
        );
    }

    function testDiamondReinitializeReverts() public {
        _installVaultCoreFacetToDiamond();

        VM.prank(admin);
        IERC4626VaultFacet(address(diamond)).initializeVault(address(asset), "Vault Share", "vSHARE", admin);

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultAlreadyInitialized.selector));
        IERC4626VaultFacet(address(diamond)).initializeVault(address(asset), "Vault Share", "vSHARE", admin);
    }

    function testDiamondCoreInstallDoesNotExposeControlsSelectors() public {
        _installVaultCoreFacetToDiamond();

        _assertSelectorsUnset(LibVaultFacetSelectors.vaultControlsSelectors());
    }

    function testInitializeNativeVaultUsesSentinelAssetAndDefaultDecimals() public {
        _initializeHostedVaultWithAsset(address(facet), LibVaultAsset.NATIVE_ASSET_SENTINEL);

        assertTrue(facet.asset() == LibVaultAsset.NATIVE_ASSET_SENTINEL, "native asset sentinel mismatch");
        assertTrue(facet.decimals() == 18, "native decimals should default to 18");
    }

    function testNativeDepositAndMintEntrypointsWorkOnDiamond() public {
        _installHostedVaultNativeFacetsToDiamond();

        VM.prank(admin);
        IERC4626VaultFacet(address(diamond))
            .initializeVault(LibVaultAsset.NATIVE_ASSET_SENTINEL, "Vault Share", "vSHARE", admin);

        VM.deal(bob, 100);
        VM.prank(bob);
        uint256 depositShares = IERC7535VaultFacet(address(diamond)).depositNative{value: 40}(bob);

        VM.prank(bob);
        uint256 mintAssets = IERC7535VaultFacet(address(diamond)).mintNative{value: 10}(10, bob);

        assertTrue(depositShares == 40, "native deposit shares mismatch");
        assertTrue(mintAssets == 10, "native mint assets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == 50, "native total assets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 50, "native managed assets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalSupply() == 50, "native supply mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).balanceOf(bob) == 50, "native share balance mismatch");
        assertTrue(address(diamond).balance == 50, "native vault balance mismatch");
    }

    function testNativeMintRequiresExactMsgValue() public {
        _installHostedVaultNativeFacetsToDiamond();

        VM.prank(admin);
        IERC4626VaultFacet(address(diamond))
            .initializeVault(LibVaultAsset.NATIVE_ASSET_SENTINEL, "Vault Share", "vSHARE", admin);

        VM.deal(bob, 100);
        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(ERC4626Vault.ERC4626VaultInvalidNativeAssetValue.selector, 9, 10));
        IERC7535VaultFacet(address(diamond)).mintNative{value: 9}(10, bob);
    }

    function testNativeEntrypointsRejectErc20VaultsOnDiamond() public {
        _installHostedVaultNativeFacetsToDiamond();

        VM.prank(admin);
        IERC4626VaultFacet(address(diamond)).initializeVault(address(asset), "Vault Share", "vSHARE", admin);

        VM.deal(bob, 100);
        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(ERC4626Vault.ERC4626VaultNativeAssetDisabled.selector));
        IERC7535VaultFacet(address(diamond)).depositNative{value: 10}(bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(ERC4626Vault.ERC4626VaultNativeAssetDisabled.selector));
        IERC7535VaultFacet(address(diamond)).mintNative{value: 10}(10, bob);
    }

    function testStandardDepositAndMintRejectNativeVaultMode() public {
        _initializeHostedVaultWithAsset(address(facet), LibVaultAsset.NATIVE_ASSET_SENTINEL);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(ERC4626Vault.ERC4626VaultNativeAssetUseNativeEntrypoint.selector));
        facet.deposit(10, bob);

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(ERC4626Vault.ERC4626VaultNativeAssetUseNativeEntrypoint.selector));
        facet.mint(10, bob);
    }

    function testErc20VaultDepositAndMintRejectMsgValue() public {
        _initializeHostedVault(address(facet));
        VM.deal(bob, 100);

        VM.prank(bob);
        (bool depositSuccess,) = address(facet).call{value: 1}(abi.encodeCall(IERC4626.deposit, (1, bob)));
        assertFalse(depositSuccess, "erc20 deposit should reject native value");

        VM.prank(bob);
        (bool mintSuccess,) = address(facet).call{value: 1}(abi.encodeCall(IERC4626.mint, (1, bob)));
        assertFalse(mintSuccess, "erc20 mint should reject native value");
    }

    function testNativeWithdrawAndRedeemTransferRawNativeAsset() public {
        _installHostedVaultNativeFacetsToDiamond();

        VM.prank(admin);
        IERC4626VaultFacet(address(diamond))
            .initializeVault(LibVaultAsset.NATIVE_ASSET_SENTINEL, "Vault Share", "vSHARE", admin);

        VM.deal(bob, 100);
        VM.prank(bob);
        IERC7535VaultFacet(address(diamond)).depositNative{value: 40}(bob);

        uint256 bobBalanceBeforeWithdraw = bob.balance;
        VM.prank(bob);
        uint256 withdrawnShares = IERC4626VaultFacet(address(diamond)).withdraw(10, bob, bob);
        assertTrue(withdrawnShares == 10, "native withdraw share burn mismatch");
        assertTrue(bob.balance == bobBalanceBeforeWithdraw + 10, "native withdraw payout mismatch");

        uint256 bobBalanceBeforeRedeem = bob.balance;
        VM.prank(bob);
        uint256 redeemedAssets = IERC4626VaultFacet(address(diamond)).redeem(5, bob, bob);
        assertTrue(redeemedAssets == 5, "native redeem asset mismatch");
        assertTrue(bob.balance == bobBalanceBeforeRedeem + 5, "native redeem payout mismatch");
        assertTrue(address(diamond).balance == 25, "native vault balance after payout mismatch");
    }

    function testNativePayoutFailureRevertsCleanly() public {
        _installHostedVaultNativeFacetsToDiamond();

        VM.prank(admin);
        IERC4626VaultFacet(address(diamond))
            .initializeVault(LibVaultAsset.NATIVE_ASSET_SENTINEL, "Vault Share", "vSHARE", admin);

        VM.deal(bob, 100);
        VM.prank(bob);
        IERC7535VaultFacet(address(diamond)).depositNative{value: 10}(bob);

        RejectingNativeReceiver receiver = new RejectingNativeReceiver();

        VM.prank(bob);
        VM.expectRevert(abi.encodeWithSelector(ERC4626Vault.ERC4626VaultAssetTransferFailed.selector));
        IERC4626VaultFacet(address(diamond)).withdraw(5, address(receiver), bob);
    }

    function testForceSentNativeAssetsDoNotChangeBookAccountingOrPricing() public {
        _installHostedVaultNativeFacetsToDiamond();

        VM.prank(admin);
        IERC4626VaultFacet(address(diamond))
            .initializeVault(LibVaultAsset.NATIVE_ASSET_SENTINEL, "Vault Share", "vSHARE", admin);

        VM.deal(bob, 100);
        VM.prank(bob);
        IERC7535VaultFacet(address(diamond)).depositNative{value: 10}(bob);

        VM.deal(address(diamond), address(diamond).balance + 7);

        assertTrue(address(diamond).balance == 17, "native force-send balance mismatch");
        assertTrue(
            IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 10, "managed assets should ignore force-send"
        );
        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == 10, "pricing should ignore force-send");
        assertTrue(
            IERC4626VaultFacet(address(diamond)).convertToShares(5) == 5, "force-send should not change share pricing"
        );
        assertTrue(
            IERC4626VaultFacet(address(diamond)).convertToAssets(10) == 10, "force-send should not change asset pricing"
        );
    }

    function testDiamondNativeRoutingReportsHostedNativeInterfaceAndTransfersRawNativeAsset() public {
        _installHostedVaultNativeFacetsToDiamond();

        VM.prank(admin);
        IERC4626VaultFacet(address(diamond))
            .initializeVault(LibVaultAsset.NATIVE_ASSET_SENTINEL, "Vault Share", "vSHARE", admin);

        assertTrue(
            IERC165(address(diamond)).supportsInterface(type(IERC7535VaultFacet).interfaceId),
            "native hosted interface unsupported"
        );

        VM.deal(bob, 100);
        VM.prank(bob);
        uint256 mintedShares = IERC7535VaultFacet(address(diamond)).depositNative{value: 25}(bob);
        assertTrue(mintedShares == 25, "diamond native deposit shares mismatch");

        uint256 bobBalanceBeforeWithdraw = bob.balance;
        VM.prank(bob);
        uint256 burnedShares = IERC4626VaultFacet(address(diamond)).withdraw(10, bob, bob);
        assertTrue(burnedShares == 10, "diamond native withdraw share burn mismatch");
        assertTrue(bob.balance == bobBalanceBeforeWithdraw + 10, "diamond native withdraw payout mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == 15, "diamond native total assets mismatch");
        assertTrue(
            IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 15, "diamond native managed assets mismatch"
        );

        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultCoreSelectors(), address(facet));
        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultNativeSelectors(), address(nativeFacet));
    }

    function _assertSelectorsOwnedByFacet(bytes4[] memory selectors, address expectedFacet) internal view {
        for (uint256 i = 0; i < selectors.length; i++) {
            assertTrue(
                IDiamondLoupe(address(diamond)).facetAddress(selectors[i]) == expectedFacet, "selector owner mismatch"
            );
        }
    }

    function _assertSelectorsUnset(bytes4[] memory selectors) internal view {
        for (uint256 i = 0; i < selectors.length; i++) {
            assertTrue(IDiamondLoupe(address(diamond)).facetAddress(selectors[i]) == address(0), "selector set");
        }
    }
}
