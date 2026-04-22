// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IERC7540Redeem
/// @notice ERC-7540 asynchronous redeem request surface.
interface IERC7540Redeem {
    /// @notice Locks `shares` and creates an asynchronous redeem request.
    /// @param shares Share amount.
    /// @param controller Request controller account.
    /// @param owner Share owner account.
    /// @return requestId Request discriminator.
    function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256 requestId);

    /// @notice Returns the pending redeem-request shares for `controller` and `requestId`.
    /// @param requestId Request discriminator.
    /// @param controller Request controller account.
    /// @return shares Pending share amount.
    function pendingRedeemRequest(uint256 requestId, address controller) external view returns (uint256 shares);

    /// @notice Returns the claimable redeem-request shares for `controller` and `requestId`.
    /// @param requestId Request discriminator.
    /// @param controller Request controller account.
    /// @return shares Claimable share amount.
    function claimableRedeemRequest(uint256 requestId, address controller) external view returns (uint256 shares);
}
