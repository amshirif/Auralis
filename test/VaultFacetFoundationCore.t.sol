// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IAccessControlTime} from "../src/interfaces/IAccessControlTime.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IERC4626} from "../src/interfaces/IERC4626.sol";
import {IERC4626VaultBase} from "../src/interfaces/IERC4626VaultBase.sol";
import {IERC4626VaultControls} from "../src/interfaces/IERC4626VaultControls.sol";
import {IERC4626VaultControlsFacet} from "../src/interfaces/IERC4626VaultControlsFacet.sol";
import {IERC4626VaultFacet} from "../src/interfaces/IERC4626VaultFacet.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {IReentrancyGuard} from "../src/interfaces/IReentrancyGuard.sol";
import {LibVaultFacetSelectors} from "../src/vault/libraries/LibVaultFacetSelectors.sol";
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
        bytes4[] memory controlSelectors = LibVaultFacetSelectors.vaultControlsSelectors();

        assertTrue(coreSelectors.length == 28, "unexpected core selector count");
        assertTrue(controlSelectors.length == 28, "unexpected controls selector count");

        _assertContains(coreSelectors, IERC4626VaultFacet.initializeVault.selector);
        _assertContains(coreSelectors, IERC4626.deposit.selector);
        _assertContains(coreSelectors, IERC4626.redeem.selector);
        _assertContains(coreSelectors, IERC4626VaultBase.totalManagedAssets.selector);

        _assertContains(controlSelectors, IERC4626VaultControls.setFeeConfig.selector);
        _assertContains(controlSelectors, IERC4626VaultControls.setLimitConfig.selector);
        _assertContains(controlSelectors, IAccessControlTime.grantRoleWithWindow.selector);
        _assertContains(controlSelectors, IReentrancyGuard.reentrancyGuardEntered.selector);
        _assertContains(controlSelectors, IERC165.supportsInterface.selector);

        _assertUnique(coreSelectors);
        _assertUnique(controlSelectors);
        _assertDisjoint(coreSelectors, controlSelectors);
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
