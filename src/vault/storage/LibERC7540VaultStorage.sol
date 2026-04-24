// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title LibERC7540VaultStorage
/// @notice Storage layout for hosted ERC-7540 async request accounting.
library LibERC7540VaultStorage {
    /// @dev Unique namespaced storage slot; do not reuse or rename without migration review.
    bytes32 internal constant STORAGE_SLOT = keccak256("auralis.erc7540-vault.storage");

    /// @notice Async request accounting layout.
    struct Layout {
        mapping(address => mapping(address => bool)) operatorApprovals;
        mapping(address => uint256) pendingDepositRequestAssets;
        mapping(address => uint256) claimableDepositRequestAssets;
        mapping(address => uint256) pendingRedeemRequestShares;
        mapping(address => uint256) claimableRedeemRequestShares;
        uint256 totalPendingDepositRequestAssets;
        uint256 totalClaimableDepositRequestAssets;
        uint256 totalPendingRedeemRequestShares;
        uint256 totalClaimableRedeemRequestShares;
    }

    /// @notice Returns the storage layout for async request accounting.
    /// @return l The storage layout pointer.
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
