// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IERC7540Operators
/// @notice ERC-7540 operator approval surface shared by async deposit and redeem vaults.
interface IERC7540Operators {
    /// @notice Returns true when `operator` is approved to manage requests for `controller`.
    /// @param controller Request controller account.
    /// @param operator Candidate operator account.
    /// @return status True when the operator is approved.
    function isOperator(address controller, address operator) external view returns (bool status);

    /// @notice Grants or revokes request-management approval for `operator`.
    /// @param operator Operator account.
    /// @param approved Whether the operator should be approved.
    /// @return success True when the update succeeds.
    function setOperator(address operator, bool approved) external returns (bool success);
}
