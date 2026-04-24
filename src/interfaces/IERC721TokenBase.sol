// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC721Metadata} from "./IERC721Metadata.sol";

/// @title IERC721TokenBase
/// @notice Interface for shared ERC-721 token foundation helpers.
interface IERC721TokenBase is IERC721Metadata {
    /// @notice Thrown when the ERC-721 initializer runs more than once.
    error ERC721TokenAlreadyInitialized();
    /// @notice Thrown when mutating helpers run before initialization.
    error ERC721TokenNotInitialized();
    /// @notice Thrown when a required account is the zero address.
    error ERC721TokenZeroAddress();
    /// @notice Thrown when `owner` is invalid for the requested operation.
    /// @param owner Invalid owner.
    error ERC721TokenInvalidOwner(address owner);
    /// @notice Thrown when a token does not exist.
    /// @param tokenId Missing token identifier.
    error ERC721TokenNonexistentToken(uint256 tokenId);
    /// @notice Thrown when a mint targets an existing token.
    /// @param tokenId Existing token identifier.
    error ERC721TokenAlreadyMinted(uint256 tokenId);
    /// @notice Thrown when `from` is not the current owner of `tokenId`.
    /// @param from Supplied owner.
    /// @param tokenId Token identifier.
    /// @param actualOwner Current token owner.
    error ERC721TokenIncorrectOwner(address from, uint256 tokenId, address actualOwner);
    /// @notice Thrown when a receiver does not implement `IERC721Receiver`.
    /// @param receiver Unsafe receiver address.
    error ERC721TokenUnsafeReceiver(address receiver);
    /// @notice Thrown when `owner` tries to set themselves as operator.
    /// @param owner Token owner.
    /// @param operator Invalid operator.
    error ERC721TokenInvalidOperator(address owner, address operator);

    /// @notice Returns true when ERC-721 storage is initialized.
    /// @return True if initialized.
    function isErc721Initialized() external view returns (bool);
}
