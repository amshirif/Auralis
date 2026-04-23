// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20TokenFacet} from "../../interfaces/IERC20TokenFacet.sol";
import {IERC20Permit} from "../../interfaces/IERC20Permit.sol";
import {IERC165} from "../../interfaces/IERC165.sol";
import {ERC20TokenBase} from "../ERC20TokenBase.sol";
import {TokenFacetControl} from "../TokenFacetControl.sol";
import {LibTokenFacetConstants} from "../libraries/LibTokenFacetConstants.sol";
import {LibERC20TokenStorage} from "../storage/LibERC20TokenStorage.sol";

/// @title ERC20TokenFacet
/// @notice Hosted ERC-20 + metadata facet with shared access control and pause integration.
contract ERC20TokenFacet is ERC20TokenBase, TokenFacetControl, IERC20TokenFacet {
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 internal constant VERSION_HASH = keccak256("1");
    uint256 internal constant SECP256K1N_DIV_2 = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    /// @notice Shared token admin role.
    bytes32 public constant TOKEN_ADMIN_ROLE = LibTokenFacetConstants.TOKEN_ADMIN_ROLE;
    /// @notice ERC-20 minter role.
    bytes32 public constant ERC20_MINTER_ROLE = LibTokenFacetConstants.ERC20_MINTER_ROLE;
    /// @notice ERC-20 burner role.
    bytes32 public constant ERC20_BURNER_ROLE = LibTokenFacetConstants.ERC20_BURNER_ROLE;
    /// @notice Pause scope for ERC-20 transfers.
    bytes32 public constant ERC20_TRANSFER_SCOPE = LibTokenFacetConstants.ERC20_TRANSFER_SCOPE;
    /// @notice Pause scope for ERC-20 approvals.
    bytes32 public constant ERC20_APPROVAL_SCOPE = LibTokenFacetConstants.ERC20_APPROVAL_SCOPE;

    /// @notice Initializes the hosted ERC-20 facet.
    /// @param tokenName Token name.
    /// @param tokenSymbol Token symbol.
    /// @param tokenDecimals Token decimals.
    /// @param admin Admin account seeded into the shared control plane.
    function initializeErc20(
        string calldata tokenName,
        string calldata tokenSymbol,
        uint8 tokenDecimals,
        address admin
    ) external {
        if (isErc20Initialized()) {
            revert ERC20TokenAlreadyInitialized();
        }

        _enforceBootstrapInitializerAuthority();
        _initializeTokenFacetControl(admin);
        _initializeErc20Token(tokenName, tokenSymbol, tokenDecimals);
        _initializePermitDomain(tokenName);

        _setRoleAdmin(TOKEN_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ERC20_MINTER_ROLE, TOKEN_ADMIN_ROLE);
        _setRoleAdmin(ERC20_BURNER_ROLE, TOKEN_ADMIN_ROLE);

        _grantRole(TOKEN_ADMIN_ROLE, admin);
        _grantRole(ERC20_MINTER_ROLE, admin);
        _grantRole(ERC20_BURNER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    /// @notice Transfers `value` tokens to `to`.
    /// @param to Recipient account.
    /// @param value Amount to transfer.
    /// @return True if the transfer succeeded.
    function transfer(address to, uint256 value) external whenScopeNotPaused(ERC20_TRANSFER_SCOPE) returns (bool) {
        _transferTokens(msg.sender, to, value);
        return true;
    }

    /// @notice Sets allowance from caller to `spender`.
    /// @param spender Approved spender.
    /// @param value New allowance amount.
    /// @return True if the approval succeeded.
    function approve(address spender, uint256 value) external whenScopeNotPaused(ERC20_APPROVAL_SCOPE) returns (bool) {
        _setAllowance(msg.sender, spender, value);
        return true;
    }

    /// @notice Transfers `value` tokens from `from` to `to` using allowance.
    /// @param from Source account.
    /// @param to Recipient account.
    /// @param value Amount to transfer.
    /// @return True if the transfer succeeded.
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        _requireScopeNotPaused(ERC20_APPROVAL_SCOPE);
        _requireScopeNotPaused(ERC20_TRANSFER_SCOPE);
        _spendAllowance(from, msg.sender, value);
        _transferTokens(from, to, value);
        return true;
    }

    /// @notice Mints `value` tokens to `to`.
    /// @dev Caller must have `ERC20_MINTER_ROLE`.
    /// @param to Recipient account.
    /// @param value Amount to mint.
    function mint(address to, uint256 value)
        external
        onlyRole(ERC20_MINTER_ROLE)
        whenScopeNotPaused(ERC20_TRANSFER_SCOPE)
    {
        _mintTokens(to, value);
    }

    /// @notice Burns `value` tokens from `from`.
    /// @dev Caller must have `ERC20_BURNER_ROLE`.
    /// @param from Token holder.
    /// @param value Amount to burn.
    function burn(address from, uint256 value)
        external
        onlyRole(ERC20_BURNER_ROLE)
        whenScopeNotPaused(ERC20_TRANSFER_SCOPE)
    {
        _burnTokens(from, value);
    }

    /// @notice Sets allowance with a signed Permit approval.
    /// @param owner Token owner.
    /// @param spender Approved spender.
    /// @param value Allowance amount.
    /// @param deadline Signature expiration timestamp.
    /// @param v Recovery identifier.
    /// @param r Signature component.
    /// @param s Signature component.
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        whenScopeNotPaused(ERC20_APPROVAL_SCOPE)
    {
        if (block.timestamp > deadline) {
            revert ERC20PermitExpired(deadline, block.timestamp);
        }

        LibERC20TokenStorage.Layout storage layout = LibERC20TokenStorage.layout();
        uint256 nonce = layout.nonces[owner];
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), structHash));
        address signer = _recoverSigner(digest, v, r, s);
        if (signer != owner) {
            revert ERC20PermitInvalidSigner(signer, owner);
        }

        layout.nonces[owner] = nonce + 1;
        _setAllowance(owner, spender, value);
    }

    /// @notice Returns the current Permit nonce for `owner`.
    /// @param owner Token owner.
    /// @return The current nonce.
    function nonces(address owner) external view returns (uint256) {
        return LibERC20TokenStorage.layout().nonces[owner];
    }

    /// @notice Returns the EIP-712 domain separator for Permit signatures.
    /// @return The domain separator.
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        LibERC20TokenStorage.Layout storage layout = LibERC20TokenStorage.layout();
        if (layout.cachedChainId == block.chainid) {
            return layout.cachedDomainSeparator;
        }
        return _buildDomainSeparator(layout.hashedName, block.chainid);
    }

    /// @notice Returns true if this contract implements `interfaceId`.
    /// @param interfaceId The interface identifier.
    /// @return True if supported.
    function supportsInterface(bytes4 interfaceId) public view override(TokenFacetControl, IERC165) returns (bool) {
        return interfaceId == type(IERC20TokenFacet).interfaceId || interfaceId == type(IERC20Permit).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function _initializePermitDomain(string memory tokenName) internal {
        LibERC20TokenStorage.Layout storage layout = LibERC20TokenStorage.layout();
        layout.hashedName = keccak256(bytes(tokenName));
        layout.cachedChainId = block.chainid;
        layout.cachedDomainSeparator = _buildDomainSeparator(layout.hashedName, block.chainid);
    }

    function _buildDomainSeparator(bytes32 hashedName, uint256 chainId) internal view returns (bytes32) {
        return keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, hashedName, VERSION_HASH, chainId, address(this)));
    }

    function _recoverSigner(bytes32 digest, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        if (v != 27 && v != 28) {
            return address(0);
        }
        if (uint256(s) > SECP256K1N_DIV_2) {
            return address(0);
        }

        return ecrecover(digest, v, r, s);
    }
}
