// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20TokenBase} from "../interfaces/IERC20TokenBase.sol";
import {LibERC20TokenStorage} from "./storage/LibERC20TokenStorage.sol";

/// @title ERC20TokenBase
/// @notice Diamond-ready ERC-20 token foundation with initializer and shared storage helpers.
abstract contract ERC20TokenBase is IERC20TokenBase {
    /// @notice Returns true when ERC-20 storage is initialized.
    /// @return True if initialized.
    function isErc20Initialized() public view returns (bool) {
        return LibERC20TokenStorage.layout().initialized;
    }

    /// @notice Returns ERC-20 token name.
    /// @return The token name.
    function name() public view virtual returns (string memory) {
        return LibERC20TokenStorage.layout().name;
    }

    /// @notice Returns ERC-20 token symbol.
    /// @return The token symbol.
    function symbol() public view virtual returns (string memory) {
        return LibERC20TokenStorage.layout().symbol;
    }

    /// @notice Returns ERC-20 token decimals.
    /// @return The token decimals.
    function decimals() public view virtual returns (uint8) {
        return LibERC20TokenStorage.layout().decimals;
    }

    /// @notice Returns total token supply.
    /// @return The current total supply.
    function totalSupply() public view virtual returns (uint256) {
        return LibERC20TokenStorage.layout().totalSupply;
    }

    /// @notice Returns balance for `account`.
    /// @param account The account to query.
    /// @return The token balance.
    function balanceOf(address account) public view virtual returns (uint256) {
        return LibERC20TokenStorage.layout().balances[account];
    }

    /// @notice Returns allowance from `owner` to `spender`.
    /// @param owner Token owner.
    /// @param spender Approved spender.
    /// @return Remaining allowance.
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return LibERC20TokenStorage.layout().allowances[owner][spender];
    }

    /// @dev Initializes ERC-20 metadata and shared storage.
    /// @param tokenName The ERC-20 token name.
    /// @param tokenSymbol The ERC-20 token symbol.
    /// @param tokenDecimals The ERC-20 token decimals.
    function _initializeErc20Token(string memory tokenName, string memory tokenSymbol, uint8 tokenDecimals) internal {
        LibERC20TokenStorage.Layout storage layout = LibERC20TokenStorage.layout();
        if (layout.initialized) {
            revert ERC20TokenAlreadyInitialized();
        }

        layout.initialized = true;
        layout.name = tokenName;
        layout.symbol = tokenSymbol;
        layout.decimals = tokenDecimals;
    }

    /// @dev Mints `value` tokens to `to`.
    /// @param to Recipient account.
    /// @param value Amount to mint.
    function _mintTokens(address to, uint256 value) internal {
        _requireInitialized();
        _requireNonZeroAddress(to);

        LibERC20TokenStorage.Layout storage layout = LibERC20TokenStorage.layout();
        layout.totalSupply += value;
        layout.balances[to] += value;

        emit Transfer(address(0), to, value);
    }

    /// @dev Burns `value` tokens from `from`.
    /// @param from Token owner.
    /// @param value Amount to burn.
    function _burnTokens(address from, uint256 value) internal {
        _requireInitialized();
        _requireNonZeroAddress(from);

        LibERC20TokenStorage.Layout storage layout = LibERC20TokenStorage.layout();
        uint256 fromBalance = layout.balances[from];
        if (fromBalance < value) {
            revert ERC20TokenInsufficientBalance(from, fromBalance, value);
        }

        unchecked {
            layout.balances[from] = fromBalance - value;
            layout.totalSupply -= value;
        }

        emit Transfer(from, address(0), value);
    }

    /// @dev Transfers `value` tokens from `from` to `to`.
    /// @param from Token sender.
    /// @param to Token receiver.
    /// @param value Amount to transfer.
    function _transferTokens(address from, address to, uint256 value) internal {
        _requireInitialized();
        _requireNonZeroAddress(from);
        _requireNonZeroAddress(to);

        LibERC20TokenStorage.Layout storage layout = LibERC20TokenStorage.layout();
        uint256 fromBalance = layout.balances[from];
        if (fromBalance < value) {
            revert ERC20TokenInsufficientBalance(from, fromBalance, value);
        }

        unchecked {
            layout.balances[from] = fromBalance - value;
        }
        layout.balances[to] += value;

        emit Transfer(from, to, value);
    }

    /// @dev Sets allowance from `owner` to `spender`.
    /// @param owner Token owner.
    /// @param spender Approved spender.
    /// @param value New allowance value.
    function _setAllowance(address owner, address spender, uint256 value) internal {
        _requireInitialized();
        _requireNonZeroAddress(owner);

        LibERC20TokenStorage.layout().allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /// @dev Consumes allowance from `owner` to `spender`.
    /// @dev Infinite allowance (`type(uint256).max`) is not decremented.
    /// @param owner Token owner.
    /// @param spender Approved spender.
    /// @param value Amount to consume.
    function _spendAllowance(address owner, address spender, uint256 value) internal {
        _requireInitialized();
        _requireNonZeroAddress(owner);

        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance == type(uint256).max) {
            return;
        }
        if (currentAllowance < value) {
            revert ERC20TokenInsufficientAllowance(owner, spender, currentAllowance, value);
        }

        unchecked {
            _setAllowance(owner, spender, currentAllowance - value);
        }
    }

    /// @dev Reverts when ERC-20 storage has not been initialized.
    function _requireInitialized() internal view {
        if (!isErc20Initialized()) {
            revert ERC20TokenNotInitialized();
        }
    }

    /// @dev Reverts when `account` is zero.
    /// @param account The account to validate.
    function _requireNonZeroAddress(address account) internal pure {
        if (account == address(0)) {
            revert ERC20TokenZeroAddress();
        }
    }
}
