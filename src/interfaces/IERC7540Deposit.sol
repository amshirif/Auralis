// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IERC7540Deposit
/// @notice ERC-7540 asynchronous deposit request surface.
interface IERC7540Deposit {
    /// @notice Locks `assets` and creates an asynchronous deposit request.
    /// @param assets Underlying asset amount.
    /// @param controller Request controller account.
    /// @param owner Asset owner account.
    /// @return requestId Request discriminator.
    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256 requestId);

    /// @notice Returns the pending deposit-request assets for `controller` and `requestId`.
    /// @param requestId Request discriminator.
    /// @param controller Request controller account.
    /// @return assets Pending asset amount.
    function pendingDepositRequest(uint256 requestId, address controller) external view returns (uint256 assets);

    /// @notice Returns the claimable deposit-request assets for `controller` and `requestId`.
    /// @param requestId Request discriminator.
    /// @param controller Request controller account.
    /// @return assets Claimable asset amount.
    function claimableDepositRequest(uint256 requestId, address controller) external view returns (uint256 assets);

    /// @notice Claims asynchronous deposit assets into shares for `receiver`.
    /// @param assets Claim asset amount.
    /// @param receiver Share receiver.
    /// @param controller Request controller account.
    /// @return shares Minted shares.
    function deposit(uint256 assets, address receiver, address controller) external returns (uint256 shares);

    /// @notice Claims asynchronous deposit assets by targeting an exact share amount for `receiver`.
    /// @param shares Target share amount.
    /// @param receiver Share receiver.
    /// @param controller Request controller account.
    /// @return assets Consumed claimable asset amount.
    function mint(uint256 shares, address receiver, address controller) external returns (uint256 assets);
}
