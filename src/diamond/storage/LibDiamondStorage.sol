// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title LibDiamondStorage
/// @notice Diamond storage layout for selector routing, facet metadata, and ownership.
library LibDiamondStorage {
    /// @dev Storage slot for the diamond layout.
    bytes32 internal constant STORAGE_SLOT = keccak256("auralis.diamond.storage");

    /// @notice Selector routing metadata.
    struct SelectorData {
        address facetAddress;
        uint96 selectorPosition;
    }

    /// @notice Selector collection metadata for one facet.
    struct FacetData {
        bytes4[] selectors;
        uint256 facetAddressPosition;
    }

    /// @notice Full diamond storage layout.
    struct Layout {
        mapping(bytes4 => SelectorData) selectorData;
        mapping(address => FacetData) facetData;
        address[] facetAddresses;
        mapping(bytes4 => bool) supportedInterfaces;
        address contractOwner;
    }

    /// @notice Returns the storage layout for the diamond state.
    /// @return l The storage layout pointer.
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
