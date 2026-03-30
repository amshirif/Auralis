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
    function testDirectIntegrationFacetRequiresManagerForConfigAndLifecycle() public {
        _initializeDirectIntegrationFacet();
        _approveAsset(bob, address(integrationFacet), 100);

        VM.prank(bob);
        integrationFacet.deposit(100, bob);

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

        VM.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorized.selector, bob, integrationFacet.VAULT_MANAGER_ROLE()
            )
        );
        VM.prank(bob);
        integrationFacet.setStrategy(address(directProfitStrategy));

        VM.prank(admin);
        integrationFacet.setStrategy(address(directProfitStrategy));
        assertTrue(integrationFacet.strategy() == address(directProfitStrategy), "strategy mismatch");

        VM.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorized.selector, bob, integrationFacet.VAULT_MANAGER_ROLE()
            )
        );
        VM.prank(bob);
        integrationFacet.deployToStrategy(40);

        VM.prank(admin);
        integrationFacet.deployToStrategy(40);

        assertTrue(integrationFacet.strategyDebt() == 40, "strategy debt mismatch");
        assertTrue(integrationFacet.idleAssets() == 60, "idle assets mismatch");
        assertTrue(integrationFacet.liveStrategyAssets() == 40, "live strategy assets mismatch");
    }

    function testDirectIntegrationFacetRejectsInvalidBindingAndOutstandingDebtOnStrategySwap() public {
        _initializeDirectIntegrationFacet();
        _approveAsset(bob, address(integrationFacet), 100);

        VM.prank(bob);
        integrationFacet.deposit(100, bob);

        VM.expectRevert(
            abi.encodeWithSelector(
                IERC4626VaultIntegrationFacet.ERC4626VaultStrategyInvalidVault.selector,
                address(wrongVaultStrategy),
                address(integrationFacet),
                address(0xBAD)
            )
        );
        VM.prank(admin);
        integrationFacet.setStrategy(address(wrongVaultStrategy));

        VM.expectRevert(
            abi.encodeWithSelector(
                IERC4626VaultIntegrationFacet.ERC4626VaultStrategyInvalidAsset.selector,
                address(directWrongAssetStrategy),
                address(asset),
                address(otherAsset)
            )
        );
        VM.prank(admin);
        integrationFacet.setStrategy(address(directWrongAssetStrategy));

        VM.prank(admin);
        integrationFacet.setStrategy(address(directProfitStrategy));
        VM.prank(admin);
        integrationFacet.deployToStrategy(40);

        VM.expectRevert(
            abi.encodeWithSelector(IERC4626VaultIntegrationFacet.ERC4626VaultStrategyDebtOutstanding.selector, 40)
        );
        VM.prank(admin);
        integrationFacet.setStrategy(address(0));

        VM.prank(admin);
        integrationFacet.withdrawFromStrategy(40);
        VM.prank(admin);
        integrationFacet.setStrategy(address(0));

        assertTrue(integrationFacet.strategy() == address(0), "strategy should clear after debt reaches zero");
        assertTrue(integrationFacet.strategyDebt() == 0, "strategy debt should clear after full withdraw");
    }

    function testDirectIntegrationFacetSyncRealizesProfitAndPartialWithdrawPreservesBookValue() public {
        _initializeDirectIntegrationFacet();
        _approveAsset(bob, address(integrationFacet), 100);

        VM.prank(bob);
        integrationFacet.deposit(100, bob);

        VM.prank(admin);
        integrationFacet.setStrategy(address(directProfitStrategy));
        VM.prank(admin);
        integrationFacet.deployToStrategy(60);
        directProfitStrategy.injectProfit(20);

        assertTrue(integrationFacet.totalManagedAssets() == 100, "book value should remain unchanged before sync");
        assertTrue(integrationFacet.liveStrategyAssets() == 80, "live strategy assets should reflect unsynced profit");

        VM.prank(admin);
        integrationFacet.syncStrategyAssets();

        assertTrue(integrationFacet.strategyDebt() == 80, "strategy debt should sync to live assets");
        assertTrue(integrationFacet.liveStrategyAssets() == 80, "live strategy assets mismatch after profit sync");
        assertTrue(integrationFacet.totalManagedAssets() == 120, "book value should realize profit on sync");
        assertTrue(integrationFacet.totalAssets() == 120, "total assets should remain mark-to-market after sync");

        VM.prank(admin);
        integrationFacet.withdrawFromStrategy(30);

        assertTrue(integrationFacet.strategyDebt() == 50, "strategy debt should decrease after withdraw");
        assertTrue(integrationFacet.liveStrategyAssets() == 50, "live strategy assets should decrease after withdraw");
        assertTrue(integrationFacet.idleAssets() == 70, "idle assets should increase after withdraw");
        assertTrue(integrationFacet.totalManagedAssets() == 120, "book value should stay unchanged after pull");
    }

    function testDirectIntegrationFacetSyncRealizesLoss() public {
        _initializeDirectIntegrationFacet();
        _approveAsset(bob, address(integrationFacet), 100);

        VM.prank(bob);
        integrationFacet.deposit(100, bob);

        VM.prank(admin);
        integrationFacet.setStrategy(address(directLossStrategy));
        VM.prank(admin);
        integrationFacet.deployToStrategy(60);
        directLossStrategy.applyLoss(15, 35);

        VM.prank(admin);
        integrationFacet.syncStrategyAssets();

        assertTrue(integrationFacet.strategyDebt() == 45, "strategy debt should sync to loss-adjusted live assets");
        assertTrue(integrationFacet.liveStrategyAssets() == 45, "live strategy assets mismatch after loss sync");
        assertTrue(integrationFacet.totalManagedAssets() == 85, "book value should realize loss on sync");
        assertTrue(integrationFacet.totalAssets() == 85, "total assets should reflect realized loss");
    }

    function testDirectIntegrationFacetRejectsUnexpectedPartialWithdrawResult() public {
        _initializeDirectIntegrationFacet();
        _approveAsset(bob, address(integrationFacet), 100);

        VM.prank(bob);
        integrationFacet.deposit(100, bob);

        VM.prank(admin);
        integrationFacet.setStrategy(address(directLossStrategy));
        VM.prank(admin);
        integrationFacet.deployToStrategy(60);
        directLossStrategy.applyLoss(0, 30);

        VM.expectRevert(
            abi.encodeWithSelector(
                IERC4626VaultIntegrationFacet.ERC4626VaultStrategyUnexpectedWithdrawResult.selector, 40, 30
            )
        );
        VM.prank(admin);
        integrationFacet.withdrawFromStrategy(40);
    }

    function testDirectIntegrationFacetHelpersRevertBeforeVaultInit() public {
        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultNotInitialized.selector));
        integrationFacet.idleAssets();

        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultNotInitialized.selector));
        integrationFacet.liveStrategyAssets();

        VM.expectRevert(abi.encodeWithSelector(IERC4626VaultBase.ERC4626VaultNotInitialized.selector));
        VM.prank(admin);
        integrationFacet.setOracleAdapter(address(adapter));
    }

    function testDiamondIntegrationFacetRoutesAndComposesWithCoreAndControls() public {
        _installHostedVaultFacetsToDiamond();
        _initializeDiamondVault();

        _approveAsset(bob, address(diamond), 100);

        VM.prank(bob);
        uint256 mintedShares = IERC4626VaultFacet(address(diamond)).deposit(100, bob);

        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setOracleAdapter(address(adapter));
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).setStrategy(address(diamondProfitStrategy));
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).deployToStrategy(60);
        diamondProfitStrategy.injectProfit(20);
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).syncStrategyAssets();
        VM.prank(admin);
        IERC4626VaultIntegrationFacet(address(diamond)).withdrawFromStrategy(30);

        IOracleAdapter.OracleQuote memory quotePayload = IERC4626VaultIntegrationFacet(address(diamond)).oracleQuote();

        assertTrue(mintedShares == 100, "deposit shares mismatch");
        assertTrue(
            IERC4626VaultIntegrationFacet(address(diamond)).oracleAdapter() == address(adapter), "adapter mismatch"
        );
        assertTrue(
            IERC4626VaultIntegrationFacet(address(diamond)).strategy() == address(diamondProfitStrategy),
            "strategy mismatch"
        );
        assertTrue(IERC4626VaultIntegrationFacet(address(diamond)).strategyDebt() == 50, "strategy debt mismatch");
        assertTrue(
            IERC4626VaultIntegrationFacet(address(diamond)).liveStrategyAssets() == 50, "live strategy assets mismatch"
        );
        assertTrue(IERC4626VaultIntegrationFacet(address(diamond)).idleAssets() == 70, "idle assets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalManagedAssets() == 120, "managed assets mismatch");
        assertTrue(IERC4626VaultFacet(address(diamond)).totalAssets() == 120, "total assets mismatch");
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
