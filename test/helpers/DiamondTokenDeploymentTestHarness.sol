// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {IERC20TokenFacet} from "../../src/interfaces/IERC20TokenFacet.sol";
import {IERC721TokenFacet} from "../../src/interfaces/IERC721TokenFacet.sol";
import {ERC20TokenFacet} from "../../src/token/facets/ERC20TokenFacet.sol";
import {ERC721TokenFacet} from "../../src/token/facets/ERC721TokenFacet.sol";
import {LibTokenFacetDeploymentSelectors} from "../../src/token/libraries/LibTokenFacetDeploymentSelectors.sol";
import {DiamondProxyHarness} from "./DiamondTestHarness.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

abstract contract DiamondTokenDeploymentFixture is TestBase {
    address internal admin = address(0xA11CE);

    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal loupeFacet;
    ERC20TokenFacet internal erc20Facet;
    ERC721TokenFacet internal erc721Facet;
    DiamondProxyHarness internal diamond;

    function setUp() public virtual {
        cutFacet = new DiamondCutFacet();
        loupeFacet = new DiamondLoupeFacet();
        erc20Facet = new ERC20TokenFacet();
        erc721Facet = new ERC721TokenFacet();
        diamond = new DiamondProxyHarness(admin, address(cutFacet));

        _installLoupeFacet();
    }

    function _installLoupeFacet() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibTokenFacetDeploymentSelectors.loupeSelectors()
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function _installErc20HostFacet() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(erc20Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibTokenFacetDeploymentSelectors.erc20HostSelectors()
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function _installErc20HostFacetAtomically() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(erc20Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibTokenFacetDeploymentSelectors.erc20HostSelectors()
        });

        VM.prank(admin);
        IDiamondCut(address(diamond))
            .diamondCut(
                cut,
                address(erc20Facet),
                abi.encodeCall(IERC20TokenFacet.initializeErc20, ("Facet Token", "FTKN", 18, admin))
            );
    }

    function _installErc721HostFacet() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(erc721Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibTokenFacetDeploymentSelectors.erc721HostSelectors()
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function _installErc721HostFacetAtomically() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(erc721Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibTokenFacetDeploymentSelectors.erc721HostSelectors()
        });

        VM.prank(admin);
        IDiamondCut(address(diamond))
            .diamondCut(
                cut,
                address(erc721Facet),
                abi.encodeCall(IERC721TokenFacet.initializeErc721, ("Facet NFT", "FNFT", "ipfs://facet/", admin))
            );
    }

    function _containsAddress(address[] memory addresses, address expected) internal pure returns (bool) {
        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == expected) {
                return true;
            }
        }

        return false;
    }
}
