// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20TokenFacet} from "../../interfaces/IERC20TokenFacet.sol";
import {IERC165} from "../../interfaces/IERC165.sol";
import {ERC20TokenBase} from "../ERC20TokenBase.sol";
import {TokenFacetControl} from "../TokenFacetControl.sol";
import {LibTokenFacetConstants} from "../libraries/LibTokenFacetConstants.sol";

/// @title ERC20TokenFacet
/// @notice Hosted ERC-20 + metadata facet with shared access control and pause integration.
contract ERC20TokenFacet is ERC20TokenBase, TokenFacetControl, IERC20TokenFacet {
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

        if (_isAccessControlInitialized()) {
            _checkRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }

        _initializeTokenFacetControl(admin);
        _initializeErc20Token(tokenName, tokenSymbol, tokenDecimals);

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

    /// @notice Returns true if this contract implements `interfaceId`.
    /// @param interfaceId The interface identifier.
    /// @return True if supported.
    function supportsInterface(bytes4 interfaceId) public view override(TokenFacetControl, IERC165) returns (bool) {
        return interfaceId == type(IERC20TokenFacet).interfaceId || super.supportsInterface(interfaceId);
    }
}
