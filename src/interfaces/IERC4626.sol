// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20Metadata} from "./IERC20Metadata.sol";

/// @title IERC4626
/// @notice ERC-4626 tokenized vault interface.
interface IERC4626 is IERC20Metadata {
    /// @notice Emitted after a successful deposit or mint.
    /// @param caller Account that initiated the deposit or mint.
    /// @param owner Share receiver.
    /// @param assets Asset amount supplied.
    /// @param shares Share amount minted.
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    /// @notice Emitted after a successful withdraw or redeem.
    /// @param caller Account that initiated the withdraw or redeem.
    /// @param receiver Asset receiver.
    /// @param owner Share owner.
    /// @param assets Asset amount withdrawn.
    /// @param shares Share amount burned.
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    /// @notice Returns the vault underlying asset token.
    /// @return The underlying asset token address.
    function asset() external view returns (address);

    /// @notice Returns total assets managed by the vault.
    /// @return The total managed assets amount.
    function totalAssets() external view returns (uint256);

    /// @notice Converts `assets` to vault shares, rounding down.
    /// @param assets Asset amount.
    /// @return Estimated shares.
    function convertToShares(uint256 assets) external view returns (uint256);

    /// @notice Converts `shares` to vault assets, rounding down.
    /// @param shares Share amount.
    /// @return Estimated assets.
    function convertToAssets(uint256 shares) external view returns (uint256);

    /// @notice Returns max assets that `receiver` can deposit.
    /// @param receiver Target receiver.
    /// @return Max deposit amount.
    function maxDeposit(address receiver) external view returns (uint256);

    /// @notice Returns shares minted by depositing `assets`.
    /// @param assets Asset amount.
    /// @return Estimated shares.
    function previewDeposit(uint256 assets) external view returns (uint256);

    /// @notice Deposits `assets` and mints shares to `receiver`.
    /// @param assets Asset amount.
    /// @param receiver Share receiver.
    /// @return Shares minted.
    function deposit(uint256 assets, address receiver) external returns (uint256);

    /// @notice Returns max shares that `receiver` can mint.
    /// @param receiver Target receiver.
    /// @return Max mint amount.
    function maxMint(address receiver) external view returns (uint256);

    /// @notice Returns assets required to mint `shares`.
    /// @param shares Share amount.
    /// @return Estimated asset amount.
    function previewMint(uint256 shares) external view returns (uint256);

    /// @notice Mints `shares` to `receiver`.
    /// @param shares Share amount.
    /// @param receiver Share receiver.
    /// @return Assets deposited.
    function mint(uint256 shares, address receiver) external returns (uint256);

    /// @notice Returns max assets that `owner` can withdraw.
    /// @param owner Token owner.
    /// @return Max withdraw amount.
    function maxWithdraw(address owner) external view returns (uint256);

    /// @notice Returns shares burned by withdrawing `assets`.
    /// @param assets Asset amount.
    /// @return Estimated shares burned.
    function previewWithdraw(uint256 assets) external view returns (uint256);

    /// @notice Withdraws `assets` to `receiver` from `owner`.
    /// @param assets Asset amount.
    /// @param receiver Asset receiver.
    /// @param owner Share owner.
    /// @return Shares burned.
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);

    /// @notice Returns max shares that `owner` can redeem.
    /// @param owner Token owner.
    /// @return Max redeemable shares.
    function maxRedeem(address owner) external view returns (uint256);

    /// @notice Returns assets received by redeeming `shares`.
    /// @param shares Share amount.
    /// @return Estimated assets returned.
    function previewRedeem(uint256 shares) external view returns (uint256);

    /// @notice Redeems `shares` from `owner` to `receiver`.
    /// @param shares Share amount.
    /// @param receiver Asset receiver.
    /// @param owner Share owner.
    /// @return Assets returned.
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
}
