// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IDiamondCut} from "../../interfaces/IDiamondCut.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

/// @title DiamondCutFacet
/// @notice Owner-gated selector mutation facet for EIP-2535 diamonds.
contract DiamondCutFacet is IDiamondCut {
    /// @notice Applies selector mutations and optional init delegatecall.
    /// @param diamondCut_ The selector mutation payload.
    /// @param init The optional init target for post-cut initialization.
    /// @param initCalldata The optional init calldata executed after the cut.
    function diamondCut(IDiamondCut.FacetCut[] calldata diamondCut_, address init, bytes calldata initCalldata)
        external
    {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.diamondCut(diamondCut_, init, initCalldata);
        emit DiamondCut(diamondCut_, init, initCalldata);
    }
}
