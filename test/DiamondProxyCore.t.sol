// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Diamond} from "../src/diamond/Diamond.sol";
import {DiamondFacetOne, DiamondFacetTwo, DiamondProxyHarness, TestBase} from "./helpers/DiamondTestHarness.sol";

contract DiamondProxyCoreTest is TestBase {
    address internal admin = address(0xA11CE);
    address internal eve = address(0xE11E);

    DiamondProxyHarness internal diamond;
    DiamondFacetOne internal facetOne;
    DiamondFacetTwo internal facetTwo;

    function setUp() public {
        diamond = new DiamondProxyHarness(admin);
        facetOne = new DiamondFacetOne();
        facetTwo = new DiamondFacetTwo();
    }

    function testConstructorBootstrapsOwner() public view {
        assertTrue(diamond.owner() == admin, "initial owner mismatch");
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
