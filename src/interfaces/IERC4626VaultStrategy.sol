// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IERC4626VaultStrategy
/// @notice Canonical single-vault, single-asset strategy interface for hosted vaults.
interface IERC4626VaultStrategy {
    /// @notice Thrown when a non-vault caller invokes a vault-only strategy action.
    /// @param caller The unauthorized caller.
    /// @param vault The bound vault address.
    error ERC4626VaultStrategyOnlyVault(address caller, address vault);

    /// @notice Returns the vault this strategy is bound to.
    /// @return The vault address.
    function vault() external view returns (address);

    /// @notice Returns the underlying asset this strategy manages.
    /// @return The asset address.
    function asset() external view returns (address);

    /// @notice Returns the strategy's total tracked assets.
    /// @dev Hosted vault pricing treats this as a trusted mark-to-market input while strategy debt is active.
    ///      Vault reads intentionally do not fall back to stored debt when this strategy quote reverts.
    /// @return The total tracked asset amount.
    function totalAssets() external view returns (uint256);

    /// @notice Returns the strategy's currently withdrawable asset amount.
    /// @return The maximum assets that can be returned immediately.
    function maxWithdrawableAssets() external view returns (uint256);

    /// @notice Deploys `assets` from the bound vault into the strategy.
    /// @param assets The asset amount to deploy.
    function deployFunds(uint256 assets) external;

    /// @notice Returns up to `assets` back to the bound vault.
    /// @param assets The requested asset amount.
    /// @return assetsReturned The actual returned asset amount.
    function withdrawToVault(uint256 assets) external returns (uint256 assetsReturned);

    /// @notice Fully unwinds strategy assets back to the bound vault.
    /// @return assetsReturned The actual returned asset amount.
    function withdrawAllToVault() external returns (uint256 assetsReturned);
}
