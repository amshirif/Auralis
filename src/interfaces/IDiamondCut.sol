// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IDiamondCut
/// @notice EIP-2535 cut interface for adding, replacing, and removing selectors.
interface IDiamondCut {
    /// @notice Selector mutation action.
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    /// @notice Facet cut payload.
    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /// @notice Emitted when selectors are added, replaced, or removed.
    /// @param diamondCut The selector mutation payload.
    /// @param init The optional init target for post-cut initialization.
    /// @param initCalldata The optional init calldata executed after the cut.
    event DiamondCut(FacetCut[] diamondCut, address init, bytes initCalldata);

    /// @notice Applies selector mutations to the diamond.
    /// @param diamondCut The selector mutation payload.
    /// @param init The optional init target for post-cut initialization.
    /// @param initCalldata The optional init calldata executed after the cut.
    function diamondCut(FacetCut[] calldata diamondCut, address init, bytes calldata initCalldata) external;
}
