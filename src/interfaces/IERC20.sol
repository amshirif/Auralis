// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IERC20
/// @notice Minimal ERC-20 token interface.
interface IERC20 {
    /// @notice Emitted when `value` tokens move from `from` to `to`.
    /// @param from Source account.
    /// @param to Recipient account.
    /// @param value Token amount transferred.
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Emitted when `owner` sets `value` allowance for `spender`.
    /// @param owner Allowance owner.
    /// @param spender Allowance spender.
    /// @param value New allowance amount.
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Returns the total token supply.
    /// @return The current total supply.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the token balance for `account`.
    /// @param account The account to query.
    /// @return The token balance.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Transfers `value` tokens to `to`.
    /// @param to Recipient account.
    /// @param value Amount of tokens to transfer.
    /// @return True if the transfer succeeded.
    function transfer(address to, uint256 value) external returns (bool);

    /// @notice Returns allowance from `owner` to `spender`.
    /// @param owner Token owner.
    /// @param spender Approved spender.
    /// @return Remaining allowance amount.
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Sets allowance from caller to `spender`.
    /// @param spender Approved spender.
    /// @param value New allowance amount.
    /// @return True if the approval succeeded.
    function approve(address spender, uint256 value) external returns (bool);

    /// @notice Transfers `value` tokens from `from` to `to` using allowance.
    /// @param from Source account.
    /// @param to Recipient account.
    /// @param value Amount of tokens to transfer.
    /// @return True if the transfer succeeded.
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}
