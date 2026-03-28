// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title LibERC4626VaultStorage
/// @notice Storage layout for ERC-4626 vault modules (diamond-ready).
library LibERC4626VaultStorage {
    /// @dev Storage slot for vault layout.
    bytes32 internal constant STORAGE_SLOT = keccak256("auralis.erc4626-vault.storage");

    /// @notice Configurable fee settings for vault flows.
    struct FeeConfig {
        uint16 depositFeeBps;
        uint16 withdrawFeeBps;
        address feeRecipient;
    }

    /// @notice Configurable limits for vault flows.
    struct LimitConfig {
        uint128 maxTotalAssets;
        uint128 maxDeposit;
        uint128 maxMint;
        uint128 maxWithdraw;
        uint128 maxRedeem;
    }

    /// @notice Vault storage layout.
    struct Layout {
        bool initialized;
        bool controlPlaneInitialized;
        address asset;
        uint8 decimals;
        string name;
        string symbol;
        uint256 totalSupply;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        uint256 totalManagedAssets;
        FeeConfig fees;
        LimitConfig limits;
        address oracleAdapter;
        address strategy;
        uint256 strategyReportedAssets;
        uint256 strategyDebt;
        bool strategyEmergencyExit;
    }

    /// @notice Returns the storage layout for vault state.
    /// @return l The storage layout pointer.
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
