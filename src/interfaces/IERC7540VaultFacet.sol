// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC7540Deposit} from "./IERC7540Deposit.sol";
import {IERC7540Operators} from "./IERC7540Operators.sol";
import {IERC7540Redeem} from "./IERC7540Redeem.sol";

/// @title IERC7540VaultFacet
/// @notice Hosted async-vault extension surface for ERC-7540-style request flows.
interface IERC7540VaultFacet is IERC7540Operators, IERC7540Deposit, IERC7540Redeem {
    /// @notice Emitted when a deposit request is submitted.
    /// @param controller Controller that will own the async claim.
    /// @param owner Asset owner funding the request.
    /// @param requestId Request identifier.
    /// @param sender Account that submitted the request.
    /// @param assets Requested deposit assets.
    event DepositRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 assets
    );

    /// @notice Emitted when a redeem request is submitted.
    /// @param controller Controller that will own the async claim.
    /// @param owner Share owner funding the request.
    /// @param requestId Request identifier.
    /// @param sender Account that submitted the request.
    /// @param shares Requested redeem shares.
    event RedeemRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 shares
    );

    /// @notice Emitted when `controller` updates `operator` approval.
    /// @param controller Account granting or revoking operator authority.
    /// @param operator Operator account.
    /// @param approved True when approved, false when revoked.
    event OperatorSet(address indexed controller, address indexed operator, bool approved);
}
