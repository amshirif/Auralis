// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "./IERC20.sol";

/// @title IWrappedNative
/// @notice Minimal wrapped-native token surface for AMM router integration.
interface IWrappedNative is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 value) external;
}
