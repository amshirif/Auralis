// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC721} from "./IERC721.sol";

/// @title IERC721Metadata
/// @notice ERC-721 metadata extension interface.
interface IERC721Metadata is IERC721 {
    /// @notice Returns token collection name.
    /// @return The collection name.
    function name() external view returns (string memory);

    /// @notice Returns token collection symbol.
    /// @return The collection symbol.
    function symbol() external view returns (string memory);

    /// @notice Returns the metadata URI for `tokenId`.
    /// @param tokenId The token identifier.
    /// @return The token metadata URI.
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
