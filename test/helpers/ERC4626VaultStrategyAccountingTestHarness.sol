// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {IERC4626VaultFacet} from "../../src/interfaces/IERC4626VaultFacet.sol";
import {IERC4626VaultStrategy} from "../../src/interfaces/IERC4626VaultStrategy.sol";
import {ERC7535VaultFacet} from "../../src/vault/facets/ERC7535VaultFacet.sol";
import {LibVaultAsset} from "../../src/vault/libraries/LibVaultAsset.sol";
import {ERC4626VaultFacet} from "../../src/vault/facets/ERC4626VaultFacet.sol";
import {LibVaultFacetSelectors} from "../../src/vault/libraries/LibVaultFacetSelectors.sol";
import {LibERC4626VaultStorage} from "../../src/vault/storage/LibERC4626VaultStorage.sol";
import {DiamondProxyHarness} from "./DiamondTestHarness.sol";
import {TestBase} from "./AccessControlTestHarness.sol";
import {ERC4626VaultControlsFacetHarness} from "./ERC4626VaultControlsFacetTestHarness.sol";
import {ReentrantMockVaultAsset} from "./ERC4626VaultControlsTestHarness.sol";
import {ERC4626VaultIntegrationFacetHarness} from "./ERC4626VaultIntegrationFacetTestHarness.sol";
import {
    LossShortfallMockVaultStrategy,
    NativeLossShortfallMockVaultStrategy,
    NativeProfitMockVaultStrategy,
    NativeRevertingMockVaultStrategy,
    ProfitMockVaultStrategy,
    RevertingMockVaultStrategy
} from "./ERC4626VaultStrategyTestHarness.sol";

contract ERC4626VaultStrategyAccountingInitMock {
    function seedStrategyState(address strategy_, uint256 strategyDebt_) external {
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        layout.strategy = strategy_;
        layout.strategyDebt = strategyDebt_;
    }
}

abstract contract ERC4626VaultStrategyAccountingFixture is TestBase {
    uint256 internal constant INITIAL_ASSETS = 1_000_000;
    uint256 internal constant DEPOSIT_ASSETS = 100;
    uint256 internal constant STRATEGY_DEBT = 60;

    address internal admin = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal eve = address(0xE11E);

    ReentrantMockVaultAsset internal asset;
    ERC4626VaultFacet internal facet;
    ERC7535VaultFacet internal nativeFacet;
    ERC4626VaultControlsFacetHarness internal controlsFacet;
    ERC4626VaultIntegrationFacetHarness internal integrationFacet;
    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal loupeFacet;
    DiamondProxyHarness internal diamond;
    ERC4626VaultStrategyAccountingInitMock internal accountingInit;
    ProfitMockVaultStrategy internal directProfitStrategy;
    LossShortfallMockVaultStrategy internal directLossStrategy;
    RevertingMockVaultStrategy internal directRevertingStrategy;
    ProfitMockVaultStrategy internal diamondProfitStrategy;
    RevertingMockVaultStrategy internal diamondRevertingStrategy;
    NativeProfitMockVaultStrategy internal diamondNativeProfitStrategy;
    NativeLossShortfallMockVaultStrategy internal diamondNativeLossStrategy;
    NativeRevertingMockVaultStrategy internal diamondNativeRevertingStrategy;

    function setUp() public virtual {
        asset = new ReentrantMockVaultAsset();
        facet = new ERC4626VaultFacet();
        nativeFacet = new ERC7535VaultFacet();
        controlsFacet = new ERC4626VaultControlsFacetHarness();
        integrationFacet = new ERC4626VaultIntegrationFacetHarness();
        cutFacet = new DiamondCutFacet();
        loupeFacet = new DiamondLoupeFacet();
        diamond = new DiamondProxyHarness(admin, address(cutFacet));
        accountingInit = new ERC4626VaultStrategyAccountingInitMock();
        directProfitStrategy = new ProfitMockVaultStrategy(address(facet), address(asset));
        directLossStrategy = new LossShortfallMockVaultStrategy(address(facet), address(asset));
        directRevertingStrategy = new RevertingMockVaultStrategy(address(facet), address(asset));
        diamondProfitStrategy = new ProfitMockVaultStrategy(address(diamond), address(asset));
        diamondRevertingStrategy = new RevertingMockVaultStrategy(address(diamond), address(asset));
        diamondNativeProfitStrategy = new NativeProfitMockVaultStrategy(address(diamond));
        diamondNativeLossStrategy = new NativeLossShortfallMockVaultStrategy(address(diamond));
        diamondNativeRevertingStrategy = new NativeRevertingMockVaultStrategy(address(diamond));

        asset.mint(bob, INITIAL_ASSETS);
        asset.mint(eve, INITIAL_ASSETS);

        _installLoupeFacet();
    }

    function _initializeDirectVault() internal {
        facet.initializeVault(address(asset), "Vault Share", "vSHARE", admin);
    }

    function _initializeDiamondVault() internal {
        VM.prank(admin);
        IERC4626VaultFacet(address(diamond)).initializeVault(address(asset), "Vault Share", "vSHARE", admin);
    }

    function _initializeDiamondNativeVault() internal {
        VM.prank(admin);
        IERC4626VaultFacet(address(diamond))
            .initializeVault(LibVaultAsset.NATIVE_ASSET_SENTINEL, "Vault Share", "vSHARE", admin);
    }

    function _setDirectStrategy(IERC4626VaultStrategy strategy_, uint256 strategyDebt_) internal {
        bytes32 baseSlot = LibERC4626VaultStorage.STORAGE_SLOT;
        VM.store(address(facet), bytes32(uint256(baseSlot) + 12), bytes32(uint256(uint160(address(strategy_)))));
        VM.store(address(facet), bytes32(uint256(baseSlot) + 14), bytes32(strategyDebt_));
        _simulateStrategyDeployment(address(facet), strategy_, strategyDebt_);
    }

    function _approveAsset(address owner, address spender, uint256 amount) internal {
        VM.prank(owner);
        asset.approve(spender, amount);
    }

    function _seedDiamondStrategyState(address strategy_, uint256 strategyDebt_) internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        VM.prank(admin);
        IDiamondCut(address(diamond))
            .diamondCut(
                cut,
                address(accountingInit),
                abi.encodeCall(ERC4626VaultStrategyAccountingInitMock.seedStrategyState, (strategy_, strategyDebt_))
            );
    }

    function _simulateStrategyDeployment(address vaultAccount, IERC4626VaultStrategy strategy_, uint256 assets_)
        internal
    {
        VM.prank(vaultAccount);
        asset.transfer(address(strategy_), assets_);

        VM.prank(vaultAccount);
        strategy_.deployFunds(assets_);
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
            facetAddress: address(facet),
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

    function _installVaultNativeFacetToDiamond() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(nativeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultNativeSelectors()
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

    function _installHostedVaultNativeFacetsToDiamond() internal {
        _installHostedVaultFacetsToDiamond();
        _installVaultNativeFacetToDiamond();
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
