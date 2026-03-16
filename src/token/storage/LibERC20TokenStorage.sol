// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title LibERC20TokenStorage
/// @notice Diamond-safe storage layout for hosted ERC-20 facets.
library LibERC20TokenStorage {
    /// @dev Storage slot for ERC-20 token layout.
    bytes32 internal constant STORAGE_SLOT = keccak256("smart-contracts.token.erc20.storage");

    /// @notice ERC-20 token storage layout.
    struct Layout {
        bool initialized;
        uint8 decimals;
        string name;
        string symbol;
        uint256 totalSupply;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
    }

    /// @notice Returns the ERC-20 storage layout.
    /// @return l The storage layout pointer.
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
