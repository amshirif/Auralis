// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IERC173
/// @notice Ownership interface used by diamonds and proxy-like deployments.
interface IERC173 {
    /// @notice Emitted when ownership changes.
    /// @param previousOwner The previous owner.
    /// @param newOwner The new owner.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Returns the current owner.
    /// @return contractOwner The current owner.
    function owner() external view returns (address contractOwner);

    /// @notice Transfers ownership to `newOwner`.
    /// @param newOwner The new owner account.
    function transferOwnership(address newOwner) external;
}
