// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IDiamondLoupe} from "../../src/interfaces/IDiamondLoupe.sol";
import {LibDiamond} from "../../src/diamond/libraries/LibDiamond.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

contract DiamondFacetOne {
    function alpha() external pure returns (uint256) {
        return 1;
    }

    function beta() external pure returns (uint256) {
        return 2;
    }
}

contract DiamondFacetTwo {
    function gamma() external pure returns (uint256) {
        return 3;
    }

    function delta() external pure returns (uint256) {
        return 4;
    }
}

contract DiamondLibraryHarness {
    function owner() external view returns (address) {
        return LibDiamond.contractOwner();
    }

    function setOwner(address newOwner) external {
        LibDiamond.setContractOwner(newOwner);
    }

    function enforceOwner() external view returns (bool) {
        LibDiamond.enforceIsContractOwner();
        return true;
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return LibDiamond.supportsInterface(interfaceId);
    }

    function setSupportedInterface(bytes4 interfaceId, bool supported) external {
        LibDiamond.setSupportedInterface(interfaceId, supported);
    }

    function addSelector(address facetAddress_, bytes4 selector) external {
        LibDiamond.addSelector(facetAddress_, selector);
    }

    function replaceSelector(address facetAddress_, bytes4 selector) external {
        LibDiamond.replaceSelector(facetAddress_, selector);
    }

    function removeSelector(bytes4 selector) external {
        LibDiamond.removeSelector(selector);
    }

    function facetAddress(bytes4 selector) external view returns (address) {
        return LibDiamond.facetAddress(selector);
    }

    function facetAddresses() external view returns (address[] memory) {
        return LibDiamond.facetAddresses();
    }

    function facetFunctionSelectors(address facetAddress_) external view returns (bytes4[] memory) {
        return LibDiamond.facetFunctionSelectors(facetAddress_);
    }

    function facets() external view returns (IDiamondLoupe.Facet[] memory) {
        return LibDiamond.facets();
    }
}

abstract contract DiamondFixture is TestBase {
    address internal admin = address(0xA11CE);
    address internal eve = address(0xE11E);

    DiamondLibraryHarness internal diamond;
    DiamondFacetOne internal facetOne;
    DiamondFacetTwo internal facetTwo;

    function setUp() public virtual {
        diamond = new DiamondLibraryHarness();
        facetOne = new DiamondFacetOne();
        facetTwo = new DiamondFacetTwo();
    }
}
