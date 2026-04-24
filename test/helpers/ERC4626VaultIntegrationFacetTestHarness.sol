// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {IERC4626VaultFacet} from "../../src/interfaces/IERC4626VaultFacet.sol";
import {ERC7535VaultFacet} from "../../src/vault/facets/ERC7535VaultFacet.sol";
import {ERC4626VaultIntegrationFacet} from "../../src/vault/facets/ERC4626VaultIntegrationFacet.sol";
import {LibVaultAsset} from "../../src/vault/libraries/LibVaultAsset.sol";
import {LibVaultFacetSelectors} from "../../src/vault/libraries/LibVaultFacetSelectors.sol";
import {DiamondProxyHarness} from "./DiamondTestHarness.sol";
import {TestBase} from "./AccessControlTestHarness.sol";
import {ERC4626VaultControlsFacetHarness} from "./ERC4626VaultControlsFacetTestHarness.sol";
import {ReentrantMockVaultAsset} from "./ERC4626VaultControlsTestHarness.sol";
import {ERC4626VaultFacetHarness} from "./ERC4626VaultFacetTestHarness.sol";
import {MockOracleFeed, OracleAdapterHarness} from "./OracleAdapterTestHarness.sol";
import {MockVaultAsset} from "./ERC4626CoreTestHarness.sol";
import {
    LossShortfallMockVaultStrategy,
    NativeLossShortfallMockVaultStrategy,
    NativeProfitMockVaultStrategy,
    NativeRevertingMockVaultStrategy,
    ProfitMockVaultStrategy,
    RevertingMockVaultStrategy
} from "./ERC4626VaultStrategyTestHarness.sol";

contract ERC4626VaultIntegrationFacetHarness is ERC4626VaultIntegrationFacet {}

contract InitializedERC4626VaultIntegrationFacetHarness is ERC4626VaultIntegrationFacet {
    constructor(address vaultAsset, string memory vaultName, string memory vaultSymbol, address admin) {
        _initializeVaultFacetControl(admin);
        _initializeErc4626Vault(vaultAsset, vaultName, vaultSymbol);
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        _requireInitialized();
        _requireNonZeroAddress(receiver);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        shares = previewDeposit(assets);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        _safeTransferFromAsset(msg.sender, address(this), assets);
        _increaseManagedAssets(assets);
        _mintShares(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        _requireInitialized();
        _requireNonZeroAddress(receiver);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        assets = previewMint(shares);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        _safeTransferFromAsset(msg.sender, address(this), assets);
        _increaseManagedAssets(assets);
        _mintShares(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        _requireInitialized();
        _requireNonZeroAddress(receiver);
        _requireNonZeroAddress(owner);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        shares = previewWithdraw(assets);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _burnShares(owner, shares);
        _decreaseManagedAssetsForAssetExit(assets);
        _safeTransferAsset(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        _requireInitialized();
        _requireNonZeroAddress(receiver);
        _requireNonZeroAddress(owner);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        assets = previewRedeem(shares);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _burnShares(owner, shares);
        _decreaseManagedAssetsForAssetExit(assets);
        _safeTransferAsset(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
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
    ERC7535VaultFacet internal nativeFacet;
    ERC4626VaultControlsFacetHarness internal controlsFacet;
    ERC4626VaultIntegrationFacet internal integrationFacet;
    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal loupeFacet;
    DiamondProxyHarness internal diamond;
    MockOracleFeed internal feed;
    OracleAdapterHarness internal adapter;
    ProfitMockVaultStrategy internal directProfitStrategy;
    LossShortfallMockVaultStrategy internal directLossStrategy;
    RevertingMockVaultStrategy internal directRevertingStrategy;
    ProfitMockVaultStrategy internal diamondProfitStrategy;
    NativeProfitMockVaultStrategy internal diamondNativeProfitStrategy;
    NativeLossShortfallMockVaultStrategy internal diamondNativeLossStrategy;
    NativeRevertingMockVaultStrategy internal diamondNativeRevertingStrategy;
    ProfitMockVaultStrategy internal wrongVaultStrategy;
    ProfitMockVaultStrategy internal directWrongAssetStrategy;

    function setUp() public virtual {
        VM.warp(currentTime);

        asset = new ReentrantMockVaultAsset();
        otherAsset = new MockVaultAsset("Other USD", "oUSD", 6);
        coreFacet = new ERC4626VaultFacetHarness();
        nativeFacet = new ERC7535VaultFacet();
        controlsFacet = new ERC4626VaultControlsFacetHarness();
        integrationFacet = new ERC4626VaultIntegrationFacetHarness();
        cutFacet = new DiamondCutFacet();
        loupeFacet = new DiamondLoupeFacet();
        diamond = new DiamondProxyHarness(admin, address(cutFacet));
        feed = new MockOracleFeed(8);
        feed.setLatestRoundData(1, 100_000_000, quoteUpdatedAt, quoteUpdatedAt, 1);
        adapter = new OracleAdapterHarness(admin, address(feed), maxStaleness);
        diamondProfitStrategy = new ProfitMockVaultStrategy(address(diamond), address(asset));
        diamondNativeProfitStrategy = new NativeProfitMockVaultStrategy(address(diamond));
        diamondNativeLossStrategy = new NativeLossShortfallMockVaultStrategy(address(diamond));
        diamondNativeRevertingStrategy = new NativeRevertingMockVaultStrategy(address(diamond));
        wrongVaultStrategy = new ProfitMockVaultStrategy(address(0xBAD), address(asset));

        asset.mint(bob, INITIAL_ASSETS);
        asset.mint(eve, INITIAL_ASSETS);

        _installLoupeFacet();
    }

    function _initializeDirectIntegrationFacet() internal {
        integrationFacet =
            new InitializedERC4626VaultIntegrationFacetHarness(address(asset), "Vault Share", "vSHARE", admin);
        directProfitStrategy = new ProfitMockVaultStrategy(address(integrationFacet), address(asset));
        directLossStrategy = new LossShortfallMockVaultStrategy(address(integrationFacet), address(asset));
        directRevertingStrategy = new RevertingMockVaultStrategy(address(integrationFacet), address(asset));
        directWrongAssetStrategy = new ProfitMockVaultStrategy(address(integrationFacet), address(otherAsset));
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
