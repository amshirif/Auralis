// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20Metadata} from "./IERC20Metadata.sol";

/// @title IERC20TokenBase
/// @notice Interface for shared ERC-20 token foundation helpers.
interface IERC20TokenBase is IERC20Metadata {
    /// @notice Thrown when the ERC-20 initializer runs more than once.
    error ERC20TokenAlreadyInitialized();
    /// @notice Thrown when mutating helpers run before initialization.
    error ERC20TokenNotInitialized();
    /// @notice Thrown when a required account is the zero address.
    error ERC20TokenZeroAddress();
    /// @notice Thrown when an account balance is insufficient.
    error ERC20TokenInsufficientBalance(address account, uint256 available, uint256 required);
    /// @notice Thrown when allowance is insufficient.
    error ERC20TokenInsufficientAllowance(address owner, address spender, uint256 available, uint256 required);

    /// @notice Returns true when ERC-20 storage is initialized.
    /// @return True if initialized.
    function isErc20Initialized() external view returns (bool);
}
