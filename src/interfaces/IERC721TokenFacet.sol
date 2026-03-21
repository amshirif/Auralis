// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "./IAccessControl.sol";
import {IERC721Metadata} from "./IERC721Metadata.sol";
import {IERC721TokenBase} from "./IERC721TokenBase.sol";
import {IPausable} from "./IPausable.sol";

/// @title IERC721TokenFacet
/// @notice Hosted ERC-721 facet surface for diamond deployments.
interface IERC721TokenFacet is IERC721Metadata, IERC721TokenBase, IAccessControl, IPausable {
    /// @notice Thrown when `operator` is not authorized to manage `tokenId`.
    error ERC721TokenUnauthorizedOperator(address operator, uint256 tokenId);

    /// @notice Returns the shared token admin role identifier.
    /// @return The role identifier.
    function TOKEN_ADMIN_ROLE() external view returns (bytes32);

    /// @notice Returns the ERC-721 minter role identifier.
    /// @return The role identifier.
    function ERC721_MINTER_ROLE() external view returns (bytes32);

    /// @notice Returns the ERC-721 burner role identifier.
    /// @return The role identifier.
    function ERC721_BURNER_ROLE() external view returns (bytes32);

    /// @notice Returns the ERC-721 metadata manager role identifier.
    /// @return The role identifier.
    function ERC721_METADATA_ROLE() external view returns (bytes32);

    /// @notice Returns the ERC-721 transfer pause scope identifier.
    /// @return The scope identifier.
    function ERC721_TRANSFER_SCOPE() external view returns (bytes32);

    /// @notice Returns the ERC-721 approval pause scope identifier.
    /// @return The scope identifier.
    function ERC721_APPROVAL_SCOPE() external view returns (bytes32);

    /// @notice Initializes the hosted ERC-721 facet.
    /// @param tokenName Collection name.
    /// @param tokenSymbol Collection symbol.
    /// @param baseURI Default base URI for token metadata.
    /// @param admin Admin account seeded into the shared control plane.
    function initializeErc721(
        string calldata tokenName,
        string calldata tokenSymbol,
        string calldata baseURI,
        address admin
    ) external;

    /// @notice Returns the current live token count.
    /// @return The current token count.
    function totalSupply() external view returns (uint256);

    /// @notice Mints `tokenId` to `to`.
    /// @param to Recipient account.
    /// @param tokenId Token identifier.
    function mint(address to, uint256 tokenId) external;

    /// @notice Safely mints `tokenId` to `to`.
    /// @param to Recipient account.
    /// @param tokenId Token identifier.
    /// @param data Additional receiver data.
    function safeMint(address to, uint256 tokenId, bytes calldata data) external;

    /// @notice Burns `tokenId`.
    /// @param tokenId Token identifier.
    function burn(uint256 tokenId) external;

    /// @notice Updates the collection base URI.
    /// @param baseURI New base URI.
    function setBaseURI(string calldata baseURI) external;

    /// @notice Sets an explicit metadata URI for `tokenId`.
    /// @param tokenId Token identifier.
    /// @param uri Explicit metadata URI.
    function setTokenURI(uint256 tokenId, string calldata uri) external;
}
