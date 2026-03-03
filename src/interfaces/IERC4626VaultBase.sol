// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20Metadata} from "./IERC20Metadata.sol";

/// @title IERC4626VaultBase
/// @notice Interface for ERC-4626 vault foundation storage and accounting helpers.
interface IERC4626VaultBase is IERC20Metadata {
    /// @notice Thrown when vault initializer runs more than once.
    error ERC4626VaultAlreadyInitialized();
    /// @notice Thrown when mutating helpers run before initialization.
    error ERC4626VaultNotInitialized();
    /// @notice Thrown when vault asset is zero address.
    error ERC4626VaultZeroAsset();
    /// @notice Thrown when a required account is zero address.
    error ERC4626VaultZeroAddress();
    /// @notice Thrown when an account balance is insufficient for requested operation.
    error ERC4626VaultInsufficientBalance(address account, uint256 available, uint256 required);
    /// @notice Thrown when allowance is insufficient for requested operation.
    error ERC4626VaultInsufficientAllowance(address owner, address spender, uint256 available, uint256 required);
    /// @notice Thrown when managed asset accounting would underflow.
    error ERC4626VaultManagedAssetsUnderflow(uint256 available, uint256 required);

    /// @notice Returns true when vault storage is initialized.
    /// @return True if initialized.
    function isVaultInitialized() external view returns (bool);

    /// @notice Returns vault asset token.
    /// @return The underlying asset token address.
    function asset() external view returns (address);

    /// @notice Returns currently managed asset accounting amount.
    /// @return The tracked managed asset amount.
    function totalManagedAssets() external view returns (uint256);
}
