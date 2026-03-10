// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IDiamondLoupe
/// @notice EIP-2535 loupe interface for facet and selector introspection.
interface IDiamondLoupe {
    /// @notice Facet metadata returned by loupe queries.
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /// @notice Returns every facet and its selectors.
    /// @return diamondFacets All active facets and their selectors.
    function facets() external view returns (Facet[] memory diamondFacets);

    /// @notice Returns all selectors owned by `facetAddress`.
    /// @param facetAddress The facet address to inspect.
    /// @return functionSelectors The selectors owned by the facet.
    function facetFunctionSelectors(address facetAddress) external view returns (bytes4[] memory functionSelectors);

    /// @notice Returns every active facet address.
    /// @return facetAddresses All active facet addresses.
    function facetAddresses() external view returns (address[] memory facetAddresses);

    /// @notice Returns the facet responsible for `functionSelector`.
    /// @param functionSelector The selector to inspect.
    /// @return facetAddress The owning facet address, or zero when unset.
    function facetAddress(bytes4 functionSelector) external view returns (address facetAddress);
}
