// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../../src/interfaces/IAccessControl.sol";
import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {IERC165} from "../../src/interfaces/IERC165.sol";
import {IERC721} from "../../src/interfaces/IERC721.sol";
import {IERC721Metadata} from "../../src/interfaces/IERC721Metadata.sol";
import {IERC721Receiver} from "../../src/interfaces/IERC721Receiver.sol";
import {IERC721TokenBase} from "../../src/interfaces/IERC721TokenBase.sol";
import {IERC721TokenFacet} from "../../src/interfaces/IERC721TokenFacet.sol";
import {IPausable} from "../../src/interfaces/IPausable.sol";
import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {ERC721TokenFacet} from "../../src/token/facets/ERC721TokenFacet.sol";
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
        bytes4[] memory selectors = new bytes4[](35);
        selectors[0] = IERC721TokenFacet.initializeErc721.selector;
        selectors[1] = IERC721.balanceOf.selector;
        selectors[2] = IERC721.ownerOf.selector;
        selectors[3] = IERC721.approve.selector;
        selectors[4] = IERC721.getApproved.selector;
        selectors[5] = IERC721.setApprovalForAll.selector;
        selectors[6] = IERC721.isApprovedForAll.selector;
        selectors[7] = IERC721.transferFrom.selector;
        selectors[8] = bytes4(keccak256("safeTransferFrom(address,address,uint256)"));
        selectors[9] = bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"));
        selectors[10] = IERC721Metadata.tokenURI.selector;
        selectors[11] = IERC721Metadata.name.selector;
        selectors[12] = IERC721Metadata.symbol.selector;
        selectors[13] = IERC721TokenFacet.totalSupply.selector;
        selectors[14] = IERC721TokenBase.isErc721Initialized.selector;
        selectors[15] = IERC721TokenFacet.mint.selector;
        selectors[16] = IERC721TokenFacet.safeMint.selector;
        selectors[17] = IERC721TokenFacet.burn.selector;
        selectors[18] = IERC721TokenFacet.setBaseURI.selector;
        selectors[19] = IERC721TokenFacet.setTokenURI.selector;
        selectors[20] = IAccessControl.DEFAULT_ADMIN_ROLE.selector;
        selectors[21] = IPausable.PAUSER_ROLE.selector;
        selectors[22] = IERC721TokenFacet.TOKEN_ADMIN_ROLE.selector;
        selectors[23] = IERC721TokenFacet.ERC721_MINTER_ROLE.selector;
        selectors[24] = IERC721TokenFacet.ERC721_BURNER_ROLE.selector;
        selectors[25] = IERC721TokenFacet.ERC721_METADATA_ROLE.selector;
        selectors[26] = IERC721TokenFacet.ERC721_TRANSFER_SCOPE.selector;
        selectors[27] = IERC721TokenFacet.ERC721_APPROVAL_SCOPE.selector;
        selectors[28] = IAccessControl.hasRole.selector;
        selectors[29] = IAccessControl.getRoleAdmin.selector;
        selectors[30] = IAccessControl.grantRole.selector;
        selectors[31] = IPausable.pauseScope.selector;
        selectors[32] = IPausable.unpauseScope.selector;
        selectors[33] = IPausable.scopePaused.selector;
        selectors[34] = IERC165.supportsInterface.selector;

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(facet), action: IDiamondCut.FacetCutAction.Add, functionSelectors: selectors
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }
}
