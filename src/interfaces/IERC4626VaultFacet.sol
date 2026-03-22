// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626} from "./IERC4626.sol";

/// @title IERC4626VaultFacet
/// @notice Hosted ERC-4626 vault core surface for future diamond facets.
interface IERC4626VaultFacet is IERC4626 {
    /// @notice Returns true when vault storage is initialized.
    /// @return True if initialized.
    function isVaultInitialized() external view returns (bool);

    /// @notice Returns currently managed asset accounting amount.
    /// @return The tracked managed asset amount.
    function totalManagedAssets() external view returns (uint256);

    /// @notice Initializes the hosted vault core and shared control plane.
    /// @param vaultAsset Underlying vault asset token.
    /// @param vaultName ERC-20 share token name.
    /// @param vaultSymbol ERC-20 share token symbol.
    /// @param admin Account receiving admin, pauser, and vault manager roles.
    function initializeVault(address vaultAsset, string calldata vaultName, string calldata vaultSymbol, address admin)
        external;
}
