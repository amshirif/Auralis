// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {ERC7535VaultFacet} from "../../src/vault/facets/ERC7535VaultFacet.sol";
import {ERC4626VaultControlsFacetHarness} from "./ERC4626VaultControlsFacetTestHarness.sol";
import {ERC4626VaultFacetHarness} from "./ERC4626VaultFacetTestHarness.sol";
import {ERC7540VaultDepositFacetHarness} from "./ERC7540VaultDepositFacetTestHarness.sol";
import {ERC4626VaultIntegrationFacetHarness} from "./ERC4626VaultIntegrationFacetTestHarness.sol";
import {MockVaultAsset} from "./ERC4626CoreTestHarness.sol";
import {DiamondProxyHarness} from "./DiamondTestHarness.sol";
import {MockOracleFeed, OracleAdapterHarness} from "./OracleAdapterTestHarness.sol";
import {NativeProfitMockVaultStrategy, ProfitMockVaultStrategy} from "./ERC4626VaultStrategyTestHarness.sol";
import {LibVaultFacetSelectors} from "../../src/vault/libraries/LibVaultFacetSelectors.sol";
import {LibVaultAsset} from "../../src/vault/libraries/LibVaultAsset.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

abstract contract DiamondVaultDeploymentFixture is TestBase {
    address internal admin = address(0xA11CE);
    address internal alice = address(0xA11CE0);

    uint64 internal maxStaleness = 1 hours;
    uint64 internal currentTime = 1_000_000;
    uint64 internal quoteUpdatedAt = 999_900;

    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal loupeFacet;
    ERC4626VaultFacetHarness internal coreFacet;
    ERC7540VaultDepositFacetHarness internal asyncDepositFacet;
    ERC7535VaultFacet internal nativeFacet;
    ERC4626VaultControlsFacetHarness internal controlsFacet;
    ERC4626VaultIntegrationFacetHarness internal integrationFacet;
    DiamondProxyHarness internal diamond;
    MockVaultAsset internal asset;
    MockOracleFeed internal feed;
    OracleAdapterHarness internal adapter;
    ProfitMockVaultStrategy internal strategy;
    NativeProfitMockVaultStrategy internal nativeStrategy;

    function setUp() public virtual {
        VM.warp(currentTime);

        cutFacet = new DiamondCutFacet();
        loupeFacet = new DiamondLoupeFacet();
        coreFacet = new ERC4626VaultFacetHarness();
        asyncDepositFacet = new ERC7540VaultDepositFacetHarness();
        nativeFacet = new ERC7535VaultFacet();
        controlsFacet = new ERC4626VaultControlsFacetHarness();
        integrationFacet = new ERC4626VaultIntegrationFacetHarness();
        diamond = new DiamondProxyHarness(admin, address(cutFacet));
        asset = new MockVaultAsset("Mock USD", "mUSD", 6);
        feed = new MockOracleFeed(8);
        feed.setLatestRoundData(1, 100_000_000, quoteUpdatedAt, quoteUpdatedAt, 1);
        adapter = new OracleAdapterHarness(admin, address(feed), maxStaleness);
        strategy = new ProfitMockVaultStrategy(address(diamond), address(asset));
        nativeStrategy = new NativeProfitMockVaultStrategy(address(diamond));

        _installLoupeFacet();
    }

    function _installLoupeFacet() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _loupeSelectors()
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function _installVaultHostFacets() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](4);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(coreFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultAsyncHostCoreSelectors()
        });
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(asyncDepositFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultAsyncDepositHostSelectors()
        });
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(controlsFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultControlsSelectors()
        });
        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(integrationFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultIntegrationSelectors()
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function _installVaultAsyncDepositTestSelector() internal {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = ERC7540VaultDepositFacetHarness.harnessSettleDepositRequest.selector;

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(asyncDepositFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function _installNativeVaultHostFacets() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](4);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(coreFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultCoreSelectors()
        });
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(nativeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultNativeSelectors()
        });
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(controlsFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultControlsSelectors()
        });
        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(integrationFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultIntegrationSelectors()
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function _initializeVaultHost() internal {
        VM.prank(admin);
        coreFacetInterface().initializeVault(address(asset), "Vault Share", "vSHARE", admin);
    }

    function _initializeNativeVaultHost() internal {
        VM.prank(admin);
        coreFacetInterface()
            .initializeVault(LibVaultAsset.NATIVE_ASSET_SENTINEL, "Native Vault Share", "nvSHARE", admin);
    }

    function _wireOracleAdapter() internal {
        VM.prank(admin);
        integrationFacetInterface().setOracleAdapter(address(adapter));
    }

    function _wireStrategy() internal {
        VM.prank(admin);
        integrationFacetInterface().setStrategy(address(strategy));
    }

    function _wireNativeStrategy() internal {
        VM.prank(admin);
        integrationFacetInterface().setStrategy(address(nativeStrategy));
    }

    function coreFacetInterface() internal view returns (ERC4626VaultFacetHarness) {
        return ERC4626VaultFacetHarness(address(diamond));
    }

    function asyncDepositFacetInterface() internal view returns (ERC7540VaultDepositFacetHarness) {
        return ERC7540VaultDepositFacetHarness(address(diamond));
    }

    function controlsFacetInterface() internal view returns (ERC4626VaultControlsFacetHarness) {
        return ERC4626VaultControlsFacetHarness(address(diamond));
    }

    function integrationFacetInterface() internal view returns (ERC4626VaultIntegrationFacetHarness) {
        return ERC4626VaultIntegrationFacetHarness(address(diamond));
    }

    function _containsAddress(address[] memory addresses, address expected) internal pure returns (bool) {
        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == expected) {
                return true;
            }
        }

        return false;
    }

    function _loupeSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](6);
        selectors[0] = DiamondLoupeFacet.facets.selector;
        selectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        selectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        selectors[3] = DiamondLoupeFacet.facetAddress.selector;
        selectors[4] = DiamondLoupeFacet.owner.selector;
        selectors[5] = DiamondLoupeFacet.transferOwnership.selector;
    }
}
