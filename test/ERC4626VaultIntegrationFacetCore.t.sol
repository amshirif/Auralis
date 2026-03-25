// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IERC4626VaultBase} from "../src/interfaces/IERC4626VaultBase.sol";
import {IERC4626VaultFacet} from "../src/interfaces/IERC4626VaultFacet.sol";
import {IERC4626VaultIntegrationFacet} from "../src/interfaces/IERC4626VaultIntegrationFacet.sol";
import {IOracleAdapter} from "../src/interfaces/IOracleAdapter.sol";
import {LibVaultFacetSelectors} from "../src/vault/libraries/LibVaultFacetSelectors.sol";
import {ERC4626VaultIntegrationFacetFixture} from "./helpers/ERC4626VaultIntegrationFacetTestHarness.sol";

contract ERC4626VaultIntegrationFacetCoreTest is ERC4626VaultIntegrationFacetFixture {
    function testDirectIntegrationFacetRequiresManagerForConfigAndReporterAuth() public {
        _initializeDirectIntegrationFacet();

        VM.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorized.selector, bob, integrationFacet.VAULT_MANAGER_ROLE()
            )
        );
        VM.prank(bob);
        integrationFacet.setOracleAdapter(address(adapter));

        VM.prank(admin);
        integrationFacet.setOracleAdapter(address(adapter));
        assertTrue(integrationFacet.oracleAdapter() == address(adapter), "adapter mismatch");

        VM.prank(admin);
        integrationFacet.setStrategy(bob);
        assertTrue(integrationFacet.strategy() == bob, "strategy mismatch");

        VM.expectRevert(
            abi.encodeWithSelector(
                IERC4626VaultIntegrationFacet.ERC4626VaultStrategyReporterUnauthorized.selector, eve, bob
            )
        );
        VM.prank(eve);
        integrationFacet.reportStrategyAssets(25);

        VM.prank(bob);
        integrationFacet.reportStrategyAssets(25);
        assertTrue(integrationFacet.strategyReportedAssets() == 25, "reported assets mismatch");
    }

    function testDirectIntegrationFacetChangingStrategyClearsReportedAssets() public {
        _initializeDirectIntegrationFacet();

        VM.prank(admin);
        integrationFacet.setStrategy(bob);
        VM.prank(bob);
        integrationFacet.reportStrategyAssets(75);

        VM.prank(admin);
        integrationFacet.setStrategy(eve);

        assertTrue(integrationFacet.strategy() == eve, "strategy should update");
        assertTrue(integrationFacet.strategyReportedAssets() == 0, "reported assets should reset");

        VM.prank(admin);
        integrationFacet.setStrategy(address(0));
        assertTrue(integrationFacet.strategy() == address(0), "strategy should clear");
        assertTrue(integrationFacet.strategyReportedAssets() == 0, "reported assets should stay cleared");
    }

    function testDirectIntegrationFacetOracleQuoteAndEstimatedAssets() public {
        _initializeDirectIntegrationFacet();

        VM.expectRevert(
            abi.encodeWithSelector(IERC4626VaultIntegrationFacet.ERC4626VaultOracleAdapterNotConfigured.selector)
        );
        integrationFacet.oracleQuote();

        VM.prank(admin);
        integrationFacet.setOracleAdapter(address(adapter));

        asset.mint(address(integrationFacet), 40);

        VM.prank(admin);
        integrationFacet.reportStrategyAssets(25);

        IOracleAdapter.OracleQuote memory quotePayload = integrationFacet.oracleQuote();

        assertTrue(quotePayload.value == 100_000_000, "quote value mismatch");
        assertTrue(quotePayload.updatedAt == quoteUpdatedAt, "quote timestamp mismatch");
        assertTrue(quotePayload.decimals == 8, "quote decimals mismatch");
        assertTrue(integrationFacet.idleAssets() == 40, "idle assets mismatch");
        assertTrue(integrationFacet.estimatedTotalManagedAssets() == 65, "estimated assets mismatch");
        assertTrue(integrationFacet.totalManagedAssets() == 0, "managed assets should remain unchanged");
    }

    function testDirectIntegrationFacetHelpersRevertBeforeVaultInit() public {
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultNotInitialized.selector));
        integrationFacet.idleAssets();

        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultNotInitialized.selector));
        integrationFacet.estimatedTotalManagedAssets();

        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultNotInitialized.selector));
        VM.prank(admin);
        integrationFacet.setOracleAdapter(address(adapter));
    }

    function testDiamondIntegrationFacetRoutesAndComposesWithCoreAndControls() public {
        _installHostedVaultFacetsToDiamond();
        _initializeDiamondVault();

        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        uint256 mintedShares = IERC4626VaultFacet(address(diamond)).deposit(40, bob);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setOracleAdapter(address(adapter));
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setStrategy(eve);

        VM.prank(eve);
        IERC4626VaultIntegrationFacet(address(diamond)).reportStrategyAssets(25);

        IOracleAdapter.OracleQuote memory quotePayload = IERC4626VaultIntegrationFacet(address(diamond)).oracleQuote();

        assertTrue(mintedShares == 40, "deposit shares mismatch");
        assertTrue(
            IERC4626VaultIntegrationFacet(address(diamond)).oracleAdapter() == address(adapter), "adapter mismatch"
        );
        assertTrue(IERC4626VaultIntegrationFacet(address(diamond)).strategy() == eve, "strategy mismatch");
        assertTrue(
            IERC4626VaultIntegrationFacet(address(diamond)).strategyReportedAssets() == 25, "reported assets mismatch"
        );
        assertTrue(IERC4626VaultIntegrationFacet(address(diamond)).idleAssets() == 40, "idle assets mismatch");
        assertTrue(
            IERC4626VaultIntegrationFacet(address(diamond)).estimatedTotalManagedAssets() == 65,
            "estimated assets mismatch"
        );
        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 40, "managed assets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).previewDeposit(10) == 10, "preview should remain core-based");
        assertTrue(quotePayload.value == 100_000_000, "quote value mismatch");
        assertTrue(quotePayload.updatedAt == quoteUpdatedAt, "quote timestamp mismatch");
        assertTrue(quotePayload.decimals == 8, "quote decimals mismatch");

        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultCoreSelectors(), address(coreFacet));
        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultControlsSelectors(), address(controlsFacet));
        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultIntegrationSelectors(), address(integrationFacet));

        assertTrue(
            IDiamondLoupe(address(diamond)).facetAddress(IERC4626VaultFacet.initializeVault.selector)
                == address(coreFacet),
            "initializer selector should stay on core facet"
        );
        assertTrue(
            IERC165(address(diamond)).supportsInterface(type(IERC4626VaultIntegrationFacet).interfaceId),
            "diamond should report integration interface support"
        );
    }

    function testDiamondIntegrationFacetHasNoInitializerSelector() public {
        _installHostedVaultFacetsToDiamond();

        bytes4[] memory selectors = LibVaultFacetSelectors.vaultIntegrationSelectors();
        for (uint256 i = 0; i < selectors.length; i++) {
            assertTrue(
                selectors[i] != IERC4626VaultFacet.initializeVault.selector,
                "integration facet should not own initializer selector"
            );
        }
    }

    function _assertSelectorsOwnedByFacet(bytes4[] memory selectors, address expectedFacet) internal view {
        for (uint256 i = 0; i < selectors.length; i++) {
            assertTrue(
                IDiamondLoupe(address(diamond)).facetAddress(selectors[i]) == expectedFacet, "selector owner mismatch"
            );
        }
    }
}
