// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IAccessControlTime} from "../src/interfaces/IAccessControlTime.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IERC4626} from "../src/interfaces/IERC4626.sol";
import {IERC7535VaultFacet} from "../src/interfaces/IERC7535VaultFacet.sol";
import {IERC4626VaultBase} from "../src/interfaces/IERC4626VaultBase.sol";
import {IERC4626VaultControls} from "../src/interfaces/IERC4626VaultControls.sol";
import {IERC4626VaultControlsFacet} from "../src/interfaces/IERC4626VaultControlsFacet.sol";
import {IERC4626VaultFacet} from "../src/interfaces/IERC4626VaultFacet.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {IReentrancyGuard} from "../src/interfaces/IReentrancyGuard.sol";
import {LibVaultFacetSelectors} from "../src/vault/libraries/LibVaultFacetSelectors.sol";
import {LibERC4626VaultStorage} from "../src/vault/storage/LibERC4626VaultStorage.sol";
import {NoMetadataAsset} from "./helpers/ERC4626VaultTestHarness.sol";
import {VaultFacetFoundationFixture} from "./helpers/VaultFacetFoundationTestHarness.sol";

contract VaultFacetFoundationCoreTest is VaultFacetFoundationFixture {
    function testInitializeVaultSeedsHostedFoundationState() public {
        _initializeVault();

        assertTrue(vault.isVaultInitialized(), "vault should initialize");
        assertTrue(vault.controlPlaneInitialized(), "control plane should initialize");
        assertTrue(vault.asset() == address(asset), "asset mismatch");
        assertTrue(keccak256(bytes(vault.name())) == keccak256(bytes("Vault Share")), "name mismatch");
        assertTrue(keccak256(bytes(vault.symbol())) == keccak256(bytes("vSHARE")), "symbol mismatch");
        assertTrue(vault.decimals() == 6, "decimals mismatch");
        assertTrue(vault.feeRecipient() == admin, "fee recipient mismatch");
        assertTrue(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), admin), "missing default admin role");
        assertTrue(vault.hasRole(vault.PAUSER_ROLE(), admin), "missing pauser role");
        assertTrue(vault.hasRole(vault.VAULT_MANAGER_ROLE(), admin), "missing vault manager role");
        assertTrue(vault.reentrancyGuardEntered() == false, "reentrancy guard should be idle");
    }

    function testInitializeVaultDefaultsDecimalsWhenMetadataMissing() public {
        NoMetadataAsset noMetadataAsset = _newNoMetadataAsset();

        vault.initializeVault(address(noMetadataAsset), "Vault Share", "vSHARE", admin);

        assertTrue(vault.decimals() == 18, "missing metadata should default to 18 decimals");
    }

    function testInitializeVaultRevertsOnZeroAsset() public {
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultZeroAsset.selector));
        vault.initializeVault(address(0), "Vault Share", "vSHARE", admin);
    }

    function testInitializeVaultRevertsWhenAlreadyInitialized() public {
        _initializeVault();

        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultAlreadyInitialized.selector));
        vault.initializeVault(address(asset), "Vault Share", "vSHARE", admin);
    }

    function testConstructorFreeControlInitCanRunBeforeVaultInit() public {
        vault.initializeControlOnly(admin);

        assertFalse(vault.isVaultInitialized(), "vault storage should remain uninitialized");
        assertTrue(vault.controlPlaneInitialized(), "control plane should initialize");
        assertTrue(vault.feeRecipient() == admin, "fee recipient mismatch");
        assertTrue(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), admin), "missing default admin role");
        assertTrue(vault.hasRole(vault.PAUSER_ROLE(), admin), "missing pauser role");
        assertTrue(vault.hasRole(vault.VAULT_MANAGER_ROLE(), admin), "missing vault manager role");

        vault.initializeControlOnly(admin);
        vault.initializeVault(address(asset), "Vault Share", "vSHARE", admin);

        assertTrue(vault.isVaultInitialized(), "vault should initialize after control-only init");
        assertTrue(vault.asset() == address(asset), "asset mismatch after delayed vault init");
    }

    function testVaultPackedSlotZeroOffsetsRemainFrozenAcrossControlOnlyAndFullInit() public {
        vault.initializeControlOnly(admin);

        uint256 controlOnlySlot0 =
            uint256(VM.load(address(vault), bytes32(uint256(LibERC4626VaultStorage.STORAGE_SLOT))));
        // casting to uint8 is safe because the mask keeps only the packed initialization byte.
        // forge-lint: disable-next-line(unsafe-typecast)
        assertTrue(uint8(controlOnlySlot0 & 0xff) == 0, "vault initialized byte should remain zero before vault init");
        assertTrue(uint8((controlOnlySlot0 >> 8) & 0xff) == 1, "controlPlaneInitialized byte should occupy second byte");
        assertTrue((controlOnlySlot0 >> 16) == 0, "asset and decimals bytes should remain unset before vault init");

        vault.initializeVault(address(asset), "Vault Share", "vSHARE", admin);

        uint256 initializedSlot0 =
            uint256(VM.load(address(vault), bytes32(uint256(LibERC4626VaultStorage.STORAGE_SLOT))));
        // casting to uint8 is safe because the mask keeps only the packed initialization byte.
        // forge-lint: disable-next-line(unsafe-typecast)
        assertTrue(uint8(initializedSlot0 & 0xff) == 1, "vault initialized byte mismatch");
        assertTrue(uint8((initializedSlot0 >> 8) & 0xff) == 1, "controlPlaneInitialized byte mismatch");
        assertTrue(
            // casting to uint160 is safe because this assertion intentionally inspects the packed address field.
            // forge-lint: disable-next-line(unsafe-typecast)
            uint160(initializedSlot0 >> 16) == uint160(address(asset)),
            "asset bytes should start at the third byte"
        );
        assertTrue(uint8((initializedSlot0 >> 176) & 0xff) == 6, "decimals byte mismatch");
    }

    function testSupportsHostedControlInterfaces() public view {
        assertTrue(vault.supportsInterface(type(IERC165).interfaceId), "erc165 unsupported");
        assertTrue(vault.supportsInterface(type(IAccessControl).interfaceId), "access control unsupported");
        assertTrue(vault.supportsInterface(type(IAccessControlTime).interfaceId), "access control time unsupported");
        assertTrue(vault.supportsInterface(type(IPausable).interfaceId), "pausable unsupported");
        assertTrue(vault.supportsInterface(type(IReentrancyGuard).interfaceId), "reentrancy unsupported");
        assertTrue(
            vault.supportsInterface(type(IERC4626VaultControlsFacet).interfaceId), "vault controls facet unsupported"
        );
    }

    function testVaultSelectorGroupsCoverExpectedHostedSplit() public pure {
        bytes4[] memory coreSelectors = LibVaultFacetSelectors.vaultCoreSelectors();
        bytes4[] memory nativeSelectors = LibVaultFacetSelectors.vaultNativeSelectors();
        bytes4[] memory controlSelectors = LibVaultFacetSelectors.vaultControlsSelectors();

        assertTrue(coreSelectors.length == 28, "unexpected core selector count");
        assertTrue(nativeSelectors.length == 2, "unexpected native selector count");
        assertTrue(controlSelectors.length == 28, "unexpected controls selector count");

        _assertContains(coreSelectors, IERC4626VaultFacet.initializeVault.selector);
        _assertContains(coreSelectors, IERC4626.deposit.selector);
        _assertContains(coreSelectors, IERC4626.redeem.selector);
        _assertContains(coreSelectors, IERC4626VaultBase.totalManagedAssets.selector);

        _assertContains(nativeSelectors, IERC7535VaultFacet.depositNative.selector);
        _assertContains(nativeSelectors, IERC7535VaultFacet.mintNative.selector);

        _assertContains(controlSelectors, IERC4626VaultControls.setFeeConfig.selector);
        _assertContains(controlSelectors, IERC4626VaultControls.setLimitConfig.selector);
        _assertContains(controlSelectors, IAccessControlTime.grantRoleWithWindow.selector);
        _assertContains(controlSelectors, IReentrancyGuard.reentrancyGuardEntered.selector);
        _assertContains(controlSelectors, IERC165.supportsInterface.selector);

        _assertUnique(coreSelectors);
        _assertUnique(nativeSelectors);
        _assertUnique(controlSelectors);
        _assertDisjoint(coreSelectors, nativeSelectors);
        _assertDisjoint(coreSelectors, controlSelectors);
        _assertDisjoint(nativeSelectors, controlSelectors);
    }

    function _assertContains(bytes4[] memory selectors, bytes4 target) internal pure {
        for (uint256 i = 0; i < selectors.length; i++) {
            if (selectors[i] == target) {
                return;
            }
        }
        revert("missing selector");
    }

    function _assertUnique(bytes4[] memory selectors) internal pure {
        for (uint256 i = 0; i < selectors.length; i++) {
            for (uint256 j = i + 1; j < selectors.length; j++) {
                if (selectors[i] == selectors[j]) {
                    revert("duplicate selector");
                }
            }
        }
    }

    function _assertDisjoint(bytes4[] memory left, bytes4[] memory right) internal pure {
        for (uint256 i = 0; i < left.length; i++) {
            for (uint256 j = 0; j < right.length; j++) {
                if (left[i] == right[j]) {
                    revert("selector overlap");
                }
            }
        }
    }
}
