// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "./IERC165.sol";

/// @title IERC4626VaultControls
/// @notice Interface for ERC-4626 fee, limit, and safety control extensions.
interface IERC4626VaultControls is IERC165 {
    /// @notice Emitted when fee configuration is updated.
    /// @param previousDepositFeeBps Previous deposit fee in basis points.
    /// @param previousWithdrawFeeBps Previous withdraw fee in basis points.
    /// @param previousFeeRecipient Previous fee recipient.
    /// @param newDepositFeeBps New deposit fee in basis points.
    /// @param newWithdrawFeeBps New withdraw fee in basis points.
    /// @param newFeeRecipient New fee recipient.
    /// @param sender Account that updated fees.
    event VaultFeeConfigUpdated(
        uint16 previousDepositFeeBps,
        uint16 previousWithdrawFeeBps,
        address indexed previousFeeRecipient,
        uint16 newDepositFeeBps,
        uint16 newWithdrawFeeBps,
        address indexed newFeeRecipient,
        address indexed sender
    );

    /// @notice Emitted when limit configuration is updated.
    /// @param maxTotalAssets New total managed-assets cap.
    /// @param maxDeposit New per-call deposit cap.
    /// @param maxMint New per-call mint cap.
    /// @param maxWithdraw New per-call withdraw cap.
    /// @param maxRedeem New per-call redeem cap.
    /// @param sender Account that updated limits.
    event VaultLimitConfigUpdated(
        uint128 maxTotalAssets,
        uint128 maxDeposit,
        uint128 maxMint,
        uint128 maxWithdraw,
        uint128 maxRedeem,
        address indexed sender
    );

    /// @notice Thrown when a fee basis point value is invalid.
    /// @param feeBps Invalid fee basis points.
    error ERC4626VaultInvalidFeeBps(uint16 feeBps);
    /// @notice Thrown when fee recipient is invalid for non-zero fee config.
    error ERC4626VaultInvalidFeeRecipient();
    /// @notice Thrown when deposit input exceeds configured limits.
    /// @param requestedAssets Requested deposit assets.
    /// @param maxAssets Maximum allowed deposit assets.
    error ERC4626VaultDepositLimitExceeded(uint256 requestedAssets, uint256 maxAssets);
    /// @notice Thrown when mint input exceeds configured limits.
    /// @param requestedShares Requested mint shares.
    /// @param maxShares Maximum allowed mint shares.
    error ERC4626VaultMintLimitExceeded(uint256 requestedShares, uint256 maxShares);
    /// @notice Thrown when withdraw input exceeds configured limits.
    /// @param requestedAssets Requested withdraw assets.
    /// @param maxAssets Maximum allowed withdraw assets.
    error ERC4626VaultWithdrawLimitExceeded(uint256 requestedAssets, uint256 maxAssets);
    /// @notice Thrown when redeem input exceeds configured limits.
    /// @param requestedShares Requested redeem shares.
    /// @param maxShares Maximum allowed redeem shares.
    error ERC4626VaultRedeemLimitExceeded(uint256 requestedShares, uint256 maxShares);
    /// @notice Thrown when operation would exceed total-assets cap.
    /// @param currentAssets Current total assets.
    /// @param addedAssets Assets that would be added.
    /// @param maxTotalAssets Maximum allowed total assets.
    error ERC4626VaultTotalAssetsCapExceeded(uint256 currentAssets, uint256 addedAssets, uint256 maxTotalAssets);

    /// @notice Role that can manage vault fees and limits.
    /// @return The vault manager role identifier.
    function VAULT_MANAGER_ROLE() external view returns (bytes32);

    /// @notice Returns current fee configuration.
    /// @return depositFeeBps Deposit fee in basis points.
    /// @return withdrawFeeBps Withdraw fee in basis points.
    /// @return feeRecipient Fee recipient account.
    function feeConfig() external view returns (uint16 depositFeeBps, uint16 withdrawFeeBps, address feeRecipient);

    /// @notice Returns current limit configuration.
    /// @return maxTotalAssets Cap for managed assets (`0` means unlimited).
    /// @return maxDeposit Per-call deposit limit (`0` means unlimited).
    /// @return maxMint Per-call mint limit (`0` means unlimited).
    /// @return maxWithdraw Per-call withdraw limit (`0` means unlimited).
    /// @return maxRedeem Per-call redeem limit (`0` means unlimited).
    function limitConfig()
        external
        view
        returns (uint128 maxTotalAssets, uint128 maxDeposit, uint128 maxMint, uint128 maxWithdraw, uint128 maxRedeem);

    /// @notice Sets fee configuration.
    /// @dev Requires `VAULT_MANAGER_ROLE`.
    /// @param depositFeeBps Deposit fee in basis points.
    /// @param withdrawFeeBps Withdraw fee in basis points.
    /// @param feeRecipient Fee recipient account.
    function setFeeConfig(uint16 depositFeeBps, uint16 withdrawFeeBps, address feeRecipient) external;

    /// @notice Sets limit configuration.
    /// @dev Requires `VAULT_MANAGER_ROLE`.
    /// @param maxTotalAssets Cap for managed assets (`0` means unlimited).
    /// @param maxDeposit Per-call deposit limit (`0` means unlimited).
    /// @param maxMint Per-call mint limit (`0` means unlimited).
    /// @param maxWithdraw Per-call withdraw limit (`0` means unlimited).
    /// @param maxRedeem Per-call redeem limit (`0` means unlimited).
    function setLimitConfig(
        uint128 maxTotalAssets,
        uint128 maxDeposit,
        uint128 maxMint,
        uint128 maxWithdraw,
        uint128 maxRedeem
    ) external;
}
