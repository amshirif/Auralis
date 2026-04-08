// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20Metadata} from "../interfaces/IERC20Metadata.sol";
import {IERC4626VaultBase} from "../interfaces/IERC4626VaultBase.sol";
import {LibERC4626VaultStorage} from "./storage/LibERC4626VaultStorage.sol";

/// @title ERC4626VaultBase
/// @notice Diamond-ready ERC-4626 foundation with initializer and shared accounting helpers.
abstract contract ERC4626VaultBase is IERC4626VaultBase {
    /// @notice Rounding direction used for conversion helpers.
    enum Rounding {
        Down,
        Up
    }

    /// @notice Returns true when vault storage is initialized.
    /// @return True if initialized.
    function isVaultInitialized() public view virtual returns (bool) {
        return LibERC4626VaultStorage.layout().initialized;
    }

    /// @notice Returns vault asset token.
    /// @return The underlying asset token address.
    function asset() public view virtual returns (address) {
        return LibERC4626VaultStorage.layout().asset;
    }

    /// @notice Returns currently managed asset accounting amount.
    /// @return The tracked managed asset amount.
    function totalManagedAssets() public view virtual returns (uint256) {
        // Managed assets are the pricing source of truth; raw balances can diverge due to donations,
        // force-sent value, or strategy timing and must not silently reprice shares.
        return LibERC4626VaultStorage.layout().totalManagedAssets;
    }

    /// @notice Returns ERC-20 share token name.
    /// @return The share token name.
    function name() public view virtual returns (string memory) {
        return LibERC4626VaultStorage.layout().name;
    }

    /// @notice Returns ERC-20 share token symbol.
    /// @return The share token symbol.
    function symbol() public view virtual returns (string memory) {
        return LibERC4626VaultStorage.layout().symbol;
    }

    /// @notice Returns ERC-20 share token decimals.
    /// @return The share token decimals.
    function decimals() public view virtual returns (uint8) {
        return LibERC4626VaultStorage.layout().decimals;
    }

    /// @notice Returns total ERC-20 share supply.
    /// @return The share supply.
    function totalSupply() public view virtual returns (uint256) {
        return LibERC4626VaultStorage.layout().totalSupply;
    }

    /// @notice Returns share balance for `account`.
    /// @param account The account to query.
    /// @return The share balance.
    function balanceOf(address account) public view virtual returns (uint256) {
        return LibERC4626VaultStorage.layout().balances[account];
    }

    /// @notice Returns allowance from `owner` to `spender`.
    /// @param owner Token owner.
    /// @param spender Approved spender.
    /// @return Remaining allowance.
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return LibERC4626VaultStorage.layout().allowances[owner][spender];
    }

    /// @dev Initializes vault storage (diamond-ready).
    /// @dev If `asset` does not expose standard metadata decimals, defaults to 18.
    /// @param vaultAsset The underlying asset token.
    /// @param vaultName The share token name.
    /// @param vaultSymbol The share token symbol.
    function _initializeErc4626Vault(address vaultAsset, string memory vaultName, string memory vaultSymbol) internal {
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        if (layout.initialized) {
            revert ERC4626VaultAlreadyInitialized();
        }
        if (vaultAsset == address(0)) {
            revert ERC4626VaultZeroAsset();
        }

        layout.initialized = true;
        layout.asset = vaultAsset;
        layout.name = vaultName;
        layout.symbol = vaultSymbol;
        layout.decimals = _readAssetDecimals(vaultAsset);
    }

    /// @dev Mints `shares` to `account`.
    /// @param account Share recipient.
    /// @param shares Shares to mint.
    function _mintShares(address account, uint256 shares) internal {
        _requireInitialized();
        _requireNonZeroAddress(account);

        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        layout.totalSupply += shares;
        layout.balances[account] += shares;
        emit Transfer(address(0), account, shares);
    }

    /// @dev Burns `shares` from `account`.
    /// @param account Share holder.
    /// @param shares Shares to burn.
    function _burnShares(address account, uint256 shares) internal {
        _requireInitialized();
        _requireNonZeroAddress(account);

        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        uint256 currentBalance = layout.balances[account];
        if (currentBalance < shares) {
            revert ERC4626VaultInsufficientBalance(account, currentBalance, shares);
        }

        unchecked {
            layout.balances[account] = currentBalance - shares;
            layout.totalSupply -= shares;
        }

        emit Transfer(account, address(0), shares);
    }

    /// @dev Transfers `shares` from `from` to `to`.
    /// @param from Source account.
    /// @param to Recipient account.
    /// @param shares Shares to transfer.
    function _transferShares(address from, address to, uint256 shares) internal {
        _requireInitialized();
        _requireNonZeroAddress(from);
        _requireNonZeroAddress(to);

        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        uint256 fromBalance = layout.balances[from];
        if (fromBalance < shares) {
            revert ERC4626VaultInsufficientBalance(from, fromBalance, shares);
        }

        unchecked {
            layout.balances[from] = fromBalance - shares;
        }
        layout.balances[to] += shares;

        emit Transfer(from, to, shares);
    }

    /// @dev Sets allowance from `owner` to `spender`.
    /// @param owner Token owner.
    /// @param spender Approved spender.
    /// @param value New allowance amount.
    function _setAllowance(address owner, address spender, uint256 value) internal {
        _requireInitialized();
        _requireNonZeroAddress(owner);
        _requireNonZeroAddress(spender);

        LibERC4626VaultStorage.layout().allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /// @dev Consumes allowance from `owner` to `spender`.
    /// @dev Infinite allowance (`type(uint256).max`) is not decremented.
    /// @param owner Token owner.
    /// @param spender Approved spender.
    /// @param value Allowance amount to consume.
    function _spendAllowance(address owner, address spender, uint256 value) internal {
        _requireInitialized();

        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance == type(uint256).max) {
            return;
        }
        if (currentAllowance < value) {
            revert ERC4626VaultInsufficientAllowance(owner, spender, currentAllowance, value);
        }

        unchecked {
            _setAllowance(owner, spender, currentAllowance - value);
        }
    }

    /// @dev Increases managed asset accounting.
    /// @param assets Asset amount to add.
    function _increaseManagedAssets(uint256 assets) internal {
        _requireInitialized();
        LibERC4626VaultStorage.layout().totalManagedAssets += assets;
    }

    /// @dev Decreases managed asset accounting.
    /// @param assets Asset amount to remove.
    function _decreaseManagedAssets(uint256 assets) internal {
        _requireInitialized();

        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        uint256 managedAssets = layout.totalManagedAssets;
        // Guard against tracked-accounting underflow directly so unexpected surplus cannot mask an
        // accounting bug or let the vault spend assets it never managed.
        if (managedAssets < assets) {
            revert ERC4626VaultManagedAssetsUnderflow(managedAssets, assets);
        }

        unchecked {
            layout.totalManagedAssets = managedAssets - assets;
        }
    }

    /// @dev Converts `assets` to shares using current vault totals.
    /// @param assets Asset amount.
    /// @param rounding Rounding direction.
    /// @return Share amount.
    function _convertToShares(uint256 assets, Rounding rounding) internal view returns (uint256) {
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        return _convertToShares(assets, layout.totalSupply, layout.totalManagedAssets, rounding);
    }

    /// @dev Converts `shares` to assets using current vault totals.
    /// @param shares Share amount.
    /// @param rounding Rounding direction.
    /// @return Asset amount.
    function _convertToAssets(uint256 shares, Rounding rounding) internal view returns (uint256) {
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        return _convertToAssets(shares, layout.totalSupply, layout.totalManagedAssets, rounding);
    }

    /// @dev Converts `assets` to shares using explicit totals.
    /// @param assets Asset amount.
    /// @param supply Share supply.
    /// @param managedAssets Managed assets.
    /// @param rounding Rounding direction.
    /// @return Share amount.
    function _convertToShares(uint256 assets, uint256 supply, uint256 managedAssets, Rounding rounding)
        internal
        pure
        returns (uint256)
    {
        if (assets == 0) {
            return 0;
        }
        if (supply == 0 || managedAssets == 0) {
            // Bootstrap 1:1 so the first liquidity provider establishes the initial price instead of
            // inheriting an arbitrary ratio from uninitialized accounting.
            return assets;
        }

        return _mulDiv(assets, supply, managedAssets, rounding);
    }

    /// @dev Converts `shares` to assets using explicit totals.
    /// @param shares Share amount.
    /// @param supply Share supply.
    /// @param managedAssets Managed assets.
    /// @param rounding Rounding direction.
    /// @return Asset amount.
    function _convertToAssets(uint256 shares, uint256 supply, uint256 managedAssets, Rounding rounding)
        internal
        pure
        returns (uint256)
    {
        if (shares == 0) {
            return 0;
        }
        if (supply == 0 || managedAssets == 0) {
            // Keep previews symmetric with the same 1:1 bootstrap rule before the vault has a meaningful
            // supply-to-assets ratio.
            return shares;
        }

        return _mulDiv(shares, managedAssets, supply, rounding);
    }

    /// @dev Returns floor/ceil of `(x * y) / denominator`.
    /// @param x Multiplicand.
    /// @param y Multiplier.
    /// @param denominator Divisor.
    /// @param rounding Rounding direction.
    /// @return result Computed quotient.
    function _mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding)
        internal
        pure
        returns (uint256 result)
    {
        uint256 product = x * y;
        result = product / denominator;

        if (rounding == Rounding.Up && product % denominator != 0) {
            result += 1;
        }
    }

    /// @dev Reverts when vault is not initialized.
    function _requireInitialized() internal view {
        if (!isVaultInitialized()) {
            revert ERC4626VaultNotInitialized();
        }
    }

    /// @dev Reverts when `account` is zero address.
    /// @param account Address to validate.
    function _requireNonZeroAddress(address account) internal pure {
        if (account == address(0)) {
            revert ERC4626VaultZeroAddress();
        }
    }

    /// @dev Reads decimals from `vaultAsset`; falls back to `18` when unavailable.
    /// @param vaultAsset Asset token address.
    /// @return Token decimals value.
    function _readAssetDecimals(address vaultAsset) internal view returns (uint8) {
        (bool success, bytes memory data) = vaultAsset.staticcall(abi.encodeCall(IERC20Metadata.decimals, ()));
        if (!success || data.length != 32) {
            return 18;
        }

        return abi.decode(data, (uint8));
    }
}
