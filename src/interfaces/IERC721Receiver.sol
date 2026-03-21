// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IERC721Receiver
/// @notice Interface for contracts that can receive safe ERC-721 transfers.
interface IERC721Receiver {
    /// @notice Handles receipt of an ERC-721 token.
    /// @param operator The account that initiated the transfer.
    /// @param from The previous owner.
    /// @param tokenId The token identifier.
    /// @param data Additional transfer data.
    /// @return The selector to confirm receipt.
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}
