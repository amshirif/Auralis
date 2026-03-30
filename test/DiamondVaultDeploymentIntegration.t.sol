// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IERC20Metadata} from "../src/interfaces/IERC20Metadata.sol";
import {IERC4626VaultBase} from "../src/interfaces/IERC4626VaultBase.sol";
import {IERC4626VaultControls} from "../src/interfaces/IERC4626VaultControls.sol";
import {IERC4626VaultControlsFacet} from "../src/interfaces/IERC4626VaultControlsFacet.sol";
import {IERC4626VaultFacet} from "../src/interfaces/IERC4626VaultFacet.sol";
import {IERC4626VaultIntegrationFacet} from "../src/interfaces/IERC4626VaultIntegrationFacet.sol";
import {IOracleAdapter} from "../src/interfaces/IOracleAdapter.sol";
import {LibVaultFacetSelectors} from "../src/vault/libraries/LibVaultFacetSelectors.sol";
import {DiamondVaultDeploymentFixture} from "./helpers/DiamondVaultDeploymentTestHarness.sol";

contract DiamondVaultDeploymentIntegrationTest is DiamondVaultDeploymentFixture {
    function testVaultHostDeployInstallInitAndOracleWiring() public {
        _installVaultHostFacets();
        _initializeVaultHost();
        _wireOracleAdapter();

        IDiamondLoupe loupe = IDiamondLoupe(address(diamond));
        address[] memory facetAddresses = loupe.facetAddresses();
        IOracleAdapter.OracleQuote memory quotePayload = integrationFacetInterface().oracleQuote();

        assertTrue(facetAddresses.length == 5, "vault host facet count mismatch");
        assertTrue(_containsAddress(facetAddresses, address(cutFacet)), "missing cut facet");
        assertTrue(_containsAddress(facetAddresses, address(loupeFacet)), "missing loupe facet");
        assertTrue(_containsAddress(facetAddresses, address(coreFacet)), "missing core facet");
        assertTrue(_containsAddress(facetAddresses, address(controlsFacet)), "missing controls facet");
        assertTrue(_containsAddress(facetAddresses, address(integrationFacet)), "missing integration facet");

        assertTrue(
            loupe.facetFunctionSelectors(address(coreFacet)).length
                == LibVaultFacetSelectors.vaultCoreSelectors().length,
            "unexpected core selector count"
        );
        assertTrue(
            loupe.facetFunctionSelectors(address(controlsFacet)).length
                == LibVaultFacetSelectors.vaultControlsSelectors().length,
            "unexpected controls selector count"
        );
        assertTrue(
            loupe.facetFunctionSelectors(address(integrationFacet)).length
                == LibVaultFacetSelectors.vaultIntegrationSelectors().length,
            "unexpected integration selector count"
        );

        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultCoreSelectors(), address(coreFacet));
        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultControlsSelectors(), address(controlsFacet));
        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultIntegrationSelectors(), address(integrationFacet));

        assertTrue(loupe.facetAddress(DiamondCutFacet.diamondCut.selector) == address(cutFacet), "cut owner mismatch");
        assertTrue(loupe.facetAddress(DiamondLoupeFacet.facets.selector) == address(loupeFacet), "loupe owner mismatch");
        assertTrue(
            loupe.facetAddress(IERC4626VaultFacet.initializeVault.selector) == address(coreFacet), "init owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IERC4626VaultControls.VAULT_MANAGER_ROLE.selector) == address(controlsFacet),
            "vault manager owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IERC4626VaultIntegrationFacet.oracleAdapter.selector) == address(integrationFacet),
            "oracle selector owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IERC165.supportsInterface.selector) == address(controlsFacet),
            "supportsInterface owner mismatch"
        );

        assertTrue(coreFacetInterface().isVaultInitialized(), "vault should be initialized");
        assertTrue(coreFacetInterface().asset() == address(asset), "asset mismatch");
        assertTrue(
            keccak256(bytes(IERC20Metadata(address(diamond)).name())) == keccak256(bytes("Vault Share")),
            "name mismatch"
        );
        assertTrue(
            keccak256(bytes(IERC20Metadata(address(diamond)).symbol())) == keccak256(bytes("vSHARE")), "symbol mismatch"
        );

        assertTrue(
            controlsFacetInterface().hasRole(controlsFacetInterface().DEFAULT_ADMIN_ROLE(), admin),
            "missing default admin"
        );
        assertTrue(controlsFacetInterface().hasRole(controlsFacetInterface().PAUSER_ROLE(), admin), "missing pauser");
        assertTrue(
            controlsFacetInterface().hasRole(controlsFacetInterface().VAULT_MANAGER_ROLE(), admin),
            "missing vault manager"
        );
        (,, address feeRecipient) = controlsFacetInterface().feeConfig();
        assertTrue(feeRecipient == admin, "fee recipient mismatch");

        assertTrue(integrationFacetInterface().oracleAdapter() == address(adapter), "adapter mismatch");
        assertTrue(integrationFacetInterface().strategy() == address(0), "strategy should be unset");
        assertTrue(integrationFacetInterface().strategyDebt() == 0, "strategy debt should be zero");
        assertTrue(integrationFacetInterface().liveStrategyAssets() == 0, "live strategy assets should be zero");
        assertTrue(quotePayload.value == 100_000_000, "quote value mismatch");
        assertTrue(quotePayload.updatedAt == quoteUpdatedAt, "quote timestamp mismatch");
        assertTrue(quotePayload.decimals == 8, "quote decimals mismatch");

        assertTrue(
            IERC165(address(diamond)).supportsInterface(type(IERC4626VaultFacet).interfaceId), "missing core interface"
        );
        assertTrue(
            IERC165(address(diamond)).supportsInterface(type(IERC4626VaultControlsFacet).interfaceId),
            "missing controls interface"
        );
        assertTrue(
            IERC165(address(diamond)).supportsInterface(type(IERC4626VaultIntegrationFacet).interfaceId),
            "missing integration interface"
        );

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultAlreadyInitialized.selector));
        coreFacetInterface().initializeVault(address(asset), "Vault Share", "vSHARE", admin);
    }

    function _assertSelectorsOwnedByFacet(bytes4[] memory selectors, address expectedFacet) internal view {
        for (uint256 i = 0; i < selectors.length; i++) {
            assertTrue(
                IDiamondLoupe(address(diamond)).facetAddress(selectors[i]) == expectedFacet, "selector owner mismatch"
            );
        }
    }
}
