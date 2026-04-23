// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {IERC4626VaultFacet} from "../../src/interfaces/IERC4626VaultFacet.sol";
import {ERC4626VaultControlsFacet} from "../../src/vault/facets/ERC4626VaultControlsFacet.sol";
import {ERC4626VaultFacet} from "../../src/vault/facets/ERC4626VaultFacet.sol";
import {ERC4626VaultIntegrationFacet} from "../../src/vault/facets/ERC4626VaultIntegrationFacet.sol";
import {ERC7535VaultFacet} from "../../src/vault/facets/ERC7535VaultFacet.sol";
import {LibVaultFacetSelectors} from "../../src/vault/libraries/LibVaultFacetSelectors.sol";
import {DiamondProxyHarness} from "./DiamondTestHarness.sol";
import {TestBase} from "./AccessControlTestHarness.sol";
import {ERC7540VaultDepositFacetHarness} from "./ERC7540VaultDepositFacetTestHarness.sol";
import {ERC7540VaultRedeemFacetHarness} from "./ERC7540VaultRedeemFacetTestHarness.sol";
import {ReentrantMockVaultAsset} from "./ERC4626VaultControlsTestHarness.sol";

contract ERC4626VaultFacetHarness is ERC4626VaultFacet {}

contract RejectingNativeReceiver {
    receive() external payable {
        revert("rejecting native asset");
    }
}

abstract contract ERC4626VaultFacetFixture is TestBase {
    uint256 internal constant INITIAL_ASSETS = 1_000_000;

    address internal admin = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal eve = address(0xE11E);

    ReentrantMockVaultAsset internal asset;
    ERC4626VaultFacet internal facet;
    ERC7540VaultDepositFacetHarness internal asyncDepositFacet;
    ERC7540VaultRedeemFacetHarness internal asyncRedeemFacet;
    ERC7535VaultFacet internal nativeFacet;
    ERC4626VaultControlsFacet internal controlsFacet;
    ERC4626VaultIntegrationFacet internal integrationFacet;
    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal loupeFacet;
    DiamondProxyHarness internal diamond;

    function setUp() public virtual {
        asset = new ReentrantMockVaultAsset();
        facet = new ERC4626VaultFacet();
        asyncDepositFacet = new ERC7540VaultDepositFacetHarness();
        asyncRedeemFacet = new ERC7540VaultRedeemFacetHarness();
        nativeFacet = new ERC7535VaultFacet();
        controlsFacet = new ERC4626VaultControlsFacet();
        integrationFacet = new ERC4626VaultIntegrationFacet();
        cutFacet = new DiamondCutFacet();
        loupeFacet = new DiamondLoupeFacet();
        diamond = new DiamondProxyHarness(admin, address(cutFacet));

        asset.mint(bob, INITIAL_ASSETS);
        asset.mint(eve, INITIAL_ASSETS);

        _installLoupeFacet();
    }

    function _initializeHostedVault(address target) internal {
        _initializeHostedVaultWithAsset(target, address(asset));
    }

    function _initializeHostedVaultWithAsset(address target, address vaultAsset) internal {
        IERC4626VaultFacet(target).initializeVault(vaultAsset, "Vault Share", "vSHARE", admin);
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
            facetAddress: address(facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultCoreSelectors()
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

    function _installVaultAsyncDepositSelectorsToDiamond() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(asyncDepositFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultAsyncDepositHostSelectors()
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function _installHostedVaultFacetsToDiamond() internal {
        _installVaultCoreFacetToDiamond();
        _installVaultControlsFacetToDiamond();
    }

    function _installHostedVaultAsyncDepositFacetsToDiamond() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](4);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(facet),
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
            functionSelectors: LibVaultFacetSelectors.vaultAsyncIntegrationSelectors()
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function _installHostedVaultFullyAsyncFacetsToDiamond() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](5);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultFullyAsyncHostCoreSelectors()
        });
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(asyncDepositFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultAsyncDepositHostSelectors()
        });
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(asyncRedeemFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultAsyncRedeemHostSelectors()
        });
        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(controlsFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultControlsSelectors()
        });
        cut[4] = IDiamondCut.FacetCut({
            facetAddress: address(integrationFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultAsyncIntegrationSelectors()
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
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
