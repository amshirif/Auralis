// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title LibVaultFacetConstants
/// @notice Canonical role identifiers for hosted vault facets.
library LibVaultFacetConstants {
    /// @dev Role that can manage vault fees and limits.
    bytes32 internal constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
}
