// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20Metadata} from "./IERC20Metadata.sol";
import {IERC20Permit} from "./IERC20Permit.sol";

/// @title IAMMLpToken
/// @notice ERC-20 + permit surface for the standalone AMM LP token.
interface IAMMLpToken is IERC20Metadata, IERC20Permit {
    /// @notice Reverts when LP token initialization is attempted more than once.
    error AMMLpAlreadyInitialized();
    /// @notice Reverts when LP token state is used before pair initialization.
    error AMMLpNotInitialized();
    /// @notice Reverts when a zero address is used where an account is required.
    error AMMLpZeroAddress();
    /// @notice Reverts when an account cannot cover an LP token transfer or burn.
    /// @param account Account whose balance was checked.
    /// @param available Current LP token balance.
    /// @param required Required LP token amount.
    error AMMLpInsufficientBalance(address account, uint256 available, uint256 required);
    /// @notice Reverts when a spender cannot cover an LP token transferFrom allowance.
    /// @param owner Allowance owner.
    /// @param spender Allowance spender.
    /// @param available Current allowance.
    /// @param required Required allowance.
    error AMMLpInsufficientAllowance(address owner, address spender, uint256 available, uint256 required);
    /// @notice Reverts when a permit deadline has passed.
    /// @param deadline Permit deadline supplied by the signer.
    /// @param currentTimestamp Current block timestamp.
    error AMMLpPermitExpired(uint256 deadline, uint256 currentTimestamp);
    /// @notice Reverts when permit signature recovery does not match the owner.
    /// @param signer Recovered signer.
    /// @param owner Expected owner.
    error AMMLpPermitInvalidSigner(address signer, address owner);
}
