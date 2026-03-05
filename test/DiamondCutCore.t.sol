// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Diamond} from "../src/diamond/Diamond.sol";
import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {LibDiamond} from "../src/diamond/libraries/LibDiamond.sol";
import {
    DiamondFacetOne,
    DiamondFacetReplacement,
    DiamondInitMock,
    DiamondProxyHarness,
    TestBase
} from "./helpers/DiamondTestHarness.sol";

contract DiamondCutCoreTest is TestBase {
    event DiamondCut(IDiamondCut.FacetCut[] diamondCut, address init, bytes initCalldata);

    address internal admin = address(0xA11CE);
    address internal eve = address(0xE11E);

    DiamondProxyHarness internal diamond;
    DiamondCutFacet internal cutFacet;
    DiamondFacetOne internal facetOne;
    DiamondFacetReplacement internal facetReplacement;
    DiamondInitMock internal initMock;

    function setUp() public {
        diamond = new DiamondProxyHarness(admin);
        cutFacet = new DiamondCutFacet();
        facetOne = new DiamondFacetOne();
        facetReplacement = new DiamondFacetReplacement();
        initMock = new DiamondInitMock();

        diamond.installSelector(address(cutFacet), DiamondCutFacet.diamondCut.selector);
    }

    function testOwnerCanAddSelectorViaDiamondCut() public {
        IDiamondCut.FacetCut[] memory cut =
            _buildSingleCut(address(facetOne), IDiamondCut.FacetCutAction.Add, DiamondFacetOne.version.selector);

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

        (bool success, bytes memory returndata) = address(diamond).call(abi.encodeCall(DiamondFacetOne.version, ()));
        assertTrue(success, "version call should succeed");
        assertTrue(abi.decode(returndata, (uint256)) == 1, "version should route to facet one");
    }

    function testDiamondCutEmitsEvent() public {
        IDiamondCut.FacetCut[] memory cut =
            _buildSingleCut(address(facetOne), IDiamondCut.FacetCutAction.Add, DiamondFacetOne.version.selector);

        VM.expectEmit(false, false, false, true, address(diamond));
        emit DiamondCut(cut, address(0), "");

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function testNonOwnerCannotDiamondCut() public {
        IDiamondCut.FacetCut[] memory cut =
            _buildSingleCut(address(facetOne), IDiamondCut.FacetCutAction.Add, DiamondFacetOne.version.selector);

        VM.prank(eve);
        VM.expectRevert(abi.encodeWithSelector(LibDiamond.DiamondUnauthorized.selector, eve, admin));
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function testReplaceSelectorViaDiamondCut() public {
        IDiamondCut.FacetCut[] memory addCut =
            _buildSingleCut(address(facetOne), IDiamondCut.FacetCutAction.Add, DiamondFacetOne.version.selector);
        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(addCut, address(0), "");

        IDiamondCut.FacetCut[] memory replaceCut = _buildSingleCut(
            address(facetReplacement), IDiamondCut.FacetCutAction.Replace, DiamondFacetReplacement.version.selector
        );
        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(replaceCut, address(0), "");

        (bool success, bytes memory returndata) = address(diamond).call(abi.encodeCall(DiamondFacetOne.version, ()));
        assertTrue(success, "replaced selector call should succeed");
        assertTrue(abi.decode(returndata, (uint256)) == 2, "version should route to replacement facet");
    }

    function testRemoveSelectorViaDiamondCut() public {
        IDiamondCut.FacetCut[] memory addCut =
            _buildSingleCut(address(facetOne), IDiamondCut.FacetCutAction.Add, DiamondFacetOne.version.selector);
        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(addCut, address(0), "");

        IDiamondCut.FacetCut[] memory removeCut =
            _buildSingleCut(address(0), IDiamondCut.FacetCutAction.Remove, DiamondFacetOne.version.selector);
        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(removeCut, address(0), "");

        (bool success, bytes memory returndata) = address(diamond).call(abi.encodeCall(DiamondFacetOne.version, ()));
        assertFalse(success, "removed selector call should fail");
        assertTrue(
            keccak256(returndata)
                == keccak256(
                    abi.encodeWithSelector(Diamond.DiamondFunctionNotFound.selector, DiamondFacetOne.version.selector)
                ),
            "removed selector revert mismatch"
        );
    }

    function testInitDelegatecallRunsAfterCut() public {
        IDiamondCut.FacetCut[] memory cut =
            _buildSingleCut(address(initMock), IDiamondCut.FacetCutAction.Add, DiamondInitMock.readValue.selector);

        VM.prank(admin);
        IDiamondCut(address(diamond))
            .diamondCut(cut, address(initMock), abi.encodeCall(DiamondInitMock.initializeValue, (42)));

        (bool success, bytes memory returndata) = address(diamond).call(abi.encodeCall(DiamondInitMock.readValue, ()));
        assertTrue(success, "readValue call should succeed");
        assertTrue(abi.decode(returndata, (uint256)) == 42, "init delegatecall value mismatch");
    }

    function testCutRejectsTargetWithoutCode() public {
        IDiamondCut.FacetCut[] memory cut =
            _buildSingleCut(eve, IDiamondCut.FacetCutAction.Add, DiamondFacetOne.version.selector);

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(LibDiamond.DiamondTargetHasNoCode.selector, eve));
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function testCutRejectsRemoveWithNonZeroFacetAddress() public {
        IDiamondCut.FacetCut[] memory cut =
            _buildSingleCut(address(facetOne), IDiamondCut.FacetCutAction.Remove, DiamondFacetOne.version.selector);

        VM.prank(admin);
        VM.expectRevert(
            abi.encodeWithSelector(LibDiamond.DiamondCutRemoveFacetAddressNotZero.selector, address(facetOne))
        );
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function testCutRejectsInitCalldataWithoutTarget() public {
        IDiamondCut.FacetCut[] memory cut =
            _buildSingleCut(address(facetOne), IDiamondCut.FacetCutAction.Add, DiamondFacetOne.version.selector);

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(LibDiamond.DiamondCutInitTargetRequired.selector));
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), abi.encodeCall(DiamondInitMock.initializeValue, (1)));
    }

    function testCutRejectsInitTargetWithoutCalldata() public {
        IDiamondCut.FacetCut[] memory cut =
            _buildSingleCut(address(facetOne), IDiamondCut.FacetCutAction.Add, DiamondFacetOne.version.selector);

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(LibDiamond.DiamondCutInitCalldataRequired.selector));
        IDiamondCut(address(diamond)).diamondCut(cut, address(initMock), "");
    }

    function testCutBubblesInitFailure() public {
        IDiamondCut.FacetCut[] memory cut =
            _buildSingleCut(address(facetOne), IDiamondCut.FacetCutAction.Add, DiamondFacetOne.version.selector);
        bytes memory initCalldata = abi.encodeCall(DiamondInitMock.revertInit, ());
        bytes memory revertReason = abi.encodeWithSelector(DiamondInitMock.InitFailure.selector);

        VM.prank(admin);
        VM.expectRevert(
            abi.encodeWithSelector(LibDiamond.DiamondCutInitFailed.selector, address(initMock), revertReason)
        );
        IDiamondCut(address(diamond)).diamondCut(cut, address(initMock), initCalldata);
    }

    function testCutRejectsEmptySelectorList() public {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetOne), action: IDiamondCut.FacetCutAction.Add, functionSelectors: new bytes4[](0)
        });

        VM.prank(admin);
        VM.expectRevert(abi.encodeWithSelector(LibDiamond.DiamondCutEmptySelectors.selector));
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function _buildSingleCut(address facetAddress, IDiamondCut.FacetCutAction action, bytes4 selector)
        internal
        pure
        returns (IDiamondCut.FacetCut[] memory cut)
    {
        cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = selector;
        cut[0] = IDiamondCut.FacetCut({facetAddress: facetAddress, action: action, functionSelectors: selectors});
    }
}
