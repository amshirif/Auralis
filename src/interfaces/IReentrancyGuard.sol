// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "./IERC165.sol";

/// @title IReentrancyGuard
/// @notice Interface for reentrancy protection module.
interface IReentrancyGuard is IERC165 {
    /// @notice Thrown when a non-reentrant function is called reentrantly.
    error ReentrancyGuardReentrantCall();
    /// @notice Thrown when reentrancy guard is initialized more than once.
    error ReentrancyGuardAlreadyInitialized();

    /// @notice Returns true if the reentrancy guard is currently entered.
    /// @return True when entered.
    function reentrancyGuardEntered() external view returns (bool);
}

