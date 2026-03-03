// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {LibDiamond} from "../src/diamond/libraries/LibDiamond.sol";
import {DiamondFixture, DiamondFacetOne, DiamondFacetTwo} from "./helpers/DiamondTestHarness.sol";

contract DiamondFoundationCoreTest is DiamondFixture {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function testOwnerCanBeSetAndRead() public {
        diamond.setOwner(admin);
        assertTrue(diamond.owner() == admin, "owner should be updated");
    }

    function testOwnerTransferEmitsEvent() public {
        VM.expectEmit(true, true, false, true, address(diamond));
        emit OwnershipTransferred(address(0), admin);

        diamond.setOwner(admin);
    }

    function testOwnerZeroAddressReverts() public {
        VM.expectRevert(abi.encodeWithSelector(LibDiamond.DiamondOwnerZeroAddress.selector));
        diamond.setOwner(address(0));
    }

    function testOwnerEnforcementRevertsForNonOwner() public {
        diamond.setOwner(admin);

        VM.prank(eve);
        VM.expectRevert(abi.encodeWithSelector(LibDiamond.DiamondUnauthorized.selector, eve, admin));
        diamond.enforceOwner();
    }

    function testSupportedInterfaceRoundTrip() public {
        bytes4 interfaceId = 0x1f931c1c;
        diamond.setSupportedInterface(interfaceId, true);
        assertTrue(diamond.supportsInterface(interfaceId), "interface support should be enabled");

        diamond.setSupportedInterface(interfaceId, false);
        assertFalse(diamond.supportsInterface(interfaceId), "interface support should be disabled");
    }

    function testInvalidInterfaceIdReverts() public {
        VM.expectRevert(abi.encodeWithSelector(LibDiamond.DiamondInvalidInterfaceId.selector, bytes4(0xffffffff)));
        diamond.setSupportedInterface(0xffffffff, true);
    }

    function testAddSelectorTracksFacetAndSelectors() public {
        bytes4 alphaSelector = DiamondFacetOne.alpha.selector;
        bytes4 betaSelector = DiamondFacetOne.beta.selector;

        diamond.addSelector(address(facetOne), alphaSelector);
        diamond.addSelector(address(facetOne), betaSelector);

        assertTrue(diamond.facetAddress(alphaSelector) == address(facetOne), "alpha selector should route to facet one");
        assertTrue(diamond.facetAddress(betaSelector) == address(facetOne), "beta selector should route to facet one");

        address[] memory facetAddresses_ = diamond.facetAddresses();
        assertTrue(facetAddresses_.length == 1, "one facet address expected");
        assertTrue(facetAddresses_[0] == address(facetOne), "facet one should be registered");

        bytes4[] memory selectors = diamond.facetFunctionSelectors(address(facetOne));
        assertTrue(selectors.length == 2, "facet one should have two selectors");
        assertTrue(selectors[0] == alphaSelector, "alpha selector order mismatch");
        assertTrue(selectors[1] == betaSelector, "beta selector order mismatch");
    }

    function testAddingExistingSelectorReverts() public {
        bytes4 alphaSelector = DiamondFacetOne.alpha.selector;
        diamond.addSelector(address(facetOne), alphaSelector);

        VM.expectRevert(
            abi.encodeWithSelector(LibDiamond.DiamondSelectorAlreadyExists.selector, alphaSelector, address(facetOne))
        );
        diamond.addSelector(address(facetTwo), alphaSelector);
    }

    function testReplaceSelectorMovesRoutingToNewFacet() public {
        bytes4 alphaSelector = DiamondFacetOne.alpha.selector;
        diamond.addSelector(address(facetOne), alphaSelector);

        diamond.replaceSelector(address(facetTwo), alphaSelector);

        assertTrue(diamond.facetAddress(alphaSelector) == address(facetTwo), "selector should route to facet two");
        assertTrue(diamond.facetFunctionSelectors(address(facetOne)).length == 0, "facet one selectors should be empty");

        bytes4[] memory facetTwoSelectors = diamond.facetFunctionSelectors(address(facetTwo));
        assertTrue(facetTwoSelectors.length == 1, "facet two should own one selector");
        assertTrue(facetTwoSelectors[0] == alphaSelector, "facet two selector mismatch");
    }

    function testReplacingSelectorWithSameFacetReverts() public {
        bytes4 alphaSelector = DiamondFacetOne.alpha.selector;
        diamond.addSelector(address(facetOne), alphaSelector);

        VM.expectRevert(
            abi.encodeWithSelector(LibDiamond.DiamondReplaceWithSameFacet.selector, alphaSelector, address(facetOne))
        );
        diamond.replaceSelector(address(facetOne), alphaSelector);
    }

    function testRemoveSelectorCleansUpFacetAddressList() public {
        bytes4 alphaSelector = DiamondFacetOne.alpha.selector;
        bytes4 gammaSelector = DiamondFacetTwo.gamma.selector;

        diamond.addSelector(address(facetOne), alphaSelector);
        diamond.addSelector(address(facetTwo), gammaSelector);
        diamond.removeSelector(alphaSelector);

        assertTrue(diamond.facetAddress(alphaSelector) == address(0), "removed selector should not resolve");
        address[] memory facetAddresses_ = diamond.facetAddresses();
        assertTrue(facetAddresses_.length == 1, "one facet should remain");
        assertTrue(facetAddresses_[0] == address(facetTwo), "facet two should remain active");
    }

    function testRemoveUnknownSelectorReverts() public {
        VM.expectRevert(
            abi.encodeWithSelector(LibDiamond.DiamondSelectorNotFound.selector, DiamondFacetOne.alpha.selector)
        );
        diamond.removeSelector(DiamondFacetOne.alpha.selector);
    }

    function testFacetsViewReturnsCurrentLayout() public {
        bytes4 alphaSelector = DiamondFacetOne.alpha.selector;
        bytes4 betaSelector = DiamondFacetOne.beta.selector;
        bytes4 gammaSelector = DiamondFacetTwo.gamma.selector;

        diamond.addSelector(address(facetOne), alphaSelector);
        diamond.addSelector(address(facetOne), betaSelector);
        diamond.addSelector(address(facetTwo), gammaSelector);

        IDiamondLoupe.Facet[] memory diamondFacets = diamond.facets();
        assertTrue(diamondFacets.length == 2, "two facets expected");

        assertTrue(diamondFacets[0].facetAddress == address(facetOne), "facet one ordering mismatch");
        assertTrue(diamondFacets[0].functionSelectors.length == 2, "facet one selector count mismatch");
        assertTrue(diamondFacets[1].facetAddress == address(facetTwo), "facet two ordering mismatch");
        assertTrue(diamondFacets[1].functionSelectors.length == 1, "facet two selector count mismatch");
    }
}
