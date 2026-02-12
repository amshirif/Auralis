// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IReentrancyGuard} from "../interfaces/IReentrancyGuard.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {LibReentrancyGuardStorage} from "./storage/LibReentrancyGuardStorage.sol";

/// @title ReentrancyGuard
/// @notice Reentrancy protection module with diamond-ready storage.
/// @dev Uses a status flag to block nested entry to `nonReentrant` functions.
abstract contract ReentrancyGuard is IReentrancyGuard {
    /// @dev Reentrancy status for a function call not currently entered.
    uint256 internal constant NOT_ENTERED = 1;
    /// @dev Reentrancy status for a function call currently entered.
    uint256 internal constant ENTERED = 2;

    constructor() {
        _initializeReentrancyGuard();
    }

    /// @dev Prevents a function from being called reentrantly.
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    /// @notice Returns true if the reentrancy guard is currently entered.
    /// @return True when entered.
    function reentrancyGuardEntered() public view returns (bool) {
        return LibReentrancyGuardStorage.layout().status == ENTERED;
    }

    /// @notice Returns true if this contract implements `interfaceId`.
    /// @param interfaceId The interface identifier.
    /// @return True if the interface is supported.
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IReentrancyGuard).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /// @dev Initializes reentrancy guard storage (diamond-ready).
    function _initializeReentrancyGuard() internal {
        LibReentrancyGuardStorage.Layout storage layout = LibReentrancyGuardStorage.layout();
        if (layout.initialized) {
            revert ReentrancyGuardAlreadyInitialized();
        }
        layout.initialized = true;
        layout.status = NOT_ENTERED;
    }

    /// @dev Reverts when the guard is already entered.
    function _nonReentrantBefore() internal {
        LibReentrancyGuardStorage.Layout storage layout = LibReentrancyGuardStorage.layout();
        if (layout.status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        layout.status = ENTERED;
    }

    /// @dev Resets the guard status after execution.
    function _nonReentrantAfter() internal {
        LibReentrancyGuardStorage.layout().status = NOT_ENTERED;
    }
}

