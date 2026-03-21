// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "../interfaces/IERC165.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {IERC721Metadata} from "../interfaces/IERC721Metadata.sol";
import {IERC721Receiver} from "../interfaces/IERC721Receiver.sol";
import {IERC721TokenBase} from "../interfaces/IERC721TokenBase.sol";
import {LibERC721TokenStorage} from "./storage/LibERC721TokenStorage.sol";

/// @title ERC721TokenBase
/// @notice Diamond-ready ERC-721 token foundation with initializer, metadata, and shared storage helpers.
abstract contract ERC721TokenBase is IERC721TokenBase {
    /// @notice Returns true when this contract implements `interfaceId`.
    /// @param interfaceId The interface identifier.
    /// @return True when supported.
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC721).interfaceId
            || interfaceId == type(IERC721Metadata).interfaceId;
    }

    /// @notice Returns true when ERC-721 storage is initialized.
    /// @return True if initialized.
    function isErc721Initialized() public view returns (bool) {
        return LibERC721TokenStorage.layout().initialized;
    }

    /// @notice Returns ERC-721 collection name.
    /// @return The collection name.
    function name() public view virtual returns (string memory) {
        return LibERC721TokenStorage.layout().name;
    }

    /// @notice Returns ERC-721 collection symbol.
    /// @return The collection symbol.
    function symbol() public view virtual returns (string memory) {
        return LibERC721TokenStorage.layout().symbol;
    }

    /// @notice Returns the current token owner.
    /// @param tokenId The token identifier.
    /// @return The token owner.
    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        return _requireOwned(tokenId);
    }

    /// @notice Returns token balance for `owner`.
    /// @param owner The account to query.
    /// @return The token balance.
    function balanceOf(address owner) public view virtual returns (uint256) {
        if (owner == address(0)) {
            revert ERC721TokenInvalidOwner(owner);
        }
        return LibERC721TokenStorage.layout().balances[owner];
    }

    /// @notice Returns the approved account for `tokenId`.
    /// @param tokenId The token identifier.
    /// @return The approved account, or zero when unset.
    function getApproved(uint256 tokenId) public view virtual returns (address) {
        _requireOwned(tokenId);
        return LibERC721TokenStorage.layout().tokenApprovals[tokenId];
    }

    /// @notice Returns whether `operator` is approved for all of `owner`'s tokens.
    /// @param owner Token owner.
    /// @param operator Operator account.
    /// @return True when approved.
    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return LibERC721TokenStorage.layout().operatorApprovals[owner][operator];
    }

    /// @notice Returns metadata URI for `tokenId`.
    /// @param tokenId The token identifier.
    /// @return The token metadata URI.
    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        _requireOwned(tokenId);

        LibERC721TokenStorage.Layout storage layout = LibERC721TokenStorage.layout();
        string memory explicitTokenUri = layout.tokenURIs[tokenId];
        if (bytes(explicitTokenUri).length != 0) {
            return explicitTokenUri;
        }
        if (bytes(layout.baseURI).length == 0) {
            return "";
        }
        return string.concat(layout.baseURI, _toString(tokenId));
    }

    /// @notice Returns current live token count tracked by the foundation.
    /// @return The token count.
    function totalSupply() public view virtual returns (uint256) {
        return LibERC721TokenStorage.layout().totalSupply;
    }

    /// @dev Initializes ERC-721 metadata and shared storage.
    /// @param tokenName The collection name.
    /// @param tokenSymbol The collection symbol.
    /// @param defaultBaseURI Default base URI for tokens without explicit URI.
    function _initializeErc721Token(string memory tokenName, string memory tokenSymbol, string memory defaultBaseURI)
        internal
    {
        LibERC721TokenStorage.Layout storage layout = LibERC721TokenStorage.layout();
        if (layout.initialized) {
            revert ERC721TokenAlreadyInitialized();
        }

        layout.initialized = true;
        layout.name = tokenName;
        layout.symbol = tokenSymbol;
        layout.baseURI = defaultBaseURI;
    }

    /// @dev Mints `tokenId` to `to`.
    /// @param to Recipient account.
    /// @param tokenId The token identifier.
    function _mintToken(address to, uint256 tokenId) internal {
        _requireInitialized();
        if (to == address(0)) {
            revert ERC721TokenZeroAddress();
        }
        if (_exists(tokenId)) {
            revert ERC721TokenAlreadyMinted(tokenId);
        }

        LibERC721TokenStorage.Layout storage layout = LibERC721TokenStorage.layout();
        layout.owners[tokenId] = to;
        layout.balances[to] += 1;
        layout.totalSupply += 1;

        emit Transfer(address(0), to, tokenId);
    }

    /// @dev Safely mints `tokenId` to `to`.
    /// @param to Recipient account.
    /// @param tokenId The token identifier.
    /// @param data Additional receiver data.
    function _safeMintToken(address to, uint256 tokenId, bytes memory data) internal {
        _mintToken(to, tokenId);
        _checkOnErc721Received(address(0), to, tokenId, data);
    }

    /// @dev Burns `tokenId`.
    /// @param tokenId The token identifier.
    function _burnToken(uint256 tokenId) internal {
        _requireInitialized();

        LibERC721TokenStorage.Layout storage layout = LibERC721TokenStorage.layout();
        address owner_ = _requireOwned(tokenId);

        unchecked {
            layout.balances[owner_] -= 1;
            layout.totalSupply -= 1;
        }

        delete layout.owners[tokenId];
        delete layout.tokenApprovals[tokenId];
        delete layout.tokenURIs[tokenId];

        emit Transfer(owner_, address(0), tokenId);
    }

    /// @dev Transfers `tokenId` from `from` to `to`.
    /// @param from Current token owner.
    /// @param to Token receiver.
    /// @param tokenId The token identifier.
    function _transferToken(address from, address to, uint256 tokenId) internal {
        _requireInitialized();
        if (to == address(0)) {
            revert ERC721TokenZeroAddress();
        }

        address owner_ = _requireOwned(tokenId);
        if (owner_ != from) {
            revert ERC721TokenIncorrectOwner(from, tokenId, owner_);
        }

        LibERC721TokenStorage.Layout storage layout = LibERC721TokenStorage.layout();
        delete layout.tokenApprovals[tokenId];

        unchecked {
            layout.balances[from] -= 1;
        }
        layout.balances[to] += 1;
        layout.owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /// @dev Safely transfers `tokenId` from `from` to `to`.
    /// @param from Current token owner.
    /// @param to Token receiver.
    /// @param tokenId The token identifier.
    /// @param data Additional receiver data.
    function _safeTransferToken(address from, address to, uint256 tokenId, bytes memory data) internal {
        _transferToken(from, to, tokenId);
        _checkOnErc721Received(from, to, tokenId, data);
    }

    /// @dev Sets approved account for `tokenId`.
    /// @param to Approved account, or zero to clear.
    /// @param tokenId The token identifier.
    function _approveToken(address to, uint256 tokenId) internal {
        _requireInitialized();
        _requireOwned(tokenId);

        LibERC721TokenStorage.layout().tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    /// @dev Enables or disables `operator` for all of `owner`'s tokens.
    /// @param owner Token owner.
    /// @param operator Operator account.
    /// @param approved True to approve, false to revoke.
    function _setApprovalForAll(address owner, address operator, bool approved) internal {
        _requireInitialized();
        if (owner == address(0) || operator == address(0)) {
            revert ERC721TokenZeroAddress();
        }
        if (owner == operator) {
            revert ERC721TokenInvalidOperator(owner, operator);
        }

        LibERC721TokenStorage.layout().operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /// @dev Sets the base URI used for tokens without explicit URI.
    /// @param baseUri The new base URI.
    function _setBaseURI(string memory baseUri) internal {
        _requireInitialized();
        LibERC721TokenStorage.layout().baseURI = baseUri;
    }

    /// @dev Sets explicit metadata URI for `tokenId`.
    /// @param tokenId The token identifier.
    /// @param uri The explicit metadata URI.
    function _setTokenURI(uint256 tokenId, string memory uri) internal {
        _requireInitialized();
        _requireOwned(tokenId);
        LibERC721TokenStorage.layout().tokenURIs[tokenId] = uri;
    }

    /// @dev Returns whether `tokenId` exists.
    /// @param tokenId The token identifier.
    /// @return True when the token exists.
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /// @dev Returns the raw owner for `tokenId`, or zero when absent.
    /// @param tokenId The token identifier.
    /// @return The raw owner address.
    function _ownerOf(uint256 tokenId) internal view returns (address) {
        return LibERC721TokenStorage.layout().owners[tokenId];
    }

    /// @dev Returns whether `spender` can manage `tokenId`.
    /// @param spender The account to check.
    /// @param tokenId The token identifier.
    /// @return True when `spender` is owner or approved.
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner_ = _requireOwned(tokenId);
        return spender == owner_ || getApproved(tokenId) == spender || isApprovedForAll(owner_, spender);
    }

    /// @dev Returns token owner or reverts when token does not exist.
    /// @param tokenId The token identifier.
    /// @return owner_ The token owner.
    function _requireOwned(uint256 tokenId) internal view returns (address owner_) {
        owner_ = _ownerOf(tokenId);
        if (owner_ == address(0)) {
            revert ERC721TokenNonexistentToken(tokenId);
        }
    }

    /// @dev Reverts when ERC-721 storage has not been initialized.
    function _requireInitialized() internal view {
        if (!isErc721Initialized()) {
            revert ERC721TokenNotInitialized();
        }
    }

    /// @dev Reverts when `to` cannot receive safe ERC-721 transfers.
    /// @param from Previous token owner.
    /// @param to Receiver account.
    /// @param tokenId The token identifier.
    /// @param data Additional receiver data.
    function _checkOnErc721Received(address from, address to, uint256 tokenId, bytes memory data) internal {
        if (to.code.length == 0) {
            return;
        }

        try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
            if (retval != IERC721Receiver.onERC721Received.selector) {
                revert ERC721TokenUnsafeReceiver(to);
            }
        } catch {
            revert ERC721TokenUnsafeReceiver(to);
        }
    }

    /// @dev Converts `value` to its decimal string representation.
    /// @param value The value to stringify.
    /// @return The decimal string.
    function _toString(uint256 value) private pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
