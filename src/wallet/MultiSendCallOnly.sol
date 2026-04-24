// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IMultiSendCallOnly} from "../interfaces/IMultiSendCallOnly.sol";

/// @title MultiSendCallOnly
/// @notice Executes atomic call-only batches when delegatecalled from a wallet.
contract MultiSendCallOnly is IMultiSendCallOnly {
    /// @inheritdoc IMultiSendCallOnly
    function multiSend(bytes calldata transactions) external {
        uint256 totalLength = transactions.length;
        if (totalLength == 0) {
            revert MultiSendCallOnlyEmptyBatch();
        }

        uint256 cursor;
        uint256 txIndex;
        while (cursor < totalLength) {
            if (totalLength - cursor < 84) {
                revert MultiSendCallOnlyInvalidEncoding(cursor);
            }

            address to;
            uint256 value;
            uint256 dataLength;
            assembly {
                let base := add(transactions.offset, cursor)
                to := shr(96, calldataload(base))
                value := calldataload(add(base, 20))
                dataLength := calldataload(add(base, 52))
            }

            if (to == address(0)) {
                revert MultiSendCallOnlyZeroTarget(txIndex);
            }

            cursor += 84;
            if (totalLength - cursor < dataLength) {
                revert MultiSendCallOnlyInvalidEncoding(cursor);
            }

            bytes calldata data = transactions[cursor:cursor + dataLength];
            // slither-disable-next-line arbitrary-send-eth
            (bool success, bytes memory returndata) = to.call{value: value}(data);
            if (!success) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            }

            cursor += dataLength;
            txIndex++;
        }
    }
}
