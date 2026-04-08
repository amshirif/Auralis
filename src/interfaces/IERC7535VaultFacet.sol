// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IERC7535VaultFacet
/// @notice Hosted native-asset extension surface for ERC-7535-style vault flows.
interface IERC7535VaultFacet {
    /// @notice Deposits native asset and mints shares to `receiver`.
    /// @param receiver Receiver of minted shares.
    /// @return shares Minted shares.
    function depositNative(address receiver) external payable returns (uint256 shares);

    /// @notice Mints `shares` to `receiver` using native asset funding.
    /// @param shares Share amount.
    /// @param receiver Receiver of minted shares.
    /// @return assets Native assets consumed.
    function mintNative(uint256 shares, address receiver) external payable returns (uint256 assets);
}
