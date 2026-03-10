// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Diamond} from "../../src/diamond/Diamond.sol";
import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../../src/interfaces/IDiamondLoupe.sol";
import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {LibDiamond} from "../../src/diamond/libraries/LibDiamond.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

contract DiamondFacetOne {
    function alpha() external pure returns (uint256) {
        return 1;
    }

    function beta() external pure returns (uint256) {
        return 2;
    }

    function caller() external view returns (address) {
        return msg.sender;
    }

    function version() external pure returns (uint256) {
        return 1;
    }
}

contract DiamondFacetReplacement {
    function version() external pure returns (uint256) {
        return 2;
    }
}

contract DiamondFacetAlphaReplacement {
    function alpha() external pure returns (uint256) {
        return 11;
    }

    function epsilon() external pure returns (uint256) {
        return 5;
    }

    function caller() external view returns (address) {
        return msg.sender;
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

library LibDiamondInitTestStorage {
    bytes32 internal constant STORAGE_SLOT = keccak256("smart-contracts.test.diamond-init.storage");

    struct Layout {
        uint256 value;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

contract DiamondInitMock {
    error InitFailure();

    function initializeValue(uint256 value_) external {
        LibDiamondInitTestStorage.layout().value = value_;
    }

    function readValue() external view returns (uint256) {
        return LibDiamondInitTestStorage.layout().value;
    }

    function revertInit() external pure {
        revert InitFailure();
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

contract DiamondProxyHarness is Diamond {
    constructor(address initialOwner) Diamond(initialOwner) {}

    function owner() external view returns (address) {
        return LibDiamond.contractOwner();
    }

    function installSelector(address facetAddress_, bytes4 selector) external {
        LibDiamond.addSelector(facetAddress_, selector);
    }

    function replaceSelector(address facetAddress_, bytes4 selector) external {
        LibDiamond.replaceSelector(facetAddress_, selector);
    }

    function removeSelector(bytes4 selector) external {
        LibDiamond.removeSelector(selector);
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
