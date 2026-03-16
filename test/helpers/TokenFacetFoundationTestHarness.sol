// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "../../src/interfaces/IERC165.sol";
import {IERC721Receiver} from "../../src/interfaces/IERC721Receiver.sol";
import {ERC20TokenBase} from "../../src/token/ERC20TokenBase.sol";
import {ERC721TokenBase} from "../../src/token/ERC721TokenBase.sol";
import {LibERC20TokenStorage} from "../../src/token/storage/LibERC20TokenStorage.sol";
import {LibERC721TokenStorage} from "../../src/token/storage/LibERC721TokenStorage.sol";
import {LibTokenFacetConstants} from "../../src/token/libraries/LibTokenFacetConstants.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

contract ERC20TokenBaseHarness is ERC20TokenBase {
    function initialize(string calldata tokenName, string calldata tokenSymbol, uint8 tokenDecimals) external {
        _initializeErc20Token(tokenName, tokenSymbol, tokenDecimals);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transferTokens(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _setAllowance(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _transferTokens(from, to, value);
        return true;
    }

    function mint(address to, uint256 value) external {
        _mintTokens(to, value);
    }

    function burn(address from, uint256 value) external {
        _burnTokens(from, value);
    }

    function transferTokens(address from, address to, uint256 value) external {
        _transferTokens(from, to, value);
    }

    function approveTokens(address owner, address spender, uint256 value) external {
        _setAllowance(owner, spender, value);
    }

    function spendAllowance(address owner, address spender, uint256 value) external {
        _spendAllowance(owner, spender, value);
    }
}

contract ERC721TokenBaseHarness is ERC721TokenBase {
    function initialize(string calldata tokenName, string calldata tokenSymbol, string calldata baseUri) external {
        _initializeErc721Token(tokenName, tokenSymbol, baseUri);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        _safeTransferToken(from, to, tokenId, "");
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        _transferToken(from, to, tokenId);
    }

    function approve(address to, uint256 tokenId) external {
        _approveToken(to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        _setApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external {
        _safeTransferToken(from, to, tokenId, data);
    }

    function mint(address to, uint256 tokenId) external {
        _mintToken(to, tokenId);
    }

    function safeMint(address to, uint256 tokenId, bytes calldata data) external {
        _safeMintToken(to, tokenId, data);
    }

    function burn(uint256 tokenId) external {
        _burnToken(tokenId);
    }

    function transferTokens(address from, address to, uint256 tokenId) external {
        _transferToken(from, to, tokenId);
    }

    function safeTransferTokens(address from, address to, uint256 tokenId, bytes calldata data) external {
        _safeTransferToken(from, to, tokenId, data);
    }

    function approveToken(address to, uint256 tokenId) external {
        _approveToken(to, tokenId);
    }

    function setApprovalForAll(address owner, address operator, bool approved) external {
        _setApprovalForAll(owner, operator, approved);
    }

    function setBaseURI(string calldata baseUri) external {
        _setBaseURI(baseUri);
    }

    function setTokenURI(uint256 tokenId, string calldata uri) external {
        _setTokenURI(tokenId, uri);
    }

    function isApprovedOrOwner(address spender, uint256 tokenId) external view returns (bool) {
        return _isApprovedOrOwner(spender, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

contract ERC721ReceiverMock is IERC721Receiver {
    bytes4 internal _response;
    address internal _lastOperator;
    address internal _lastFrom;
    uint256 internal _lastTokenId;
    bytes internal _lastData;

    constructor(bytes4 response_) {
        _response = response_;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        _lastOperator = operator;
        _lastFrom = from;
        _lastTokenId = tokenId;
        _lastData = data;
        return _response;
    }

    function lastOperator() external view returns (address) {
        return _lastOperator;
    }

    function lastFrom() external view returns (address) {
        return _lastFrom;
    }

    function lastTokenId() external view returns (uint256) {
        return _lastTokenId;
    }

    function lastData() external view returns (bytes memory) {
        return _lastData;
    }
}

contract ERC721ReceiverRejector {}

abstract contract TokenFacetFoundationFixture is TestBase {
    address internal admin = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal eve = address(0xE11E);

    ERC20TokenBaseHarness internal erc20;
    ERC721TokenBaseHarness internal erc721;
    ERC721ReceiverMock internal receiver;
    ERC721ReceiverRejector internal rejector;

    function setUp() public virtual {
        erc20 = new ERC20TokenBaseHarness();
        erc721 = new ERC721TokenBaseHarness();
        receiver = new ERC721ReceiverMock(IERC721Receiver.onERC721Received.selector);
        rejector = new ERC721ReceiverRejector();
    }

    function erc20StorageSlot() public pure returns (bytes32) {
        return LibERC20TokenStorage.STORAGE_SLOT;
    }

    function erc721StorageSlot() public pure returns (bytes32) {
        return LibERC721TokenStorage.STORAGE_SLOT;
    }

    function tokenAdminRole() public pure returns (bytes32) {
        return LibTokenFacetConstants.TOKEN_ADMIN_ROLE;
    }

    function erc20MinterRole() public pure returns (bytes32) {
        return LibTokenFacetConstants.ERC20_MINTER_ROLE;
    }

    function erc721MetadataRole() public pure returns (bytes32) {
        return LibTokenFacetConstants.ERC721_METADATA_ROLE;
    }

    function erc20TransferScope() public pure returns (bytes32) {
        return LibTokenFacetConstants.ERC20_TRANSFER_SCOPE;
    }

    function erc721ApprovalScope() public pure returns (bytes32) {
        return LibTokenFacetConstants.ERC721_APPROVAL_SCOPE;
    }

    function supportsErc721(bytes4 interfaceId) public view returns (bool) {
        return erc721.supportsInterface(interfaceId);
    }

    function supportsErc165(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}
