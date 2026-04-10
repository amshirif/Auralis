// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IMultiSendCallOnly
/// @notice Delegatecall helper for atomic call-only batch execution from a wallet context.
interface IMultiSendCallOnly {
    error MultiSendCallOnlyEmptyBatch();
    error MultiSendCallOnlyInvalidEncoding(uint256 offset);
    error MultiSendCallOnlyZeroTarget(uint256 transactionIndex);

    /// @notice Executes concatenated call-only transactions.
    /// @dev Each transaction is encoded as:
    ///      - 20 bytes target
    ///      - 32 bytes value
    ///      - 32 bytes calldata length
    ///      - N bytes calldata
    function multiSend(bytes calldata transactions) external;
}
