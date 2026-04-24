// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "./IERC20.sol";

/// @title IWrappedNative
/// @notice Minimal wrapped-native token surface for AMM router integration.
interface IWrappedNative is IERC20 {
    /// @notice Wraps native currency into ERC-20 wrapped-native tokens.
    function deposit() external payable;

    /// @notice Burns wrapped-native tokens and releases native currency.
    /// @param value Wrapped-native amount to unwrap.
    function withdraw(uint256 value) external;
}
