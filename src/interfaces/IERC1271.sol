// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IERC1271
/// @notice Contract-based signature validation standard.
interface IERC1271 {
    /// @notice Returns whether `signature` is valid for `hash`.
    /// @param hash Digest to validate.
    /// @param signature Encoded signature payload.
    /// @return magicValue ERC-1271 success magic value when valid.
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4 magicValue);
}
