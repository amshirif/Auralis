// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC173} from "../../interfaces/IERC173.sol";
import {IDiamondLoupe} from "../../interfaces/IDiamondLoupe.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

/// @title DiamondLoupeFacet
/// @notice Facet metadata + ownership surface for EIP-2535 diamonds.
contract DiamondLoupeFacet is IDiamondLoupe, IERC173 {
    /// @notice Returns every facet and its selectors.
    /// @return diamondFacets All active facets and their selectors.
    function facets() external view returns (IDiamondLoupe.Facet[] memory diamondFacets) {
        return LibDiamond.facets();
    }

    /// @notice Returns all selectors owned by `facetAddress_`.
    /// @param facetAddress_ The facet address to inspect.
    /// @return functionSelectors The selectors owned by the facet.
    function facetFunctionSelectors(address facetAddress_) external view returns (bytes4[] memory functionSelectors) {
        return LibDiamond.facetFunctionSelectors(facetAddress_);
    }

    /// @notice Returns every active facet address.
    /// @return facetAddresses_ All active facet addresses.
    function facetAddresses() external view returns (address[] memory facetAddresses_) {
        return LibDiamond.facetAddresses();
    }

    /// @notice Returns the facet responsible for `functionSelector`.
    /// @param functionSelector The selector to inspect.
    /// @return facetAddress_ The owning facet address, or zero when unset.
    function facetAddress(bytes4 functionSelector) external view returns (address facetAddress_) {
        return LibDiamond.facetAddress(functionSelector);
    }

    /// @notice Returns the current owner.
    /// @return contractOwner The current owner.
    function owner() external view returns (address contractOwner) {
        return LibDiamond.contractOwner();
    }

    /// @notice Transfers ownership to `newOwner`.
    /// @param newOwner The new owner account.
    function transferOwnership(address newOwner) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(newOwner);
    }
}
