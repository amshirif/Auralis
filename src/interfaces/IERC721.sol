// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "./IERC165.sol";

/// @title IERC721
/// @notice ERC-721 non-fungible token standard interface.
interface IERC721 is IERC165 {
    /// @notice Emitted when `tokenId` transfers from `from` to `to`.
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /// @notice Emitted when `owner` approves `approved` for `tokenId`.
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /// @notice Emitted when `owner` enables or disables `operator`.
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /// @notice Returns the token count owned by `owner`.
    /// @param owner The account to query.
    /// @return The balance for `owner`.
    function balanceOf(address owner) external view returns (uint256);

    /// @notice Returns the owner of `tokenId`.
    /// @param tokenId The token identifier.
    /// @return The token owner.
    function ownerOf(uint256 tokenId) external view returns (address);

    /// @notice Safely transfers `tokenId` from `from` to `to`.
    /// @param from The current owner.
    /// @param to The receiver.
    /// @param tokenId The token identifier.
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /// @notice Transfers `tokenId` from `from` to `to`.
    /// @param from The current owner.
    /// @param to The receiver.
    /// @param tokenId The token identifier.
    function transferFrom(address from, address to, uint256 tokenId) external;

    /// @notice Approves `to` to manage `tokenId`.
    /// @param to Approved account.
    /// @param tokenId The token identifier.
    function approve(address to, uint256 tokenId) external;

    /// @notice Enables or disables `operator` for caller-owned tokens.
    /// @param operator The operator account.
    /// @param approved True to approve, false to revoke.
    function setApprovalForAll(address operator, bool approved) external;

    /// @notice Returns the approved account for `tokenId`.
    /// @param tokenId The token identifier.
    /// @return The approved account, or zero if none.
    function getApproved(uint256 tokenId) external view returns (address);

    /// @notice Returns whether `operator` is approved for all of `owner`'s tokens.
    /// @param owner Token owner.
    /// @param operator Operator account.
    /// @return True if approved.
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /// @notice Safely transfers `tokenId` from `from` to `to` with `data`.
    /// @param from The current owner.
    /// @param to The receiver.
    /// @param tokenId The token identifier.
    /// @param data Additional receiver data.
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}
