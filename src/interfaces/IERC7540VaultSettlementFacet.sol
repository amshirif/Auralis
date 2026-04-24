// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "./IERC165.sol";

/// @title IERC7540VaultSettlementFacet
/// @notice Manager-facing settlement surface for hosted ERC-7540 async vault requests.
interface IERC7540VaultSettlementFacet is IERC165 {
    /// @notice Emitted when pending deposit assets are moved into claimable state.
    /// @param controller Controller whose pending deposit was settled.
    /// @param assets Asset amount moved into claimable state.
    /// @param sender Account that settled the request.
    event VaultDepositRequestSettled(address indexed controller, uint256 assets, address indexed sender);

    /// @notice Emitted when pending redeem shares are moved into claimable state.
    /// @param controller Controller whose pending redeem was settled.
    /// @param shares Share amount moved into claimable state.
    /// @param sender Account that settled the request.
    event VaultRedeemRequestSettled(address indexed controller, uint256 shares, address indexed sender);

    /// @notice Returns the pause scope that gates manager settlement entrypoints.
    /// @return The settlement pause scope identifier.
    function ASYNC_SETTLEMENT_SCOPE() external view returns (bytes32);

    /// @notice Moves pending deposit assets into claimable state for `controller`.
    /// @dev Requires `VAULT_MANAGER_ROLE` and an unpaused `ASYNC_SETTLEMENT_SCOPE`.
    /// @param controller Request controller account.
    /// @param assets Asset amount to settle.
    function settleDepositRequest(address controller, uint256 assets) external;

    /// @notice Moves pending redeem shares into claimable state for `controller`.
    /// @dev Requires `VAULT_MANAGER_ROLE` and an unpaused `ASYNC_SETTLEMENT_SCOPE`.
    /// @param controller Request controller account.
    /// @param shares Share amount to settle.
    function settleRedeemRequest(address controller, uint256 shares) external;
}
