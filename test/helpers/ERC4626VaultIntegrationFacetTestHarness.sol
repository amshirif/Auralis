// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {IERC4626VaultFacet} from "../../src/interfaces/IERC4626VaultFacet.sol";
import {ERC4626VaultIntegrationFacet} from "../../src/vault/facets/ERC4626VaultIntegrationFacet.sol";
import {LibVaultFacetSelectors} from "../../src/vault/libraries/LibVaultFacetSelectors.sol";
import {DiamondProxyHarness} from "./DiamondTestHarness.sol";
import {TestBase} from "./AccessControlTestHarness.sol";
import {ERC4626VaultControlsFacetHarness} from "./ERC4626VaultControlsFacetTestHarness.sol";
import {ReentrantMockVaultAsset} from "./ERC4626VaultControlsTestHarness.sol";
import {ERC4626VaultFacetHarness} from "./ERC4626VaultFacetTestHarness.sol";
import {MockOracleFeed, OracleAdapterHarness} from "./OracleAdapterTestHarness.sol";
import {MockVaultAsset} from "./ERC4626CoreTestHarness.sol";
import {LossShortfallMockVaultStrategy, ProfitMockVaultStrategy} from "./ERC4626VaultStrategyTestHarness.sol";

contract ERC4626VaultIntegrationFacetHarness is ERC4626VaultIntegrationFacet {
    function initializeHostedVaultForTest(
        address vaultAsset,
        string memory vaultName,
        string memory vaultSymbol,
        address admin
    ) external {
        _initializeVaultFacetControl(admin);
        _initializeErc4626Vault(vaultAsset, vaultName, vaultSymbol);
    }
}

abstract contract ERC4626VaultIntegrationFacetFixture is TestBase {
    uint256 internal constant INITIAL_ASSETS = 1_000_000;

    address internal admin = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal eve = address(0xE11E);

    uint64 internal maxStaleness = 1 hours;
    uint64 internal currentTime = 1_000_000;
    uint64 internal quoteUpdatedAt = 999_900;

    ReentrantMockVaultAsset internal asset;
    MockVaultAsset internal otherAsset;
    ERC4626VaultFacetHarness internal coreFacet;
    ERC4626VaultControlsFacetHarness internal controlsFacet;
    ERC4626VaultIntegrationFacetHarness internal integrationFacet;
    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal loupeFacet;
    DiamondProxyHarness internal diamond;
    MockOracleFeed internal feed;
    OracleAdapterHarness internal adapter;
    ProfitMockVaultStrategy internal directProfitStrategy;
    LossShortfallMockVaultStrategy internal directLossStrategy;
    ProfitMockVaultStrategy internal diamondProfitStrategy;
    ProfitMockVaultStrategy internal wrongVaultStrategy;
    ProfitMockVaultStrategy internal directWrongAssetStrategy;

    function setUp() public virtual {
        VM.warp(currentTime);

        asset = new ReentrantMockVaultAsset();
        otherAsset = new MockVaultAsset("Other USD", "oUSD", 6);
        coreFacet = new ERC4626VaultFacetHarness();
        controlsFacet = new ERC4626VaultControlsFacetHarness();
        integrationFacet = new ERC4626VaultIntegrationFacetHarness();
        cutFacet = new DiamondCutFacet();
        loupeFacet = new DiamondLoupeFacet();
        diamond = new DiamondProxyHarness(admin, address(cutFacet));
        feed = new MockOracleFeed(8);
        feed.setLatestRoundData(1, 100_000_000, quoteUpdatedAt, quoteUpdatedAt, 1);
        adapter = new OracleAdapterHarness(admin, address(feed), maxStaleness);
        directProfitStrategy = new ProfitMockVaultStrategy(address(integrationFacet), address(asset));
        directLossStrategy = new LossShortfallMockVaultStrategy(address(integrationFacet), address(asset));
        diamondProfitStrategy = new ProfitMockVaultStrategy(address(diamond), address(asset));
        wrongVaultStrategy = new ProfitMockVaultStrategy(address(0xBAD), address(asset));
        directWrongAssetStrategy = new ProfitMockVaultStrategy(address(integrationFacet), address(otherAsset));

        asset.mint(bob, INITIAL_ASSETS);
        asset.mint(eve, INITIAL_ASSETS);

        _installLoupeFacet();
    }

    function _initializeDirectIntegrationFacet() internal {
        integrationFacet.initializeHostedVaultForTest(address(asset), "Vault Share", "vSHARE", admin);
    }

    function _initializeDiamondVault() internal {
        VM.prank(admin);
        IERC4626VaultFacet(address(diamond)).initializeVault(address(asset), "Vault Share", "vSHARE", admin);
    }

    function _approveAsset(address owner, address spender, uint256 amount) internal {
        VM.prank(owner);
        asset.approve(spender, amount);
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

    function _installVaultCoreFacetToDiamond() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(coreFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultCoreSelectors()
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function _installVaultControlsFacetToDiamond() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(controlsFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultControlsSelectors()
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function _installVaultIntegrationFacetToDiamond() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(integrationFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultIntegrationSelectors()
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function _installHostedVaultFacetsToDiamond() internal {
        _installVaultCoreFacetToDiamond();
        _installVaultControlsFacetToDiamond();
        _installVaultIntegrationFacetToDiamond();
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
