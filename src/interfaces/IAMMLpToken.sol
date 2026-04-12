// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20Metadata} from "./IERC20Metadata.sol";
import {IERC20Permit} from "./IERC20Permit.sol";

/// @title IAMMLpToken
/// @notice ERC-20 + permit surface for the standalone AMM LP token.
interface IAMMLpToken is IERC20Metadata, IERC20Permit {
    error AMMLpAlreadyInitialized();
    error AMMLpNotInitialized();
    error AMMLpZeroAddress();
    error AMMLpInsufficientBalance(address account, uint256 available, uint256 required);
    error AMMLpInsufficientAllowance(address owner, address spender, uint256 available, uint256 required);
    error AMMLpPermitExpired(uint256 deadline, uint256 currentTimestamp);
    error AMMLpPermitInvalidSigner(address signer, address owner);
}
