// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondFacetOne, DiamondFacetTwo, DiamondProxyHarness, TestBase} from "./helpers/DiamondTestHarness.sol";
import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {IERC173} from "../src/interfaces/IERC173.sol";
import {LibDiamond} from "../src/diamond/libraries/LibDiamond.sol";

contract DiamondLoupeCoreTest is TestBase {
    address internal admin = address(0xA11CE);
    address internal eve = address(0xE11E);

    DiamondProxyHarness internal diamond;
    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal loupeFacet;
    DiamondFacetOne internal facetOne;
    DiamondFacetTwo internal facetTwo;

    function setUp() public {
        cutFacet = new DiamondCutFacet();
        diamond = new DiamondProxyHarness(admin, address(cutFacet));
        loupeFacet = new DiamondLoupeFacet();
        facetOne = new DiamondFacetOne();
        facetTwo = new DiamondFacetTwo();

        _installLoupeSelectors();
        diamond.installSelector(address(facetOne), DiamondFacetOne.alpha.selector);
        diamond.installSelector(address(facetOne), DiamondFacetOne.beta.selector);
        diamond.installSelector(address(facetTwo), DiamondFacetTwo.gamma.selector);
    }

    function testLoupeFacetAddressesAndSelectorLookups() public view {
        IDiamondLoupe loupe = IDiamondLoupe(address(diamond));
        address[] memory facetAddresses_ = loupe.facetAddresses();

        assertTrue(facetAddresses_.length == 4, "facet address count mismatch");
        assertTrue(facetAddresses_[0] == address(cutFacet), "cut facet ordering mismatch");
        assertTrue(facetAddresses_[1] == address(loupeFacet), "loupe facet ordering mismatch");
        assertTrue(facetAddresses_[2] == address(facetOne), "facet one ordering mismatch");
        assertTrue(facetAddresses_[3] == address(facetTwo), "facet two ordering mismatch");

        assertTrue(
            loupe.facetAddress(DiamondLoupeFacet.facets.selector) == address(loupeFacet),
            "loupe selector should resolve to loupe facet"
        );
        assertTrue(
            loupe.facetAddress(DiamondCutFacet.diamondCut.selector) == address(cutFacet),
            "diamondCut selector should resolve to cut facet"
        );
        assertTrue(
            loupe.facetAddress(DiamondFacetOne.alpha.selector) == address(facetOne),
            "alpha selector should resolve to facet one"
        );
        assertTrue(
            loupe.facetAddress(DiamondFacetTwo.gamma.selector) == address(facetTwo),
            "gamma selector should resolve to facet two"
        );
        assertTrue(loupe.facetAddress(0xdeadbeef) == address(0), "unknown selector should resolve to zero");
    }

    function testLoupeFacetFunctionSelectorsAndFacetsSnapshot() public view {
        IDiamondLoupe loupe = IDiamondLoupe(address(diamond));

        bytes4[] memory cutSelectors = loupe.facetFunctionSelectors(address(cutFacet));
        bytes4[] memory loupeSelectors = loupe.facetFunctionSelectors(address(loupeFacet));
        bytes4[] memory facetOneSelectors = loupe.facetFunctionSelectors(address(facetOne));
        bytes4[] memory facetTwoSelectors = loupe.facetFunctionSelectors(address(facetTwo));
        bytes4[] memory unknownFacetSelectors = loupe.facetFunctionSelectors(eve);

        assertTrue(cutSelectors.length == 1, "cut facet selector count mismatch");
        assertTrue(loupeSelectors.length == 6, "loupe selector count mismatch");
        assertTrue(facetOneSelectors.length == 2, "facet one selector count mismatch");
        assertTrue(facetTwoSelectors.length == 1, "facet two selector count mismatch");
        assertTrue(unknownFacetSelectors.length == 0, "unknown facet should have no selectors");

        IDiamondLoupe.Facet[] memory facets_ = loupe.facets();
        assertTrue(facets_.length == 4, "facets snapshot count mismatch");
        assertTrue(facets_[0].facetAddress == address(cutFacet), "cut snapshot ordering mismatch");
        assertTrue(facets_[1].facetAddress == address(loupeFacet), "loupe snapshot ordering mismatch");
        assertTrue(facets_[2].facetAddress == address(facetOne), "facet one snapshot ordering mismatch");
        assertTrue(facets_[3].facetAddress == address(facetTwo), "facet two snapshot ordering mismatch");
    }

    function testOwnershipSurfaceReportsCurrentOwner() public view {
        assertTrue(IERC173(address(diamond)).owner() == admin, "owner view mismatch");
    }

    function testOwnerCanTransferOwnershipThroughLoupeFacet() public {
        VM.prank(admin);
        IERC173(address(diamond)).transferOwnership(eve);

        assertTrue(IERC173(address(diamond)).owner() == eve, "ownership transfer mismatch");
    }

    function testNonOwnerCannotTransferOwnership() public {
        VM.prank(eve);
        VM.expectRevert(abi.encodeWithSelector(LibDiamond.DiamondUnauthorized.selector, eve, admin));
        IERC173(address(diamond)).transferOwnership(eve);
    }

    function testTransferOwnershipZeroAddressReverts() public {
        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(LibDiamond.DiamondOwnerZeroAddress.selector));
        IERC173(address(diamond)).transferOwnership(address(0));
    }

    function testLoupeReflectsLiveSelectorReplaceAndRemove() public {
        IDiamondLoupe loupe = IDiamondLoupe(address(diamond));

        assertTrue(
            loupe.facetAddress(DiamondFacetOne.alpha.selector) == address(facetOne), "alpha should start on facet one"
        );

        diamond.replaceSelector(address(facetTwo), DiamondFacetOne.alpha.selector);
        assertTrue(
            loupe.facetAddress(DiamondFacetOne.alpha.selector) == address(facetTwo), "alpha should move to facet two"
        );

        bytes4[] memory facetOneSelectorsAfterReplace = loupe.facetFunctionSelectors(address(facetOne));
        assertTrue(facetOneSelectorsAfterReplace.length == 1, "facet one selector count after replace mismatch");
        assertTrue(facetOneSelectorsAfterReplace[0] == DiamondFacetOne.beta.selector, "beta should remain on facet one");

        diamond.removeSelector(DiamondFacetOne.alpha.selector);
        assertTrue(loupe.facetAddress(DiamondFacetOne.alpha.selector) == address(0), "alpha should be removed");

        bytes4[] memory facetTwoSelectorsAfterRemove = loupe.facetFunctionSelectors(address(facetTwo));
        assertTrue(facetTwoSelectorsAfterRemove.length == 1, "facet two selector count after remove mismatch");
        assertTrue(
            facetTwoSelectorsAfterRemove[0] == DiamondFacetTwo.gamma.selector, "gamma should remain on facet two"
        );
    }

    function _installLoupeSelectors() internal {
        diamond.installSelector(address(loupeFacet), DiamondLoupeFacet.facets.selector);
        diamond.installSelector(address(loupeFacet), DiamondLoupeFacet.facetFunctionSelectors.selector);
        diamond.installSelector(address(loupeFacet), DiamondLoupeFacet.facetAddresses.selector);
        diamond.installSelector(address(loupeFacet), DiamondLoupeFacet.facetAddress.selector);
        diamond.installSelector(address(loupeFacet), DiamondLoupeFacet.owner.selector);
        diamond.installSelector(address(loupeFacet), DiamondLoupeFacet.transferOwnership.selector);
    }
}
