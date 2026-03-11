// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Diamond} from "../src/diamond/Diamond.sol";
import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {LibDiamond} from "../src/diamond/libraries/LibDiamond.sol";
import {
    DiamondFacetAlphaReplacement,
    DiamondFacetOne,
    DiamondFacetTwo,
    DiamondProxyHarness,
    TestBase
} from "./helpers/DiamondTestHarness.sol";

contract DiamondSelectorIntegrityCoreTest is TestBase {
    address internal admin = address(0xA11CE);
    address internal eve = address(0xE11E);

    DiamondProxyHarness internal diamond;
    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal loupeFacet;
    DiamondFacetOne internal facetOne;
    DiamondFacetTwo internal facetTwo;
    DiamondFacetAlphaReplacement internal alphaReplacement;

    function setUp() public {
        cutFacet = new DiamondCutFacet();
        diamond = new DiamondProxyHarness(admin, address(cutFacet));
        loupeFacet = new DiamondLoupeFacet();
        facetOne = new DiamondFacetOne();
        facetTwo = new DiamondFacetTwo();
        alphaReplacement = new DiamondFacetAlphaReplacement();

        _bootstrapCoreFacets();
    }

    function testMultiFacetCutRoutesExternalCallsAndLoupeQueries() public {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](2);
        cut[0] = _buildCut(address(facetOne), IDiamondCut.FacetCutAction.Add, _facetOneSelectors());
        cut[1] = _buildCut(address(facetTwo), IDiamondCut.FacetCutAction.Add, _facetTwoSelectors());

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

        _assertCallReturnsUint256(abi.encodeCall(DiamondFacetOne.alpha, ()), 1, "alpha routing mismatch");
        _assertCallReturnsUint256(abi.encodeCall(DiamondFacetOne.beta, ()), 2, "beta routing mismatch");
        _assertCallReturnsUint256(abi.encodeCall(DiamondFacetTwo.gamma, ()), 3, "gamma routing mismatch");
        _assertCallReturnsUint256(abi.encodeCall(DiamondFacetTwo.delta, ()), 4, "delta routing mismatch");

        VM.prank(eve);
        (bool success, bytes memory returndata) = address(diamond).call(abi.encodeCall(DiamondFacetOne.caller, ()));
        assertTrue(success, "caller routing should succeed");
        assertTrue(abi.decode(returndata, (address)) == eve, "caller routing should preserve msg.sender");

        IDiamondLoupe loupe = IDiamondLoupe(address(diamond));
        bytes4[] memory facetOneSelectors = loupe.facetFunctionSelectors(address(facetOne));
        bytes4[] memory facetTwoSelectors = loupe.facetFunctionSelectors(address(facetTwo));

        assertTrue(facetOneSelectors.length == 3, "facet one selector count mismatch");
        assertTrue(_containsSelector(facetOneSelectors, DiamondFacetOne.alpha.selector), "facet one missing alpha");
        assertTrue(_containsSelector(facetOneSelectors, DiamondFacetOne.beta.selector), "facet one missing beta");
        assertTrue(_containsSelector(facetOneSelectors, DiamondFacetOne.caller.selector), "facet one missing caller");

        assertTrue(facetTwoSelectors.length == 2, "facet two selector count mismatch");
        assertTrue(_containsSelector(facetTwoSelectors, DiamondFacetTwo.gamma.selector), "facet two missing gamma");
        assertTrue(_containsSelector(facetTwoSelectors, DiamondFacetTwo.delta.selector), "facet two missing delta");
    }

    function testSelectorCollisionRevertsAtomically() public {
        IDiamondCut.FacetCut[] memory installCut = new IDiamondCut.FacetCut[](1);
        installCut[0] = _buildCut(
            address(facetOne), IDiamondCut.FacetCutAction.Add, _singleSelector(DiamondFacetOne.alpha.selector)
        );

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(installCut, address(0), "");

        IDiamondCut.FacetCut[] memory collisionCut = new IDiamondCut.FacetCut[](2);
        collisionCut[0] = _buildCut(
            address(facetTwo), IDiamondCut.FacetCutAction.Add, _singleSelector(DiamondFacetTwo.delta.selector)
        );
        collisionCut[1] = _buildCut(
            address(alphaReplacement),
            IDiamondCut.FacetCutAction.Add,
            _singleSelector(DiamondFacetAlphaReplacement.alpha.selector)
        );

        VM.prank(admin);
        VM.expectRevert(
            abi.encodeWithSelector(
                LibDiamond.DiamondSelectorAlreadyExists.selector,
                DiamondFacetAlphaReplacement.alpha.selector,
                address(facetOne)
            )
        );
        IDiamondCut(address(diamond)).diamondCut(collisionCut, address(0), "");

        IDiamondLoupe loupe = IDiamondLoupe(address(diamond));
        assertTrue(
            loupe.facetAddress(DiamondFacetOne.alpha.selector) == address(facetOne),
            "existing alpha route should remain unchanged"
        );
        assertTrue(
            loupe.facetAddress(DiamondFacetTwo.delta.selector) == address(0),
            "delta should not be partially installed after revert"
        );
        _assertSelectorMissing(DiamondFacetTwo.delta.selector, abi.encodeCall(DiamondFacetTwo.delta, ()));
    }

    function testUpgradeDiffUpdatesRoutingBeforeAndAfterCuts() public {
        IDiamondCut.FacetCut[] memory initialCut = new IDiamondCut.FacetCut[](2);
        initialCut[0] = _buildCut(
            address(facetOne),
            IDiamondCut.FacetCutAction.Add,
            _selectors(DiamondFacetOne.alpha.selector, DiamondFacetOne.beta.selector)
        );
        initialCut[1] = _buildCut(
            address(facetTwo), IDiamondCut.FacetCutAction.Add, _singleSelector(DiamondFacetTwo.gamma.selector)
        );

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(initialCut, address(0), "");

        _assertCallReturnsUint256(abi.encodeCall(DiamondFacetOne.alpha, ()), 1, "alpha should route to facet one");
        _assertCallReturnsUint256(abi.encodeCall(DiamondFacetOne.beta, ()), 2, "beta should route to facet one");
        _assertCallReturnsUint256(abi.encodeCall(DiamondFacetTwo.gamma, ()), 3, "gamma should route to facet two");

        IDiamondCut.FacetCut[] memory upgradeCut = new IDiamondCut.FacetCut[](3);
        upgradeCut[0] = _buildCut(
            address(alphaReplacement),
            IDiamondCut.FacetCutAction.Replace,
            _singleSelector(DiamondFacetOne.alpha.selector)
        );
        upgradeCut[1] =
            _buildCut(address(0), IDiamondCut.FacetCutAction.Remove, _singleSelector(DiamondFacetOne.beta.selector));
        upgradeCut[2] = _buildCut(
            address(alphaReplacement),
            IDiamondCut.FacetCutAction.Add,
            _singleSelector(DiamondFacetAlphaReplacement.epsilon.selector)
        );

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(upgradeCut, address(0), "");

        _assertCallReturnsUint256(
            abi.encodeCall(DiamondFacetAlphaReplacement.alpha, ()), 11, "alpha should route to replacement facet"
        );
        _assertCallReturnsUint256(abi.encodeCall(DiamondFacetTwo.gamma, ()), 3, "gamma should remain unchanged");
        _assertCallReturnsUint256(
            abi.encodeCall(DiamondFacetAlphaReplacement.epsilon, ()), 5, "epsilon should route to replacement facet"
        );
        _assertSelectorMissing(DiamondFacetOne.beta.selector, abi.encodeCall(DiamondFacetOne.beta, ()));
    }

    function testLoupeReflectsFreshStateAfterUpgradeDiff() public {
        IDiamondCut.FacetCut[] memory initialCut = new IDiamondCut.FacetCut[](1);
        initialCut[0] = _buildCut(address(facetOne), IDiamondCut.FacetCutAction.Add, _facetOneSelectors());

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(initialCut, address(0), "");

        IDiamondLoupe loupe = IDiamondLoupe(address(diamond));
        bytes4[] memory initialSelectors = loupe.facetFunctionSelectors(address(facetOne));
        assertTrue(initialSelectors.length == 3, "initial selector count mismatch");

        IDiamondCut.FacetCut[] memory upgradeCut = new IDiamondCut.FacetCut[](3);
        upgradeCut[0] = _buildCut(
            address(alphaReplacement),
            IDiamondCut.FacetCutAction.Replace,
            _singleSelector(DiamondFacetOne.alpha.selector)
        );
        upgradeCut[1] = _buildCut(
            address(0),
            IDiamondCut.FacetCutAction.Remove,
            _selectors(DiamondFacetOne.beta.selector, DiamondFacetOne.caller.selector)
        );
        upgradeCut[2] = _buildCut(
            address(alphaReplacement),
            IDiamondCut.FacetCutAction.Add,
            _selectors(DiamondFacetAlphaReplacement.epsilon.selector, DiamondFacetOne.caller.selector)
        );

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(upgradeCut, address(0), "");

        bytes4[] memory refreshedOldFacetSelectors = loupe.facetFunctionSelectors(address(facetOne));
        bytes4[] memory refreshedReplacementSelectors = loupe.facetFunctionSelectors(address(alphaReplacement));

        assertTrue(refreshedOldFacetSelectors.length == 0, "facet one should no longer own selectors");
        assertTrue(refreshedReplacementSelectors.length == 3, "replacement facet selector count mismatch");
        assertTrue(
            _containsSelector(refreshedReplacementSelectors, DiamondFacetAlphaReplacement.alpha.selector),
            "replacement facet missing alpha"
        );
        assertTrue(
            _containsSelector(refreshedReplacementSelectors, DiamondFacetAlphaReplacement.epsilon.selector),
            "replacement facet missing epsilon"
        );
        assertTrue(
            _containsSelector(refreshedReplacementSelectors, DiamondFacetOne.caller.selector),
            "replacement facet missing caller"
        );
        assertTrue(
            loupe.facetAddress(DiamondFacetOne.alpha.selector) == address(alphaReplacement),
            "loupe should point alpha to replacement facet"
        );
        assertTrue(
            loupe.facetAddress(DiamondFacetOne.beta.selector) == address(0), "loupe should report removed beta as unset"
        );
    }

    function _bootstrapCoreFacets() internal {
        diamond.installSelector(address(loupeFacet), DiamondLoupeFacet.facets.selector);
        diamond.installSelector(address(loupeFacet), DiamondLoupeFacet.facetFunctionSelectors.selector);
        diamond.installSelector(address(loupeFacet), DiamondLoupeFacet.facetAddresses.selector);
        diamond.installSelector(address(loupeFacet), DiamondLoupeFacet.facetAddress.selector);
        diamond.installSelector(address(loupeFacet), DiamondLoupeFacet.owner.selector);
        diamond.installSelector(address(loupeFacet), DiamondLoupeFacet.transferOwnership.selector);
    }

    function _buildCut(address facetAddress, IDiamondCut.FacetCutAction action, bytes4[] memory selectors)
        internal
        pure
        returns (IDiamondCut.FacetCut memory)
    {
        return IDiamondCut.FacetCut({facetAddress: facetAddress, action: action, functionSelectors: selectors});
    }

    function _facetOneSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](3);
        selectors[0] = DiamondFacetOne.alpha.selector;
        selectors[1] = DiamondFacetOne.beta.selector;
        selectors[2] = DiamondFacetOne.caller.selector;
    }

    function _facetTwoSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](2);
        selectors[0] = DiamondFacetTwo.gamma.selector;
        selectors[1] = DiamondFacetTwo.delta.selector;
    }

    function _singleSelector(bytes4 selector) internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](1);
        selectors[0] = selector;
    }

    function _selectors(bytes4 first, bytes4 second) internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](2);
        selectors[0] = first;
        selectors[1] = second;
    }

    function _assertCallReturnsUint256(bytes memory callData, uint256 expectedValue, string memory message) internal {
        (bool success, bytes memory returndata) = address(diamond).call(callData);
        assertTrue(success, message);
        assertTrue(abi.decode(returndata, (uint256)) == expectedValue, message);
    }

    function _assertSelectorMissing(bytes4 selector, bytes memory callData) internal {
        (bool success, bytes memory returndata) = address(diamond).call(callData);
        assertFalse(success, "missing selector call should revert");
        assertTrue(
            keccak256(returndata)
                == keccak256(abi.encodeWithSelector(Diamond.DiamondFunctionNotFound.selector, selector)),
            "missing selector revert mismatch"
        );
    }

    function _containsSelector(bytes4[] memory selectors, bytes4 selector) internal pure returns (bool) {
        for (uint256 i = 0; i < selectors.length; i++) {
            if (selectors[i] == selector) {
                return true;
            }
        }
        return false;
    }
}
