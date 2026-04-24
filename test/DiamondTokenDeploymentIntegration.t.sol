// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IERC20Metadata} from "../src/interfaces/IERC20Metadata.sol";
import {IERC20TokenBase} from "../src/interfaces/IERC20TokenBase.sol";
import {IERC20TokenFacet} from "../src/interfaces/IERC20TokenFacet.sol";
import {IERC721} from "../src/interfaces/IERC721.sol";
import {IERC721Metadata} from "../src/interfaces/IERC721Metadata.sol";
import {IERC721TokenBase} from "../src/interfaces/IERC721TokenBase.sol";
import {IERC721TokenFacet} from "../src/interfaces/IERC721TokenFacet.sol";
import {LibDiamond} from "../src/diamond/libraries/LibDiamond.sol";
import {DiamondTokenDeploymentFixture} from "./helpers/DiamondTokenDeploymentTestHarness.sol";

contract DiamondTokenDeploymentIntegrationTest is DiamondTokenDeploymentFixture {
    function testErc20HostDeployInstallInitAndLoupeChecks() public {
        _installErc20HostFacetAtomically();
        assertTrue(IERC20TokenFacet(address(diamond)).isErc20Initialized(), "erc20 host should initialize inside cut");

        IDiamondLoupe loupe = IDiamondLoupe(address(diamond));
        address[] memory facetAddresses = loupe.facetAddresses();

        assertTrue(facetAddresses.length == 3, "erc20 host facet count mismatch");
        assertTrue(_containsAddress(facetAddresses, address(cutFacet)), "erc20 host missing cut facet");
        assertTrue(_containsAddress(facetAddresses, address(loupeFacet)), "erc20 host missing loupe facet");
        assertTrue(_containsAddress(facetAddresses, address(erc20Facet)), "erc20 host missing erc20 facet");
        assertTrue(loupe.facetFunctionSelectors(address(erc20Facet)).length == 30, "erc20 host selector count mismatch");
        assertTrue(
            loupe.facetAddress(DiamondCutFacet.diamondCut.selector) == address(cutFacet), "erc20 cut owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(DiamondLoupeFacet.facets.selector) == address(loupeFacet), "erc20 loupe owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IERC20TokenFacet.initializeErc20.selector) == address(erc20Facet),
            "erc20 init owner mismatch"
        );
        assertTrue(loupe.facetAddress(IERC20Metadata.name.selector) == address(erc20Facet), "erc20 name owner mismatch");
        assertTrue(
            loupe.facetAddress(IERC165.supportsInterface.selector) == address(erc20Facet),
            "erc20 supportsInterface owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IERC20TokenFacet.TOKEN_ADMIN_ROLE.selector) == address(erc20Facet),
            "erc20 token admin owner mismatch"
        );
        assertTrue(IERC20TokenFacet(address(diamond)).isErc20Initialized(), "erc20 host not initialized");
        assertTrue(
            keccak256(bytes(IERC20TokenFacet(address(diamond)).name())) == keccak256(bytes("Facet Token")),
            "erc20 host name mismatch"
        );
        assertTrue(
            keccak256(bytes(IERC20TokenFacet(address(diamond)).symbol())) == keccak256(bytes("FTKN")),
            "erc20 host symbol mismatch"
        );
        assertTrue(IERC20TokenFacet(address(diamond)).decimals() == 18, "erc20 host decimals mismatch");
        assertTrue(
            IERC20TokenFacet(address(diamond)).hasRole(IERC20TokenFacet(address(diamond)).TOKEN_ADMIN_ROLE(), admin),
            "erc20 host token admin missing"
        );
        assertTrue(
            IERC20TokenFacet(address(diamond)).supportsInterface(type(IERC20TokenFacet).interfaceId),
            "erc20 host interface missing"
        );

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IERC20TokenBase.ERC20TokenAlreadyInitialized.selector));
        IERC20TokenFacet(address(diamond)).initializeErc20("Facet Token", "FTKN", 18, admin);
    }

    function testErc721HostDeployInstallInitAndLoupeChecks() public {
        _installErc721HostFacetAtomically();
        assertTrue(
            IERC721TokenFacet(address(diamond)).isErc721Initialized(), "erc721 host should initialize inside cut"
        );

        IDiamondLoupe loupe = IDiamondLoupe(address(diamond));
        address[] memory facetAddresses = loupe.facetAddresses();

        assertTrue(facetAddresses.length == 3, "erc721 host facet count mismatch");
        assertTrue(_containsAddress(facetAddresses, address(cutFacet)), "erc721 host missing cut facet");
        assertTrue(_containsAddress(facetAddresses, address(loupeFacet)), "erc721 host missing loupe facet");
        assertTrue(_containsAddress(facetAddresses, address(erc721Facet)), "erc721 host missing erc721 facet");
        assertTrue(
            loupe.facetFunctionSelectors(address(erc721Facet)).length == 35, "erc721 host selector count mismatch"
        );
        assertTrue(
            loupe.facetAddress(DiamondCutFacet.diamondCut.selector) == address(cutFacet), "erc721 cut owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(DiamondLoupeFacet.facets.selector) == address(loupeFacet), "erc721 loupe owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IERC721TokenFacet.initializeErc721.selector) == address(erc721Facet),
            "erc721 init owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IERC721Metadata.name.selector) == address(erc721Facet), "erc721 name owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IERC165.supportsInterface.selector) == address(erc721Facet),
            "erc721 supportsInterface owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IERC721TokenFacet.ERC721_METADATA_ROLE.selector) == address(erc721Facet),
            "erc721 metadata owner mismatch"
        );
        assertTrue(IERC721TokenFacet(address(diamond)).isErc721Initialized(), "erc721 host not initialized");
        assertTrue(
            keccak256(bytes(IERC721TokenFacet(address(diamond)).name())) == keccak256(bytes("Facet NFT")),
            "erc721 host name mismatch"
        );
        assertTrue(
            keccak256(bytes(IERC721TokenFacet(address(diamond)).symbol())) == keccak256(bytes("FNFT")),
            "erc721 host symbol mismatch"
        );
        assertTrue(IERC721TokenFacet(address(diamond)).totalSupply() == 0, "erc721 host supply mismatch");
        assertTrue(
            IERC721TokenFacet(address(diamond))
                .hasRole(IERC721TokenFacet(address(diamond)).ERC721_METADATA_ROLE(), admin),
            "erc721 metadata role missing"
        );
        assertTrue(
            IERC721TokenFacet(address(diamond)).supportsInterface(type(IERC721TokenFacet).interfaceId),
            "erc721 host interface missing"
        );

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(IERC721TokenBase.ERC721TokenAlreadyInitialized.selector));
        IERC721TokenFacet(address(diamond)).initializeErc721("Facet NFT", "FNFT", "ipfs://facet/", admin);
    }

    function testErc20AndErc721SelectorsCannotCoexistUnchanged() public {
        _installErc20HostFacet();

        IDiamondLoupe loupe = IDiamondLoupe(address(diamond));
        IDiamondCut.FacetCut[] memory collisionCut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = IERC721.ownerOf.selector;
        selectors[1] = IERC721Metadata.name.selector;
        collisionCut[0] = IDiamondCut.FacetCut({
            facetAddress: address(erc721Facet), action: IDiamondCut.FacetCutAction.Add, functionSelectors: selectors
        });

        VM.prank(admin);
        VM.expectRevert(
            abi.encodeWithSelector(
                LibDiamond.DiamondSelectorAlreadyExists.selector, IERC721Metadata.name.selector, address(erc20Facet)
            )
        );
        IDiamondCut(address(diamond)).diamondCut(collisionCut, address(0), "");

        assertTrue(
            loupe.facetAddress(IERC721.ownerOf.selector) == address(0), "erc721 ownerOf should not be partially routed"
        );
        assertTrue(
            loupe.facetAddress(IERC20Metadata.name.selector) == address(erc20Facet),
            "erc20 name owner should remain unchanged"
        );
        assertTrue(loupe.facetAddresses().length == 3, "collision revert should preserve facet count");
    }
}
