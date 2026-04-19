// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC7540Deposit} from "../../interfaces/IERC7540Deposit.sol";
import {IERC7540Operators} from "../../interfaces/IERC7540Operators.sol";
import {IERC4626VaultControls} from "../../interfaces/IERC4626VaultControls.sol";
import {LibDiamond} from "../../diamond/libraries/LibDiamond.sol";
import {ERC4626Vault} from "../ERC4626Vault.sol";
import {ERC4626VaultControlledCore, LibERC4626VaultControlLogic} from "../ERC4626VaultControlLogic.sol";
import {VaultFacetControl} from "../VaultFacetControl.sol";
import {LibERC7540RequestAccounting} from "../libraries/LibERC7540RequestAccounting.sol";
import {LibVaultAsset} from "../libraries/LibVaultAsset.sol";

/// @title ERC7540VaultDepositFacet
/// @notice Hosted async deposit and operator extension facet for ERC-7540-style request flows.
contract ERC7540VaultDepositFacet is ERC4626VaultControlledCore, VaultFacetControl, IERC7540Deposit, IERC7540Operators {
    /// @notice Emitted when a deposit request is submitted.
    event DepositRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 assets
    );

    /// @notice Emitted when `controller` updates `operator` approval.
    event OperatorSet(address indexed controller, address indexed operator, bool approved);

    /// @notice Thrown when an async deposit entrypoint is used before the async deposit extension is active.
    error ERC7540VaultAsyncDepositDisabled();

    /// @notice Thrown when async deposit preview helpers are queried on an async deposit vault.
    error ERC7540VaultAsyncDepositPreviewUnsupported();

    /// @notice Thrown when `sender` is not approved to manage requests for `account`.
    error ERC7540VaultUnauthorizedOperator(address account, address sender);

    /// @notice Returns max assets that can currently be claimed for `receiver`.
    /// @param receiver Receiver of minted shares.
    /// @return assets Max gross claimable asset amount.
    function maxDeposit(address receiver)
        public
        view
        virtual
        override(ERC4626VaultControlledCore)
        returns (uint256 assets)
    {
        if (receiver == address(0) || paused()) {
            return 0;
        }

        return LibERC7540RequestAccounting.claimableDepositRequest(
            LibERC7540RequestAccounting.aggregateRequestId(), msg.sender
        );
    }

    /// @notice Returns max shares that can currently be claimed for `receiver`.
    /// @param receiver Receiver of minted shares.
    /// @return shares Max claimable share amount at the current exchange rate.
    function maxMint(address receiver)
        public
        view
        virtual
        override(ERC4626VaultControlledCore)
        returns (uint256 shares)
    {
        if (receiver == address(0) || paused()) {
            return 0;
        }

        uint256 claimableAssets = LibERC7540RequestAccounting.claimableDepositRequest(
            LibERC7540RequestAccounting.aggregateRequestId(), msg.sender
        );
        (uint256 netAssets,) = LibERC4626VaultControlLogic.netAfterDepositFee(claimableAssets);
        return _convertToShares(netAssets, Rounding.Down);
    }

    /// @notice Returns shares for an async deposit preview.
    /// @param assets Asset amount.
    /// @return shares Preview share amount.
    function previewDeposit(uint256 assets) public view virtual override(ERC4626VaultControlledCore) returns (uint256) {
        assets;
        revert ERC7540VaultAsyncDepositPreviewUnsupported();
    }

    /// @notice Returns assets for an async mint preview.
    /// @param shares Share amount.
    /// @return assets Preview asset amount.
    function previewMint(uint256 shares) public view virtual override(ERC4626VaultControlledCore) returns (uint256) {
        shares;
        revert ERC7540VaultAsyncDepositPreviewUnsupported();
    }

    /// @notice Claims asynchronous deposit assets into shares for `receiver`.
    /// @param assets Claimable gross asset amount.
    /// @param receiver Share receiver.
    /// @return shares Minted share amount.
    function deposit(uint256 assets, address receiver)
        public
        virtual
        override(ERC4626Vault)
        whenNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        return _claimAsyncDeposit(assets, receiver, msg.sender);
    }

    /// @notice Claims asynchronous deposit assets into an exact share amount for `receiver`.
    /// @param shares Target share amount.
    /// @param receiver Share receiver.
    /// @return assets Consumed claimable gross asset amount.
    function mint(uint256 shares, address receiver)
        public
        virtual
        override(ERC4626Vault)
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        return _claimAsyncMint(shares, receiver, msg.sender);
    }

    /// @notice Locks `assets` for an asynchronous deposit request.
    /// @param assets Requested asset amount.
    /// @param controller Request controller account.
    /// @param owner Asset owner account.
    /// @return requestId Canonical aggregated request id.
    function requestDeposit(uint256 assets, address controller, address owner)
        public
        virtual
        whenNotPaused
        nonReentrant
        returns (uint256 requestId)
    {
        _requireInitialized();
        _requireAsyncDepositEnabled();
        _requireNonZeroAddress(controller);
        _requireNonZeroAddress(owner);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        if (msg.sender != owner && !LibERC7540RequestAccounting.isOperator(owner, msg.sender)) {
            revert ERC7540VaultUnauthorizedOperator(owner, msg.sender);
        }

        uint256 maxAssets = _maxRequestDepositAssets(controller);
        if (assets > maxAssets) {
            revert IERC4626VaultControls.ERC4626VaultDepositLimitExceeded(assets, maxAssets);
        }

        requestId = LibERC7540RequestAccounting.aggregateRequestId();
        _safeTransferFromAsset(owner, address(this), assets);
        LibERC7540RequestAccounting.increasePendingDeposit(controller, assets);

        emit DepositRequest(controller, owner, requestId, msg.sender, assets);
    }

    /// @notice Returns pending deposit-request assets for `controller`.
    /// @param requestId Request discriminator.
    /// @param controller Request controller account.
    /// @return assets Pending gross asset amount.
    function pendingDepositRequest(uint256 requestId, address controller) public view virtual returns (uint256 assets) {
        return LibERC7540RequestAccounting.pendingDepositRequest(requestId, controller);
    }

    /// @notice Returns claimable deposit-request assets for `controller`.
    /// @param requestId Request discriminator.
    /// @param controller Request controller account.
    /// @return assets Claimable gross asset amount.
    function claimableDepositRequest(uint256 requestId, address controller)
        public
        view
        virtual
        returns (uint256 assets)
    {
        return LibERC7540RequestAccounting.claimableDepositRequest(requestId, controller);
    }

    /// @notice Returns whether `operator` is approved for `controller`.
    /// @param controller Request controller account.
    /// @param operator Operator account.
    /// @return status True when approved.
    function isOperator(address controller, address operator) public view virtual returns (bool status) {
        return LibERC7540RequestAccounting.isOperator(controller, operator);
    }

    /// @notice Grants or revokes operator approval for the caller's requests.
    /// @param operator Operator account.
    /// @param approved Approval status.
    /// @return success True when stored.
    function setOperator(address operator, bool approved) public virtual returns (bool success) {
        LibERC7540RequestAccounting.setOperator(msg.sender, operator, approved);
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    /// @notice Claims asynchronous deposit assets into shares for `receiver`.
    /// @param assets Claimable gross asset amount.
    /// @param receiver Share receiver.
    /// @param controller Request controller account.
    /// @return shares Minted share amount.
    function deposit(uint256 assets, address receiver, address controller)
        public
        virtual
        whenNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        return _claimAsyncDeposit(assets, receiver, controller);
    }

    /// @notice Claims asynchronous deposit assets into an exact share amount for `receiver`.
    /// @param shares Target share amount.
    /// @param receiver Share receiver.
    /// @param controller Request controller account.
    /// @return assets Consumed claimable gross asset amount.
    function mint(uint256 shares, address receiver, address controller)
        public
        virtual
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        return _claimAsyncMint(shares, receiver, controller);
    }

    function _vaultOperationsPaused() internal view virtual override returns (bool) {
        return paused();
    }

    function _asyncDepositModeEnabled() internal view virtual returns (bool) {
        return !LibVaultAsset.isNativeAsset(ERC4626Vault.asset())
            && LibDiamond.selectorExists(IERC7540Deposit.requestDeposit.selector);
    }

    function _maxRequestDepositAssets(address controller) internal view returns (uint256 maxAssets) {
        if (controller == address(0) || paused()) {
            return 0;
        }

        maxAssets = type(uint256).max;
        (uint128 maxTotalAssets_, uint128 maxDeposit_,,,) = LibERC4626VaultControlLogic.limitConfig();

        if (maxDeposit_ != 0) {
            maxAssets = maxDeposit_;
        }

        if (maxTotalAssets_ != 0) {
            uint256 currentCommittedAssets = totalAssets()
                + LibERC7540RequestAccounting.totalPendingDepositRequestAssets()
                + LibERC7540RequestAccounting.totalClaimableDepositRequestAssets();

            if (currentCommittedAssets >= maxTotalAssets_) {
                return 0;
            }

            uint256 remainingAssets = maxTotalAssets_ - currentCommittedAssets;
            if (remainingAssets < maxAssets) {
                maxAssets = remainingAssets;
            }
        }
    }

    function _claimAsyncDeposit(uint256 assets, address receiver, address controller)
        internal
        returns (uint256 shares)
    {
        _requireInitialized();
        _requireAsyncDepositEnabled();
        _requireNonZeroAddress(receiver);
        _requireNonZeroAddress(controller);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        _requireControllerOrOperator(controller);

        (uint256 netAssets, uint256 feeAssets) = LibERC4626VaultControlLogic.netAfterDepositFee(assets);
        shares = _convertToShares(netAssets, Rounding.Down);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        LibERC7540RequestAccounting.consumeClaimableDeposit(controller, assets);
        _increaseManagedAssets(netAssets);
        _mintShares(receiver, shares);
        _payoutFee(feeAssets);

        emit Deposit(controller, receiver, assets, shares);
    }

    function _claimAsyncMint(uint256 shares, address receiver, address controller) internal returns (uint256 assets) {
        _requireInitialized();
        _requireAsyncDepositEnabled();
        _requireNonZeroAddress(receiver);
        _requireNonZeroAddress(controller);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        _requireControllerOrOperator(controller);

        uint256 netAssets = _convertToAssets(shares, Rounding.Up);
        if (netAssets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        assets = LibERC4626VaultControlLogic.grossUpForDepositFee(netAssets);
        uint256 feeAssets = assets - netAssets;

        LibERC7540RequestAccounting.consumeClaimableDeposit(controller, assets);
        _increaseManagedAssets(netAssets);
        _mintShares(receiver, shares);
        _payoutFee(feeAssets);

        emit Deposit(controller, receiver, assets, shares);
    }

    function _requireAsyncDepositEnabled() internal view {
        if (!_asyncDepositModeEnabled()) {
            revert ERC7540VaultAsyncDepositDisabled();
        }
    }

    function _requireControllerOrOperator(address controller) internal view {
        if (msg.sender != controller && !LibERC7540RequestAccounting.isOperator(controller, msg.sender)) {
            revert ERC7540VaultUnauthorizedOperator(controller, msg.sender);
        }
    }
}
