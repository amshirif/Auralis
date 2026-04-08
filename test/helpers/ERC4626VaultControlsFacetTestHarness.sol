// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {IERC4626VaultControlsFacet} from "../../src/interfaces/IERC4626VaultControlsFacet.sol";
import {IERC4626VaultFacet} from "../../src/interfaces/IERC4626VaultFacet.sol";
import {ERC4626Vault} from "../../src/vault/ERC4626Vault.sol";
import {ERC4626VaultControlsFacet} from "../../src/vault/facets/ERC4626VaultControlsFacet.sol";
import {ERC7535VaultFacet} from "../../src/vault/facets/ERC7535VaultFacet.sol";
import {LibVaultFacetSelectors} from "../../src/vault/libraries/LibVaultFacetSelectors.sol";
import {DiamondProxyHarness} from "./DiamondTestHarness.sol";
import {ERC4626VaultFacetHarness} from "./ERC4626VaultFacetTestHarness.sol";
import {TestBase} from "./AccessControlTestHarness.sol";
import {ReentrantMockVaultAsset} from "./ERC4626VaultControlsTestHarness.sol";

contract ERC4626VaultControlsFacetHarness is ERC4626VaultControlsFacet, ERC4626Vault {
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

abstract contract ERC4626VaultControlsFacetFixture is TestBase {
    uint256 internal constant INITIAL_ASSETS = 1_000_000;

    address internal admin = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal eve = address(0xE11E);

    ReentrantMockVaultAsset internal asset;
    ERC4626VaultFacetHarness internal coreFacet;
    ERC7535VaultFacet internal nativeFacet;
    ERC4626VaultControlsFacetHarness internal controlsFacet;
    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal loupeFacet;
    DiamondProxyHarness internal diamond;

    function setUp() public virtual {
        asset = new ReentrantMockVaultAsset();
        coreFacet = new ERC4626VaultFacetHarness();
        nativeFacet = new ERC7535VaultFacet();
        controlsFacet = new ERC4626VaultControlsFacetHarness();
        cutFacet = new DiamondCutFacet();
        loupeFacet = new DiamondLoupeFacet();
        diamond = new DiamondProxyHarness(admin, address(cutFacet));

        asset.mint(bob, INITIAL_ASSETS);
        asset.mint(eve, INITIAL_ASSETS);

        _installLoupeFacet();
    }

    function _initializeDirectControlsFacet() internal {
        controlsFacet.initializeHostedVaultForTest(address(asset), "Vault Share", "vSHARE", admin);
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

    function _installHostedVaultFacetsToDiamond() internal {
        _installVaultCoreFacetToDiamond();
        _installVaultControlsFacetToDiamond();
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
