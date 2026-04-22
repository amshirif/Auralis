// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LibERC7540VaultStorage} from "../storage/LibERC7540VaultStorage.sol";

/// @title LibERC7540RequestAccounting
/// @notice Shared async request bookkeeping helpers for the hosted vault track.
library LibERC7540RequestAccounting {
    /// @notice Canonical request id for the hosted vault's aggregated request model.
    uint256 internal constant AGGREGATE_REQUEST_ID = 0;

    /// @notice Thrown when a caller attempts to use a non-aggregate request id with the aggregated model.
    /// @param requestId The unsupported request id.
    error ERC7540VaultInvalidRequestId(uint256 requestId);

    /// @notice Thrown when a request update is attempted for the zero controller address.
    error ERC7540VaultZeroController();

    /// @notice Thrown when an operator update uses the zero operator address.
    error ERC7540VaultZeroOperator();

    /// @notice Thrown when a pending deposit move exceeds the controller's pending assets.
    /// @param controller Request controller account.
    /// @param available Available pending asset amount.
    /// @param required Requested asset amount.
    error ERC7540VaultInsufficientPendingDepositRequest(address controller, uint256 available, uint256 required);

    /// @notice Thrown when a claimable deposit consume exceeds the controller's claimable assets.
    /// @param controller Request controller account.
    /// @param available Available claimable asset amount.
    /// @param required Requested asset amount.
    error ERC7540VaultInsufficientClaimableDepositRequest(address controller, uint256 available, uint256 required);

    /// @notice Thrown when a pending redeem move exceeds the controller's pending shares.
    /// @param controller Request controller account.
    /// @param available Available pending share amount.
    /// @param required Requested share amount.
    error ERC7540VaultInsufficientPendingRedeemRequest(address controller, uint256 available, uint256 required);

    /// @notice Thrown when a claimable redeem consume exceeds the controller's claimable shares.
    /// @param controller Request controller account.
    /// @param available Available claimable share amount.
    /// @param required Requested share amount.
    error ERC7540VaultInsufficientClaimableRedeemRequest(address controller, uint256 available, uint256 required);

    /// @notice Returns the hosted vault's aggregated request id.
    /// @return requestId The canonical request id.
    function aggregateRequestId() internal pure returns (uint256 requestId) {
        return AGGREGATE_REQUEST_ID;
    }

    /// @notice Reverts when `requestId` is not supported by the aggregated request model.
    /// @param requestId Request id to validate.
    function requireAggregateRequestId(uint256 requestId) internal pure {
        if (requestId != AGGREGATE_REQUEST_ID) {
            revert ERC7540VaultInvalidRequestId(requestId);
        }
    }

    /// @notice Returns the pending deposit-request assets for `controller` and `requestId`.
    /// @param requestId Request discriminator.
    /// @param controller Request controller account.
    /// @return assets Pending asset amount.
    function pendingDepositRequest(uint256 requestId, address controller) internal view returns (uint256 assets) {
        if (requestId != AGGREGATE_REQUEST_ID || controller == address(0)) {
            return 0;
        }
        return LibERC7540VaultStorage.layout().pendingDepositRequestAssets[controller];
    }

    /// @notice Returns the claimable deposit-request assets for `controller` and `requestId`.
    /// @param requestId Request discriminator.
    /// @param controller Request controller account.
    /// @return assets Claimable asset amount.
    function claimableDepositRequest(uint256 requestId, address controller) internal view returns (uint256 assets) {
        if (requestId != AGGREGATE_REQUEST_ID || controller == address(0)) {
            return 0;
        }
        return LibERC7540VaultStorage.layout().claimableDepositRequestAssets[controller];
    }

    /// @notice Returns the pending redeem-request shares for `controller` and `requestId`.
    /// @param requestId Request discriminator.
    /// @param controller Request controller account.
    /// @return shares Pending share amount.
    function pendingRedeemRequest(uint256 requestId, address controller) internal view returns (uint256 shares) {
        if (requestId != AGGREGATE_REQUEST_ID || controller == address(0)) {
            return 0;
        }
        return LibERC7540VaultStorage.layout().pendingRedeemRequestShares[controller];
    }

    /// @notice Returns the claimable redeem-request shares for `controller` and `requestId`.
    /// @param requestId Request discriminator.
    /// @param controller Request controller account.
    /// @return shares Claimable share amount.
    function claimableRedeemRequest(uint256 requestId, address controller) internal view returns (uint256 shares) {
        if (requestId != AGGREGATE_REQUEST_ID || controller == address(0)) {
            return 0;
        }
        return LibERC7540VaultStorage.layout().claimableRedeemRequestShares[controller];
    }

    /// @notice Returns true when `operator` is approved for `controller`.
    /// @param controller Request controller account.
    /// @param operator Candidate operator account.
    /// @return status True when approved.
    function isOperator(address controller, address operator) internal view returns (bool status) {
        if (controller == address(0) || operator == address(0)) {
            return false;
        }
        return LibERC7540VaultStorage.layout().operatorApprovals[controller][operator];
    }

    /// @notice Updates operator approval for `controller`.
    /// @param controller Request controller account.
    /// @param operator Operator account.
    /// @param approved Approval status to store.
    function setOperator(address controller, address operator, bool approved) internal {
        _requireController(controller);
        if (operator == address(0)) {
            revert ERC7540VaultZeroOperator();
        }

        LibERC7540VaultStorage.layout().operatorApprovals[controller][operator] = approved;
    }

    /// @notice Increases pending deposit assets for `controller`.
    /// @param controller Request controller account.
    /// @param assets Added pending asset amount.
    function increasePendingDeposit(address controller, uint256 assets) internal {
        _requireController(controller);
        if (assets == 0) {
            return;
        }

        LibERC7540VaultStorage.Layout storage layout = LibERC7540VaultStorage.layout();
        layout.pendingDepositRequestAssets[controller] += assets;
        layout.totalPendingDepositRequestAssets += assets;
    }

    /// @notice Moves pending deposit assets into claimable state for `controller`.
    /// @param controller Request controller account.
    /// @param assets Asset amount to move.
    function movePendingDepositToClaimable(address controller, uint256 assets) internal {
        _requireController(controller);
        if (assets == 0) {
            return;
        }

        LibERC7540VaultStorage.Layout storage layout = LibERC7540VaultStorage.layout();
        uint256 available = layout.pendingDepositRequestAssets[controller];
        if (assets > available) {
            revert ERC7540VaultInsufficientPendingDepositRequest(controller, available, assets);
        }

        layout.pendingDepositRequestAssets[controller] = available - assets;
        layout.claimableDepositRequestAssets[controller] += assets;
        layout.totalPendingDepositRequestAssets -= assets;
        layout.totalClaimableDepositRequestAssets += assets;
    }

    /// @notice Consumes claimable deposit assets for `controller`.
    /// @param controller Request controller account.
    /// @param assets Asset amount to consume.
    function consumeClaimableDeposit(address controller, uint256 assets) internal {
        _requireController(controller);
        if (assets == 0) {
            return;
        }

        LibERC7540VaultStorage.Layout storage layout = LibERC7540VaultStorage.layout();
        uint256 available = layout.claimableDepositRequestAssets[controller];
        if (assets > available) {
            revert ERC7540VaultInsufficientClaimableDepositRequest(controller, available, assets);
        }

        layout.claimableDepositRequestAssets[controller] = available - assets;
        layout.totalClaimableDepositRequestAssets -= assets;
    }

    /// @notice Increases pending redeem shares for `controller`.
    /// @param controller Request controller account.
    /// @param shares Added pending share amount.
    function increasePendingRedeem(address controller, uint256 shares) internal {
        _requireController(controller);
        if (shares == 0) {
            return;
        }

        LibERC7540VaultStorage.Layout storage layout = LibERC7540VaultStorage.layout();
        layout.pendingRedeemRequestShares[controller] += shares;
        layout.totalPendingRedeemRequestShares += shares;
    }

    /// @notice Moves pending redeem shares into claimable state for `controller`.
    /// @param controller Request controller account.
    /// @param shares Share amount to move.
    function movePendingRedeemToClaimable(address controller, uint256 shares) internal {
        _requireController(controller);
        if (shares == 0) {
            return;
        }

        LibERC7540VaultStorage.Layout storage layout = LibERC7540VaultStorage.layout();
        uint256 available = layout.pendingRedeemRequestShares[controller];
        if (shares > available) {
            revert ERC7540VaultInsufficientPendingRedeemRequest(controller, available, shares);
        }

        layout.pendingRedeemRequestShares[controller] = available - shares;
        layout.claimableRedeemRequestShares[controller] += shares;
        layout.totalPendingRedeemRequestShares -= shares;
        layout.totalClaimableRedeemRequestShares += shares;
    }

    /// @notice Consumes claimable redeem shares for `controller`.
    /// @param controller Request controller account.
    /// @param shares Share amount to consume.
    function consumeClaimableRedeem(address controller, uint256 shares) internal {
        _requireController(controller);
        if (shares == 0) {
            return;
        }

        LibERC7540VaultStorage.Layout storage layout = LibERC7540VaultStorage.layout();
        uint256 available = layout.claimableRedeemRequestShares[controller];
        if (shares > available) {
            revert ERC7540VaultInsufficientClaimableRedeemRequest(controller, available, shares);
        }

        layout.claimableRedeemRequestShares[controller] = available - shares;
        layout.totalClaimableRedeemRequestShares -= shares;
    }

    /// @notice Returns the aggregate pending deposit-request assets across all controllers.
    /// @return assets Total pending deposit-request assets.
    function totalPendingDepositRequestAssets() internal view returns (uint256 assets) {
        return LibERC7540VaultStorage.layout().totalPendingDepositRequestAssets;
    }

    /// @notice Returns the aggregate claimable deposit-request assets across all controllers.
    /// @return assets Total claimable deposit-request assets.
    function totalClaimableDepositRequestAssets() internal view returns (uint256 assets) {
        return LibERC7540VaultStorage.layout().totalClaimableDepositRequestAssets;
    }

    /// @notice Returns the aggregate pending redeem-request shares across all controllers.
    /// @return shares Total pending redeem-request shares.
    function totalPendingRedeemRequestShares() internal view returns (uint256 shares) {
        return LibERC7540VaultStorage.layout().totalPendingRedeemRequestShares;
    }

    /// @notice Returns the aggregate claimable redeem-request shares across all controllers.
    /// @return shares Total claimable redeem-request shares.
    function totalClaimableRedeemRequestShares() internal view returns (uint256 shares) {
        return LibERC7540VaultStorage.layout().totalClaimableRedeemRequestShares;
    }

    function _requireController(address controller) private pure {
        if (controller == address(0)) {
            revert ERC7540VaultZeroController();
        }
    }
}
