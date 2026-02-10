// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IERC165
/// @notice Interface detection standard.
interface IERC165 {
    /// @notice Query if a contract implements an interface.
    /// @param interfaceId The interface identifier, as specified in ERC-165.
    /// @return True if the contract implements `interfaceId`.
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
