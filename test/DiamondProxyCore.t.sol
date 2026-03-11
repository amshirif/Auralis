// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Diamond} from "../src/diamond/Diamond.sol";
import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {LibDiamond} from "../src/diamond/libraries/LibDiamond.sol";
import {DiamondFacetOne, DiamondFacetTwo, DiamondProxyHarness, TestBase} from "./helpers/DiamondTestHarness.sol";

contract DiamondProxyCoreTest is TestBase {
    address internal admin = address(0xA11CE);
    address internal eve = address(0xE11E);

    DiamondProxyHarness internal diamond;
    DiamondCutFacet internal cutFacet;
    DiamondFacetOne internal facetOne;
    DiamondFacetTwo internal facetTwo;

    function setUp() public {
        cutFacet = new DiamondCutFacet();
        diamond = new DiamondProxyHarness(admin, address(cutFacet));
        facetOne = new DiamondFacetOne();
        facetTwo = new DiamondFacetTwo();
    }

    function testConstructorBootstrapsOwner() public view {
        assertTrue(diamond.owner() == admin, "initial owner mismatch");
    }

    function testConstructorBootstrapsInitialCutFacet() public {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = DiamondFacetOne.alpha.selector;
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetOne), action: IDiamondCut.FacetCutAction.Add, functionSelectors: selectors
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

        (bool success, bytes memory returndata) = address(diamond).call(abi.encodeCall(DiamondFacetOne.alpha, ()));
        assertTrue(success, "alpha call should succeed after constructor bootstrap");
        assertTrue(abi.decode(returndata, (uint256)) == 1, "alpha return mismatch after constructor bootstrap");
    }

    function testConstructorRejectsInitialCutFacetWithoutCode() public {
        VM.expectRevert(abi.encodeWithSelector(LibDiamond.DiamondTargetHasNoCode.selector, eve));
        new DiamondProxyHarness(admin, eve);
    }

    function testFallbackRoutesSelectorToInstalledFacet() public {
        diamond.installSelector(address(facetOne), DiamondFacetOne.alpha.selector);

        (bool success, bytes memory returndata) = address(diamond).call(abi.encodeCall(DiamondFacetOne.alpha, ()));

        assertTrue(success, "alpha call should succeed");
        assertTrue(abi.decode(returndata, (uint256)) == 1, "alpha return mismatch");
    }

    function testFallbackRoutesMultipleFacetSelectors() public {
        diamond.installSelector(address(facetOne), DiamondFacetOne.alpha.selector);
        diamond.installSelector(address(facetTwo), DiamondFacetTwo.gamma.selector);

        (bool alphaSuccess, bytes memory alphaReturndata) =
            address(diamond).call(abi.encodeCall(DiamondFacetOne.alpha, ()));
        (bool gammaSuccess, bytes memory gammaReturndata) =
            address(diamond).call(abi.encodeCall(DiamondFacetTwo.gamma, ()));

        assertTrue(alphaSuccess, "alpha call should succeed");
        assertTrue(gammaSuccess, "gamma call should succeed");
        assertTrue(abi.decode(alphaReturndata, (uint256)) == 1, "alpha return mismatch");
        assertTrue(abi.decode(gammaReturndata, (uint256)) == 3, "gamma return mismatch");
    }

    function testDelegatecallPreservesOriginalCaller() public {
        diamond.installSelector(address(facetOne), DiamondFacetOne.caller.selector);

        VM.prank(eve);
        (bool success, bytes memory returndata) = address(diamond).call(abi.encodeCall(DiamondFacetOne.caller, ()));

        assertTrue(success, "caller call should succeed");
        assertTrue(abi.decode(returndata, (address)) == eve, "delegated caller mismatch");
    }

    function testUnknownSelectorRevertsCleanly() public {
        (bool success, bytes memory returndata) = address(diamond).call(hex"deadbeef");

        assertFalse(success, "unknown selector call should fail");
        assertTrue(
            keccak256(returndata)
                == keccak256(abi.encodeWithSelector(Diamond.DiamondFunctionNotFound.selector, bytes4(0xdeadbeef))),
            "unknown selector revert mismatch"
        );
    }
}
