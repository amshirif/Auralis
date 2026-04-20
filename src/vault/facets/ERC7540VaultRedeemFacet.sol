// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC7540Redeem} from "../../interfaces/IERC7540Redeem.sol";
import {IERC4626VaultControls} from "../../interfaces/IERC4626VaultControls.sol";
import {LibDiamond} from "../../diamond/libraries/LibDiamond.sol";
import {ERC4626Vault} from "../ERC4626Vault.sol";
import {ERC4626VaultControlledCore, LibERC4626VaultControlLogic} from "../ERC4626VaultControlLogic.sol";
import {VaultFacetControl} from "../VaultFacetControl.sol";
import {LibERC7540RequestAccounting} from "../libraries/LibERC7540RequestAccounting.sol";
import {LibVaultAsset} from "../libraries/LibVaultAsset.sol";

/// @title ERC7540VaultRedeemFacet
/// @notice Hosted async redeem extension facet for ERC-7540-style request flows.
contract ERC7540VaultRedeemFacet is ERC4626VaultControlledCore, VaultFacetControl, IERC7540Redeem {
    /// @notice Emitted when a redeem request is submitted.
    event RedeemRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 shares
    );

    /// @notice Thrown when an async redeem entrypoint is used before the async redeem extension is active.
    error ERC7540VaultAsyncRedeemDisabled();

    /// @notice Thrown when async redeem preview helpers are queried on an async redeem vault.
    error ERC7540VaultAsyncRedeemPreviewUnsupported();

    /// @notice Thrown when `sender` is not approved to manage requests for `account`.
    error ERC7540VaultUnauthorizedOperator(address account, address sender);

    /// @notice Returns max assets that can currently be claimed for `controller`.
    /// @param controller Request controller account.
    /// @return assets Max net asset amount claimable at the current exchange rate.
    function maxWithdraw(address controller)
        public
        view
        virtual
        override(ERC4626VaultControlledCore)
        returns (uint256 assets)
    {
        if (controller == address(0) || paused()) {
            return 0;
        }

        uint256 claimableShares = LibERC7540RequestAccounting.claimableRedeemRequest(
            LibERC7540RequestAccounting.aggregateRequestId(), controller
        );
        uint256 grossAssets = _convertToAssets(claimableShares, Rounding.Down);
        (assets,) = LibERC4626VaultControlLogic.withdrawNetFromGross(grossAssets);
    }

    /// @notice Returns max shares that can currently be claimed for `controller`.
    /// @param controller Request controller account.
    /// @return shares Max claimable redeem share amount.
    function maxRedeem(address controller)
        public
        view
        virtual
        override(ERC4626VaultControlledCore)
        returns (uint256 shares)
    {
        if (controller == address(0) || paused()) {
            return 0;
        }

        return LibERC7540RequestAccounting.claimableRedeemRequest(
            LibERC7540RequestAccounting.aggregateRequestId(), controller
        );
    }

    /// @notice Returns shares for an async withdraw preview.
    /// @param assets Asset amount.
    /// @return shares Preview share amount.
    function previewWithdraw(uint256 assets)
        public
        view
        virtual
        override(ERC4626VaultControlledCore)
        returns (uint256)
    {
        assets;
        revert ERC7540VaultAsyncRedeemPreviewUnsupported();
    }

    /// @notice Returns assets for an async redeem preview.
    /// @param shares Share amount.
    /// @return assets Preview asset amount.
    function previewRedeem(uint256 shares) public view virtual override(ERC4626VaultControlledCore) returns (uint256) {
        shares;
        revert ERC7540VaultAsyncRedeemPreviewUnsupported();
    }

    /// @notice Claims asynchronous redeem shares into an exact asset amount for `receiver`.
    /// @param assets Target net asset amount.
    /// @param receiver Asset receiver.
    /// @param controller Request controller account.
    /// @return shares Consumed claimable share amount.
    function withdraw(uint256 assets, address receiver, address controller)
        public
        virtual
        override(ERC4626Vault)
        whenNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        _requireInitialized();
        _requireAsyncRedeemEnabled();
        _requireNonZeroAddress(receiver);
        _requireNonZeroAddress(controller);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        _requireControllerOrOperator(controller);

        uint256 maxAssets = maxWithdraw(controller);
        if (assets > maxAssets) {
            revert IERC4626VaultControls.ERC4626VaultWithdrawLimitExceeded(assets, maxAssets);
        }

        (uint256 grossAssets, uint256 feeAssets) = LibERC4626VaultControlLogic.withdrawGrossFromNet(assets);
        _sourceStrategyLiquidity(grossAssets);

        uint256 availableIdleAssets = _idleAssetBalance();
        if (grossAssets > availableIdleAssets) {
            revert ERC4626VaultInsufficientLiquidity(grossAssets, availableIdleAssets);
        }

        shares = _convertToShares(grossAssets, Rounding.Up);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        LibERC7540RequestAccounting.consumeClaimableRedeem(controller, shares);
        _burnShares(address(this), shares);
        _decreaseManagedAssetsForAssetExit(grossAssets);
        _safeTransferAsset(receiver, assets);
        _payoutFee(feeAssets);

        emit Withdraw(msg.sender, receiver, controller, assets, shares);
    }

    /// @notice Claims asynchronous redeem shares into assets for `receiver`.
    /// @param shares Claimable share amount.
    /// @param receiver Asset receiver.
    /// @param controller Request controller account.
    /// @return assets Returned net asset amount.
    function redeem(uint256 shares, address receiver, address controller)
        public
        virtual
        override(ERC4626Vault)
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        _requireInitialized();
        _requireAsyncRedeemEnabled();
        _requireNonZeroAddress(receiver);
        _requireNonZeroAddress(controller);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        _requireControllerOrOperator(controller);

        uint256 maxShares = maxRedeem(controller);
        if (shares > maxShares) {
            revert IERC4626VaultControls.ERC4626VaultRedeemLimitExceeded(shares, maxShares);
        }

        uint256 grossAssets = _convertToAssets(shares, Rounding.Down);
        _sourceStrategyLiquidity(grossAssets);

        uint256 availableIdleAssets = _idleAssetBalance();
        if (grossAssets > availableIdleAssets) {
            revert ERC4626VaultInsufficientLiquidity(grossAssets, availableIdleAssets);
        }

        uint256 feeAssets;
        (assets, feeAssets) = LibERC4626VaultControlLogic.withdrawNetFromGross(grossAssets);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        LibERC7540RequestAccounting.consumeClaimableRedeem(controller, shares);
        _burnShares(address(this), shares);
        _decreaseManagedAssetsForAssetExit(grossAssets);
        _safeTransferAsset(receiver, assets);
        _payoutFee(feeAssets);

        emit Withdraw(msg.sender, receiver, controller, assets, shares);
    }

    /// @notice Locks `shares` for an asynchronous redeem request.
    /// @param shares Requested share amount.
    /// @param controller Request controller account.
    /// @param owner Share owner account.
    /// @return requestId Canonical aggregated request id.
    function requestRedeem(uint256 shares, address controller, address owner)
        public
        virtual
        whenNotPaused
        nonReentrant
        returns (uint256 requestId)
    {
        _requireInitialized();
        _requireAsyncRedeemEnabled();
        _requireNonZeroAddress(controller);
        _requireNonZeroAddress(owner);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        uint256 maxShares = _maxRequestRedeemShares(owner);
        if (shares > maxShares) {
            revert IERC4626VaultControls.ERC4626VaultRedeemLimitExceeded(shares, maxShares);
        }

        if (msg.sender != owner && !LibERC7540RequestAccounting.isOperator(owner, msg.sender)) {
            _spendAllowance(owner, msg.sender, shares);
        }

        requestId = LibERC7540RequestAccounting.aggregateRequestId();
        _transferShares(owner, address(this), shares);
        LibERC7540RequestAccounting.increasePendingRedeem(controller, shares);

        emit RedeemRequest(controller, owner, requestId, msg.sender, shares);
    }

    /// @notice Returns pending redeem-request shares for `controller`.
    /// @param requestId Request discriminator.
    /// @param controller Request controller account.
    /// @return shares Pending share amount.
    function pendingRedeemRequest(uint256 requestId, address controller) public view virtual returns (uint256 shares) {
        return LibERC7540RequestAccounting.pendingRedeemRequest(requestId, controller);
    }

    /// @notice Returns claimable redeem-request shares for `controller`.
    /// @param requestId Request discriminator.
    /// @param controller Request controller account.
    /// @return shares Claimable share amount.
    function claimableRedeemRequest(uint256 requestId, address controller)
        public
        view
        virtual
        returns (uint256 shares)
    {
        return LibERC7540RequestAccounting.claimableRedeemRequest(requestId, controller);
    }

    function _vaultOperationsPaused() internal view virtual override returns (bool) {
        return paused();
    }

    function _asyncRedeemModeEnabled() internal view virtual returns (bool) {
        return !LibVaultAsset.isNativeAsset(ERC4626Vault.asset())
            && LibDiamond.selectorExists(IERC7540Redeem.requestRedeem.selector);
    }

    function _maxRequestRedeemShares(address owner) internal view returns (uint256 maxShares) {
        if (owner == address(0) || paused()) {
            return 0;
        }

        maxShares = balanceOf(owner);
        (,,,, uint128 maxRedeem_) = LibERC4626VaultControlLogic.limitConfig();
        if (maxRedeem_ != 0 && maxRedeem_ < maxShares) {
            maxShares = maxRedeem_;
        }
    }

    function _sourceStrategyLiquidity(uint256 requiredGrossAssets) internal {
        if (requiredGrossAssets == 0) {
            return;
        }

        uint256 idleAssets = _idleAssetBalance();
        while (idleAssets < requiredGrossAssets) {
            uint256 strategyLiquidity = _strategyWithdrawableAssets();
            if (strategyLiquidity == 0) {
                break;
            }

            uint256 requestedAssets = requiredGrossAssets - idleAssets;
            if (requestedAssets > strategyLiquidity) {
                requestedAssets = strategyLiquidity;
            }

            (uint256 returnedAssets, uint256 postCallLiveAssets) = _withdrawStrategyAssets(requestedAssets);
            _reconcileStrategyWithdrawalAccounting(returnedAssets, postCallLiveAssets);

            uint256 nextIdleAssets = _idleAssetBalance();
            if (nextIdleAssets <= idleAssets) {
                break;
            }

            idleAssets = nextIdleAssets;
        }
    }

    function _requireAsyncRedeemEnabled() internal view {
        if (!_asyncRedeemModeEnabled()) {
            revert ERC7540VaultAsyncRedeemDisabled();
        }
    }

    function _requireControllerOrOperator(address controller) internal view {
        if (msg.sender != controller && !LibERC7540RequestAccounting.isOperator(controller, msg.sender)) {
            revert ERC7540VaultUnauthorizedOperator(controller, msg.sender);
        }
    }
}
