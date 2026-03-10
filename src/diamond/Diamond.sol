// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibDiamond} from "./libraries/LibDiamond.sol";

/// @title Diamond
/// @notice Base EIP-2535 proxy contract with selector routing and owner bootstrap.
contract Diamond {
    /// @notice Thrown when no facet is registered for the requested selector.
    /// @param selector The unresolved selector.
    error DiamondFunctionNotFound(bytes4 selector);

    /// @param initialOwner The account that becomes the initial diamond owner.
    constructor(address initialOwner) {
        LibDiamond.setContractOwner(initialOwner);
    }

    /// @notice Accepts plain ETH transfers.
    receive() external payable {}

    /// @notice Delegates calls to the registered facet for `msg.sig`.
    fallback() external payable {
        address facet = LibDiamond.facetAddress(msg.sig);
        if (facet == address(0)) {
            revert DiamondFunctionNotFound(msg.sig);
        }

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
