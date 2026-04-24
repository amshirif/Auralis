// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IMultiSendCallOnly
/// @notice Delegatecall helper for atomic call-only batch execution from a wallet context.
interface IMultiSendCallOnly {
    /// @notice Reverts when the encoded batch has no transactions.
    error MultiSendCallOnlyEmptyBatch();
    /// @notice Reverts when transaction bytes cannot be decoded at `offset`.
    /// @param offset Byte offset where decoding failed.
    error MultiSendCallOnlyInvalidEncoding(uint256 offset);
    /// @notice Reverts when a batch item targets the zero address.
    /// @param transactionIndex Zero-based index of the invalid transaction.
    error MultiSendCallOnlyZeroTarget(uint256 transactionIndex);

    /// @notice Executes concatenated call-only transactions.
    /// @dev Each transaction is encoded as:
    ///      - 20 bytes target
    ///      - 32 bytes value
    ///      - 32 bytes calldata length
    ///      - N bytes calldata
    /// @param transactions Concatenated encoded call-only transactions.
    function multiSend(bytes calldata transactions) external;
}
