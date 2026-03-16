// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title LibTokenFacetConstants
/// @notice Shared role and pause-scope identifiers for hosted token facets.
library LibTokenFacetConstants {
    /// @notice Role for token-level administrative configuration.
    bytes32 internal constant TOKEN_ADMIN_ROLE = keccak256("TOKEN_ADMIN_ROLE");
    /// @notice Role for ERC-20 mint operations.
    bytes32 internal constant ERC20_MINTER_ROLE = keccak256("ERC20_MINTER_ROLE");
    /// @notice Role for ERC-20 burn operations.
    bytes32 internal constant ERC20_BURNER_ROLE = keccak256("ERC20_BURNER_ROLE");
    /// @notice Role for ERC-721 mint operations.
    bytes32 internal constant ERC721_MINTER_ROLE = keccak256("ERC721_MINTER_ROLE");
    /// @notice Role for ERC-721 burn operations.
    bytes32 internal constant ERC721_BURNER_ROLE = keccak256("ERC721_BURNER_ROLE");
    /// @notice Role for ERC-721 metadata updates.
    bytes32 internal constant ERC721_METADATA_ROLE = keccak256("ERC721_METADATA_ROLE");

    /// @notice Pause scope for ERC-20 transfers.
    bytes32 internal constant ERC20_TRANSFER_SCOPE = keccak256("ERC20_TRANSFER_SCOPE");
    /// @notice Pause scope for ERC-20 approvals.
    bytes32 internal constant ERC20_APPROVAL_SCOPE = keccak256("ERC20_APPROVAL_SCOPE");
    /// @notice Pause scope for ERC-721 transfers.
    bytes32 internal constant ERC721_TRANSFER_SCOPE = keccak256("ERC721_TRANSFER_SCOPE");
    /// @notice Pause scope for ERC-721 approvals.
    bytes32 internal constant ERC721_APPROVAL_SCOPE = keccak256("ERC721_APPROVAL_SCOPE");
}
