// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../../interfaces/IAccessControl.sol";
import {IERC165} from "../../interfaces/IERC165.sol";
import {IERC721TokenFacet} from "../../interfaces/IERC721TokenFacet.sol";
import {ERC721TokenBase} from "../ERC721TokenBase.sol";
import {TokenFacetControl} from "../TokenFacetControl.sol";
import {LibTokenFacetConstants} from "../libraries/LibTokenFacetConstants.sol";

/// @title ERC721TokenFacet
/// @notice Hosted ERC-721 + metadata facet with shared access control and pause integration.
contract ERC721TokenFacet is ERC721TokenBase, TokenFacetControl, IERC721TokenFacet {
    /// @notice Shared token admin role.
    bytes32 public constant TOKEN_ADMIN_ROLE = LibTokenFacetConstants.TOKEN_ADMIN_ROLE;
    /// @notice ERC-721 minter role.
    bytes32 public constant ERC721_MINTER_ROLE = LibTokenFacetConstants.ERC721_MINTER_ROLE;
    /// @notice ERC-721 burner role.
    bytes32 public constant ERC721_BURNER_ROLE = LibTokenFacetConstants.ERC721_BURNER_ROLE;
    /// @notice ERC-721 metadata manager role.
    bytes32 public constant ERC721_METADATA_ROLE = LibTokenFacetConstants.ERC721_METADATA_ROLE;
    /// @notice Pause scope for ERC-721 transfers.
    bytes32 public constant ERC721_TRANSFER_SCOPE = LibTokenFacetConstants.ERC721_TRANSFER_SCOPE;
    /// @notice Pause scope for ERC-721 approvals.
    bytes32 public constant ERC721_APPROVAL_SCOPE = LibTokenFacetConstants.ERC721_APPROVAL_SCOPE;

    /// @notice Initializes the hosted ERC-721 facet.
    /// @param tokenName Collection name.
    /// @param tokenSymbol Collection symbol.
    /// @param baseURI Default base URI for tokens without explicit metadata URI.
    /// @param admin Admin account seeded into the shared control plane.
    function initializeErc721(
        string calldata tokenName,
        string calldata tokenSymbol,
        string calldata baseURI,
        address admin
    ) external {
        if (isErc721Initialized()) {
            revert ERC721TokenAlreadyInitialized();
        }

        _enforceBootstrapInitializerAuthority();
        _initializeTokenFacetControl(admin);
        _initializeErc721Token(tokenName, tokenSymbol, baseURI);

        _setRoleAdmin(TOKEN_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ERC721_MINTER_ROLE, TOKEN_ADMIN_ROLE);
        _setRoleAdmin(ERC721_BURNER_ROLE, TOKEN_ADMIN_ROLE);
        _setRoleAdmin(ERC721_METADATA_ROLE, TOKEN_ADMIN_ROLE);

        _grantRole(TOKEN_ADMIN_ROLE, admin);
        _grantRole(ERC721_MINTER_ROLE, admin);
        _grantRole(ERC721_BURNER_ROLE, admin);
        _grantRole(ERC721_METADATA_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    /// @notice Approves `to` to manage `tokenId`.
    /// @param to Approved account, or zero to clear approval.
    /// @param tokenId Token identifier.
    function approve(address to, uint256 tokenId) external whenScopeNotPaused(ERC721_APPROVAL_SCOPE) {
        address owner_ = ownerOf(tokenId);
        if (msg.sender != owner_ && !isApprovedForAll(owner_, msg.sender)) {
            revert ERC721TokenUnauthorizedOperator(msg.sender, tokenId);
        }
        _approveToken(to, tokenId);
    }

    /// @notice Enables or disables `operator` for all caller-owned tokens.
    /// @param operator Operator account.
    /// @param approved True to approve, false to revoke.
    function setApprovalForAll(address operator, bool approved) external whenScopeNotPaused(ERC721_APPROVAL_SCOPE) {
        _setApprovalForAll(msg.sender, operator, approved);
    }

    /// @notice Transfers `tokenId` from `from` to `to`.
    /// @param from Current token owner.
    /// @param to Receiver account.
    /// @param tokenId Token identifier.
    function transferFrom(address from, address to, uint256 tokenId)
        external
        whenScopeNotPaused(ERC721_TRANSFER_SCOPE)
    {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert ERC721TokenUnauthorizedOperator(msg.sender, tokenId);
        }
        _transferToken(from, to, tokenId);
    }

    /// @notice Safely transfers `tokenId` from `from` to `to`.
    /// @param from Current token owner.
    /// @param to Receiver account.
    /// @param tokenId Token identifier.
    function safeTransferFrom(address from, address to, uint256 tokenId)
        external
        whenScopeNotPaused(ERC721_TRANSFER_SCOPE)
    {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert ERC721TokenUnauthorizedOperator(msg.sender, tokenId);
        }
        _safeTransferToken(from, to, tokenId, "");
    }

    /// @notice Safely transfers `tokenId` from `from` to `to` with `data`.
    /// @param from Current token owner.
    /// @param to Receiver account.
    /// @param tokenId Token identifier.
    /// @param data Additional receiver data.
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data)
        external
        whenScopeNotPaused(ERC721_TRANSFER_SCOPE)
    {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert ERC721TokenUnauthorizedOperator(msg.sender, tokenId);
        }
        _safeTransferToken(from, to, tokenId, data);
    }

    /// @notice Mints `tokenId` to `to`.
    /// @param to Recipient account.
    /// @param tokenId Token identifier.
    function mint(address to, uint256 tokenId)
        external
        onlyRole(ERC721_MINTER_ROLE)
        whenScopeNotPaused(ERC721_TRANSFER_SCOPE)
    {
        _mintToken(to, tokenId);
    }

    /// @notice Safely mints `tokenId` to `to`.
    /// @param to Recipient account.
    /// @param tokenId Token identifier.
    /// @param data Additional receiver data.
    function safeMint(address to, uint256 tokenId, bytes calldata data)
        external
        onlyRole(ERC721_MINTER_ROLE)
        whenScopeNotPaused(ERC721_TRANSFER_SCOPE)
    {
        _safeMintToken(to, tokenId, data);
    }

    /// @notice Burns `tokenId`.
    /// @param tokenId Token identifier.
    function burn(uint256 tokenId) external onlyRole(ERC721_BURNER_ROLE) whenScopeNotPaused(ERC721_TRANSFER_SCOPE) {
        _burnToken(tokenId);
    }

    /// @notice Updates the collection base URI.
    /// @param baseURI New base URI.
    function setBaseURI(string calldata baseURI) external onlyRole(ERC721_METADATA_ROLE) {
        _setBaseURI(baseURI);
    }

    /// @notice Sets an explicit metadata URI for `tokenId`.
    /// @param tokenId Token identifier.
    /// @param uri Explicit metadata URI.
    function setTokenURI(uint256 tokenId, string calldata uri) external onlyRole(ERC721_METADATA_ROLE) {
        _setTokenURI(tokenId, uri);
    }

    /// @notice Returns the current live token count.
    /// @return The current token count.
    function totalSupply() public view override(ERC721TokenBase, IERC721TokenFacet) returns (uint256) {
        return ERC721TokenBase.totalSupply();
    }

    /// @notice Returns true if this contract implements `interfaceId`.
    /// @param interfaceId The interface identifier.
    /// @return True if supported.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721TokenBase, TokenFacetControl, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC721TokenFacet).interfaceId || ERC721TokenBase.supportsInterface(interfaceId)
            || TokenFacetControl.supportsInterface(interfaceId);
    }
}
