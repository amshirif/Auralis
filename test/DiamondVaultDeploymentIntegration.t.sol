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
import {IERC4626VaultStrategy} from "../src/interfaces/IERC4626VaultStrategy.sol";
import {IERC7535VaultFacet} from "../src/interfaces/IERC7535VaultFacet.sol";
import {IOracleAdapter} from "../src/interfaces/IOracleAdapter.sol";
import {LibVaultFacetSelectors} from "../src/vault/libraries/LibVaultFacetSelectors.sol";
import {LibVaultAsset} from "../src/vault/libraries/LibVaultAsset.sol";
import {DiamondVaultDeploymentFixture} from "./helpers/DiamondVaultDeploymentTestHarness.sol";

contract DiamondVaultDeploymentIntegrationTest is DiamondVaultDeploymentFixture {
    function testVaultHostDeployInstallInitOracleAndStrategyWiring() public {
        _installVaultHostFacets();
        _initializeVaultHost();
        _wireOracleAdapter();
        _wireStrategy();

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
            loupe.facetAddress(IERC4626VaultIntegrationFacet.deployToStrategy.selector) == address(integrationFacet),
            "deploy strategy selector owner mismatch"
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
        assertTrue(integrationFacetInterface().strategy() == address(strategy), "strategy should be configured");
        assertTrue(integrationFacetInterface().strategyDebt() == 0, "strategy debt should be zero");
        assertFalse(integrationFacetInterface().strategyEmergencyExit(), "emergency exit should be inactive");
        assertTrue(integrationFacetInterface().liveStrategyAssets() == 0, "live strategy assets should be zero");
        assertTrue(IERC4626VaultStrategy(address(strategy)).vault() == address(diamond), "strategy vault mismatch");
        assertTrue(IERC4626VaultStrategy(address(strategy)).asset() == address(asset), "strategy asset mismatch");
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

    function testVaultHostSmokeCoversStrategyLifecycle() public {
        _installVaultHostFacets();
        _initializeVaultHost();
        _wireOracleAdapter();
        _wireStrategy();

        asset.mint(admin, 1_500_000_000);
        VM.prank(admin);
        asset.approve(address(diamond), 1_500_000_000);
        VM.prank(admin);
        coreFacetInterface().deposit(1_000_000_000, admin);

        VM.prank(admin);
        integrationFacetInterface().deployToStrategy(600_000_000);
        strategy.injectProfit(100_000_000);
        VM.prank(admin);
        integrationFacetInterface().syncStrategyAssets();

        assertTrue(integrationFacetInterface().strategyDebt() == 700_000_000, "strategy debt mismatch after sync");
        assertTrue(coreFacetInterface().totalManagedAssets() == 1_100_000_000, "book value mismatch after sync");
        assertTrue(coreFacetInterface().totalAssets() == 1_100_000_000, "total assets mismatch after sync");

        VM.prank(admin);
        uint256 managerReturned = integrationFacetInterface().withdrawFromStrategy(150_000_000);
        assertTrue(managerReturned == 150_000_000, "manager withdraw should return requested assets");
        assertTrue(
            integrationFacetInterface().strategyDebt() == 550_000_000, "strategy debt mismatch after manager withdraw"
        );

        VM.prank(admin);
        coreFacetInterface().withdraw(700_000_000, admin, admin);

        assertTrue(
            integrationFacetInterface().strategyDebt() == 400_000_000, "strategy debt mismatch after user withdraw"
        );
        assertTrue(integrationFacetInterface().liveStrategyAssets() == 400_000_000, "live strategy assets mismatch");
        assertTrue(integrationFacetInterface().idleAssets() == 0, "idle assets should be exhausted after auto-pull");
        assertTrue(coreFacetInterface().totalManagedAssets() == 400_000_000, "book value mismatch after user withdraw");

        VM.prank(admin);
        uint256 emergencyAssets = integrationFacetInterface().emergencyExitStrategy();

        assertTrue(emergencyAssets == 400_000_000, "emergency exit should unwind remaining assets");
        assertTrue(integrationFacetInterface().strategyEmergencyExit(), "emergency exit should be active");
        assertTrue(integrationFacetInterface().strategyDebt() == 0, "strategy debt should be zero after unwind");
        assertTrue(integrationFacetInterface().idleAssets() == 400_000_000, "idle assets should contain unwound funds");

        VM.prank(admin);
        integrationFacetInterface().setStrategy(address(0));
        VM.prank(admin);
        integrationFacetInterface().setStrategy(address(strategy));

        assertFalse(integrationFacetInterface().strategyEmergencyExit(), "emergency exit should clear on rebind");
        assertTrue(integrationFacetInterface().strategy() == address(strategy), "strategy should be rebound");
        assertTrue(integrationFacetInterface().strategyDebt() == 0, "strategy debt should reset to zero");
    }

    function testNativeVaultHostDeployInstallInitOracleAndStrategyWiring() public {
        _installNativeVaultHostFacets();
        _initializeNativeVaultHost();
        _wireOracleAdapter();
        _wireNativeStrategy();

        IDiamondLoupe loupe = IDiamondLoupe(address(diamond));
        address[] memory facetAddresses = loupe.facetAddresses();
        IOracleAdapter.OracleQuote memory quotePayload = integrationFacetInterface().oracleQuote();

        assertTrue(facetAddresses.length == 6, "native vault host facet count mismatch");
        assertTrue(_containsAddress(facetAddresses, address(cutFacet)), "missing cut facet");
        assertTrue(_containsAddress(facetAddresses, address(loupeFacet)), "missing loupe facet");
        assertTrue(_containsAddress(facetAddresses, address(coreFacet)), "missing core facet");
        assertTrue(_containsAddress(facetAddresses, address(nativeFacet)), "missing native facet");
        assertTrue(_containsAddress(facetAddresses, address(controlsFacet)), "missing controls facet");
        assertTrue(_containsAddress(facetAddresses, address(integrationFacet)), "missing integration facet");

        assertTrue(
            loupe.facetFunctionSelectors(address(coreFacet)).length
                == LibVaultFacetSelectors.vaultCoreSelectors().length,
            "unexpected core selector count"
        );
        assertTrue(
            loupe.facetFunctionSelectors(address(nativeFacet)).length
                == LibVaultFacetSelectors.vaultNativeSelectors().length,
            "unexpected native selector count"
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
        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultNativeSelectors(), address(nativeFacet));
        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultControlsSelectors(), address(controlsFacet));
        _assertSelectorsOwnedByFacet(LibVaultFacetSelectors.vaultIntegrationSelectors(), address(integrationFacet));

        assertTrue(loupe.facetAddress(DiamondCutFacet.diamondCut.selector) == address(cutFacet), "cut owner mismatch");
        assertTrue(loupe.facetAddress(DiamondLoupeFacet.facets.selector) == address(loupeFacet), "loupe owner mismatch");
        assertTrue(
            loupe.facetAddress(IERC4626VaultFacet.initializeVault.selector) == address(coreFacet), "init owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IERC7535VaultFacet.depositNative.selector) == address(nativeFacet),
            "native deposit owner mismatch"
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
            loupe.facetAddress(IERC4626VaultIntegrationFacet.deployToStrategy.selector) == address(integrationFacet),
            "deploy strategy selector owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IERC165.supportsInterface.selector) == address(controlsFacet),
            "supportsInterface owner mismatch"
        );

        assertTrue(coreFacetInterface().isVaultInitialized(), "vault should be initialized");
        assertTrue(coreFacetInterface().asset() == LibVaultAsset.NATIVE_ASSET_SENTINEL, "asset mismatch");
        assertTrue(
            keccak256(bytes(IERC20Metadata(address(diamond)).name())) == keccak256(bytes("Native Vault Share")),
            "name mismatch"
        );
        assertTrue(
            keccak256(bytes(IERC20Metadata(address(diamond)).symbol())) == keccak256(bytes("nvSHARE")),
            "symbol mismatch"
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
        assertTrue(integrationFacetInterface().strategy() == address(nativeStrategy), "strategy should be configured");
        assertTrue(integrationFacetInterface().strategyDebt() == 0, "strategy debt should be zero");
        assertFalse(integrationFacetInterface().strategyEmergencyExit(), "emergency exit should be inactive");
        assertTrue(integrationFacetInterface().liveStrategyAssets() == 0, "live strategy assets should be zero");
        assertTrue(
            IERC4626VaultStrategy(address(nativeStrategy)).vault() == address(diamond), "strategy vault mismatch"
        );
        assertTrue(
            IERC4626VaultStrategy(address(nativeStrategy)).asset() == LibVaultAsset.NATIVE_ASSET_SENTINEL,
            "strategy asset mismatch"
        );
        assertTrue(quotePayload.value == 100_000_000, "quote value mismatch");
        assertTrue(quotePayload.updatedAt == quoteUpdatedAt, "quote timestamp mismatch");
        assertTrue(quotePayload.decimals == 8, "quote decimals mismatch");

        assertTrue(
            IERC165(address(diamond)).supportsInterface(type(IERC4626VaultFacet).interfaceId), "missing core interface"
        );
        assertTrue(
            IERC165(address(diamond)).supportsInterface(type(IERC7535VaultFacet).interfaceId),
            "missing native interface"
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
        coreFacetInterface()
            .initializeVault(LibVaultAsset.NATIVE_ASSET_SENTINEL, "Native Vault Share", "nvSHARE", admin);
    }

    function testNativeVaultHostSmokeCoversStrategyLifecycle() public {
        _installNativeVaultHostFacets();
        _initializeNativeVaultHost();
        _wireOracleAdapter();
        _wireNativeStrategy();

        VM.deal(address(this), 1 ether);
        VM.deal(alice, 2 ether);
        VM.prank(alice);
        IERC7535VaultFacet(address(diamond)).depositNative{value: 1 ether}(alice);

        VM.prank(admin);
        integrationFacetInterface().deployToStrategy(0.6 ether);
        nativeStrategy.injectProfit{value: 0.1 ether}();
        VM.prank(admin);
        integrationFacetInterface().syncStrategyAssets();

        assertTrue(integrationFacetInterface().strategyDebt() == 0.7 ether, "strategy debt mismatch after sync");
        assertTrue(coreFacetInterface().totalManagedAssets() == 1.1 ether, "book value mismatch after sync");
        assertTrue(coreFacetInterface().totalAssets() == 1.1 ether, "total assets mismatch after sync");

        VM.prank(admin);
        uint256 managerReturned = integrationFacetInterface().withdrawFromStrategy(0.15 ether);
        assertTrue(managerReturned == 0.15 ether, "manager withdraw should return requested assets");
        assertTrue(
            integrationFacetInterface().strategyDebt() == 0.55 ether, "strategy debt mismatch after manager withdraw"
        );

        uint256 aliceBalanceBeforeWithdraw = alice.balance;
        VM.prank(alice);
        coreFacetInterface().withdraw(0.7 ether, alice, alice);

        assertTrue(alice.balance == aliceBalanceBeforeWithdraw + 0.7 ether, "native withdraw payout mismatch");
        assertTrue(
            integrationFacetInterface().strategyDebt() == 0.4 ether, "strategy debt mismatch after user withdraw"
        );
        assertTrue(integrationFacetInterface().liveStrategyAssets() == 0.4 ether, "live strategy assets mismatch");
        assertTrue(integrationFacetInterface().idleAssets() == 0, "idle assets should be exhausted after auto-pull");
        assertTrue(coreFacetInterface().totalManagedAssets() == 0.4 ether, "book value mismatch after user withdraw");

        VM.prank(admin);
        uint256 emergencyAssets = integrationFacetInterface().emergencyExitStrategy();

        assertTrue(emergencyAssets == 0.4 ether, "emergency exit should unwind remaining assets");
        assertTrue(integrationFacetInterface().strategyEmergencyExit(), "emergency exit should be active");
        assertTrue(integrationFacetInterface().strategyDebt() == 0, "strategy debt should be zero after unwind");
        assertTrue(integrationFacetInterface().idleAssets() == 0.4 ether, "idle assets should contain unwound funds");

        VM.prank(admin);
        integrationFacetInterface().setStrategy(address(0));
        VM.prank(admin);
        integrationFacetInterface().setStrategy(address(nativeStrategy));

        assertFalse(integrationFacetInterface().strategyEmergencyExit(), "emergency exit should clear on rebind");
        assertTrue(integrationFacetInterface().strategy() == address(nativeStrategy), "strategy should be rebound");
        assertTrue(integrationFacetInterface().strategyDebt() == 0, "strategy debt should reset to zero");
    }

    function _assertSelectorsOwnedByFacet(bytes4[] memory selectors, address expectedFacet) internal view {
        for (uint256 i = 0; i < selectors.length; i++) {
            assertTrue(
                IDiamondLoupe(address(diamond)).facetAddress(selectors[i]) == expectedFacet, "selector owner mismatch"
            );
        }
    }
}
