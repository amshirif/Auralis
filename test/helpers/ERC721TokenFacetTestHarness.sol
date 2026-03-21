// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {IERC721Receiver} from "../../src/interfaces/IERC721Receiver.sol";
import {IERC721TokenFacet} from "../../src/interfaces/IERC721TokenFacet.sol";
import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {ERC721TokenFacet} from "../../src/token/facets/ERC721TokenFacet.sol";
import {LibTokenFacetDeploymentSelectors} from "../../src/token/libraries/LibTokenFacetDeploymentSelectors.sol";
import {DiamondProxyHarness} from "./DiamondTestHarness.sol";
import {TestBase} from "./AccessControlTestHarness.sol";
import {ERC721ReceiverMock, ERC721ReceiverRejector} from "./TokenFacetFoundationTestHarness.sol";

abstract contract ERC721TokenFacetFixture is TestBase {
    address internal admin = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal eve = address(0xE11E);
    address internal carol = address(0xCA401);

    ERC721TokenFacet internal facet;
    DiamondCutFacet internal cutFacet;
    DiamondProxyHarness internal diamond;
    ERC721ReceiverMock internal receiver;
    ERC721ReceiverRejector internal rejector;

    function setUp() public virtual {
        facet = new ERC721TokenFacet();
        cutFacet = new DiamondCutFacet();
        diamond = new DiamondProxyHarness(admin, address(cutFacet));
        receiver = new ERC721ReceiverMock(IERC721Receiver.onERC721Received.selector);
        rejector = new ERC721ReceiverRejector();
    }

    function _erc721Init(address target) internal {
        IERC721TokenFacet(target).initializeErc721("Facet NFT", "FNFT", "ipfs://facet/", admin);
    }

    function _addErc721FacetToDiamond() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibTokenFacetDeploymentSelectors.erc721HostSelectors()
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }
}
