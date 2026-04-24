// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title LibERC721TokenStorage
/// @notice Diamond-safe storage layout for hosted ERC-721 facets.
library LibERC721TokenStorage {
    /// @dev Unique namespaced storage slot; do not reuse or rename without migration review.
    bytes32 internal constant STORAGE_SLOT = keccak256("auralis.token.erc721.storage");

    /// @notice ERC-721 token storage layout.
    struct Layout {
        bool initialized;
        string name;
        string symbol;
        string baseURI;
        uint256 totalSupply;
        mapping(uint256 => address) owners;
        mapping(address => uint256) balances;
        mapping(uint256 => address) tokenApprovals;
        mapping(address => mapping(address => bool)) operatorApprovals;
        // forge-lint: disable-next-line(mixed-case-variable) -- storage field name is frozen for layout compatibility.
        mapping(uint256 => string) tokenURIs;
    }

    /// @notice Returns the ERC-721 storage layout.
    /// @return l The storage layout pointer.
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
