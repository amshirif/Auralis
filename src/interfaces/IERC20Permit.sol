// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IERC20Permit
/// @notice EIP-2612 permit extension interface.
interface IERC20Permit {
    /// @notice Sets `value` allowance from `owner` to `spender` using a signed approval.
    /// @param owner Token owner.
    /// @param spender Approved spender.
    /// @param value Allowance amount.
    /// @param deadline Signature expiration timestamp.
    /// @param v Recovery identifier.
    /// @param r Signature component.
    /// @param s Signature component.
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    /// @notice Returns the current permit nonce for `owner`.
    /// @param owner Token owner.
    /// @return The current nonce.
    function nonces(address owner) external view returns (uint256);

    /// @notice Returns the EIP-712 domain separator used for permit signatures.
    /// @return The domain separator.
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
