// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626VaultControls} from "../interfaces/IERC4626VaultControls.sol";
import {ERC4626Vault} from "./ERC4626Vault.sol";
import {LibERC4626VaultStorage} from "./storage/LibERC4626VaultStorage.sol";
import {VaultFacetControl} from "./VaultFacetControl.sol";

/// @title LibERC4626VaultControlLogic
/// @notice Shared fee and limit logic for standalone and hosted vault flows.
library LibERC4626VaultControlLogic {
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    enum FeeRounding {
        Down,
        Up
    }

    /// @notice Reads the current vault fee configuration from storage.
    /// @return depositFeeBps Deposit fee in basis points.
    /// @return withdrawFeeBps Withdraw fee in basis points.
    /// @return recipient Fee recipient account.
    function feeConfig() internal view returns (uint16 depositFeeBps, uint16 withdrawFeeBps, address recipient) {
        LibERC4626VaultStorage.FeeConfig storage fees = LibERC4626VaultStorage.layout().fees;
        return (fees.depositFeeBps, fees.withdrawFeeBps, fees.feeRecipient);
    }

    /// @notice Reads the current vault limit configuration from storage.
    /// @return maxTotalAssets Cap for managed assets, or zero when unlimited.
    /// @return maxDeposit Per-call deposit limit, or zero when unlimited.
    /// @return maxMint Per-call mint limit, or zero when unlimited.
    /// @return maxWithdraw Per-call withdraw limit, or zero when unlimited.
    /// @return maxRedeem Per-call redeem limit, or zero when unlimited.
    function limitConfig()
        internal
        view
        returns (uint128 maxTotalAssets, uint128 maxDeposit, uint128 maxMint, uint128 maxWithdraw, uint128 maxRedeem)
    {
        LibERC4626VaultStorage.LimitConfig storage limits = LibERC4626VaultStorage.layout().limits;
        return (limits.maxTotalAssets, limits.maxDeposit, limits.maxMint, limits.maxWithdraw, limits.maxRedeem);
    }

    /// @notice Reads the configured vault fee recipient.
    /// @return Fee recipient account.
    function feeRecipient() internal view returns (address) {
        return LibERC4626VaultStorage.layout().fees.feeRecipient;
    }

    /// @notice Reverts unless a fee rate is below 100%.
    /// @param feeBps Fee rate in basis points.
    function validateFeeBps(uint16 feeBps) internal pure {
        if (feeBps >= BPS_DENOMINATOR) {
            revert IERC4626VaultControls.ERC4626VaultInvalidFeeBps(feeBps);
        }
    }

    /// @notice Computes net managed assets credited after a deposit fee.
    /// @param assets Gross assets paid by the depositor.
    /// @return netAssets Assets credited to vault managed accounting.
    /// @return feeAssets Assets paid to the configured fee recipient.
    function netAfterDepositFee(uint256 assets) internal view returns (uint256 netAssets, uint256 feeAssets) {
        uint16 depositFeeBps = LibERC4626VaultStorage.layout().fees.depositFeeBps;
        feeAssets = feeOnRaw(assets, depositFeeBps, FeeRounding.Down);
        netAssets = assets - feeAssets;
    }

    /// @notice Computes the smallest gross deposit that credits at least `netAssets`.
    /// @param netAssets Desired net managed assets after deposit fee.
    /// @return grossAssets Gross assets required from the depositor.
    function grossUpForDepositFee(uint256 netAssets) internal view returns (uint256 grossAssets) {
        uint16 depositFeeBps = LibERC4626VaultStorage.layout().fees.depositFeeBps;
        if (depositFeeBps == 0 || netAssets == 0) {
            return netAssets;
        }

        uint256 denominator = BPS_DENOMINATOR - depositFeeBps;
        grossAssets = mulDiv(netAssets, BPS_DENOMINATOR, denominator, FeeRounding.Up);

        (uint256 creditedAssets,) = netAfterDepositFee(grossAssets);
        if (creditedAssets < netAssets) {
            grossAssets += 1;
        }
    }

    /// @notice Computes gross accounting assets needed to withdraw an exact net amount.
    /// @param assets Net assets requested by the receiver.
    /// @return grossAssets Gross assets removed from vault accounting.
    /// @return feeAssets Withdraw fee paid to the configured recipient.
    function withdrawGrossFromNet(uint256 assets) internal view returns (uint256 grossAssets, uint256 feeAssets) {
        uint256 withdrawFeeBps = LibERC4626VaultStorage.layout().fees.withdrawFeeBps;

        // Withdraw gross-up intentionally rounds down so it is inverse with the
        // gross-asset fee basis used by withdrawNetFromGross().
        uint256 denominator;
        // Fee setters validate bps below the denominator, so this subtraction
        // cannot underflow for supported vault state.
        unchecked {
            denominator = BPS_DENOMINATOR - withdrawFeeBps;
        }
        feeAssets = mulDiv(assets, withdrawFeeBps, denominator, FeeRounding.Down);
        grossAssets = assets + feeAssets;
    }

    /// @notice Computes net receiver assets and fees from a gross redeem amount.
    /// @param grossAssets Gross assets removed from vault accounting.
    /// @return netAssets Assets paid to the receiver.
    /// @return feeAssets Withdraw fee paid to the configured recipient.
    function withdrawNetFromGross(uint256 grossAssets) internal view returns (uint256 netAssets, uint256 feeAssets) {
        uint16 withdrawFeeBps = LibERC4626VaultStorage.layout().fees.withdrawFeeBps;
        feeAssets = feeOnRaw(grossAssets, withdrawFeeBps, FeeRounding.Down);
        netAssets = grossAssets - feeAssets;
    }

    /// @notice Computes a raw basis-point fee with the requested rounding direction.
    /// @param assets Asset amount used as fee basis.
    /// @param feeBps Fee rate in basis points.
    /// @param rounding Rounding direction for non-even divisions.
    /// @return Fee amount.
    function feeOnRaw(uint256 assets, uint16 feeBps, FeeRounding rounding) internal pure returns (uint256) {
        if (feeBps == 0 || assets == 0) {
            return 0;
        }

        return mulDiv(assets, feeBps, BPS_DENOMINATOR, rounding);
    }

    /// @notice Multiplies and divides with optional upward rounding.
    /// @param x Multiplicand.
    /// @param y Multiplier.
    /// @param denominator Division denominator.
    /// @param rounding Rounding direction for non-even divisions.
    /// @return result Computed `x * y / denominator`.
    function mulDiv(uint256 x, uint256 y, uint256 denominator, FeeRounding rounding)
        internal
        pure
        returns (uint256 result)
    {
        uint256 product = x * y;
        result = product / denominator;

        if (rounding == FeeRounding.Up && product % denominator != 0) {
            result += 1;
        }
    }
}

/// @title ERC4626VaultControlledCore
/// @notice Shared fee-aware and limit-aware ERC-4626 core behavior.
abstract contract ERC4626VaultControlledCore is ERC4626Vault {
    /// @notice Unconditionally reverts because this facet does not own this ERC-4626 selector.
    /// @dev Exists only to satisfy concrete inheritance; intended calls are routed by the diamond proxy to the owning facet.
    /// @return Never returns.
    function deposit(uint256, address) public virtual override returns (uint256) {
        revert();
    }

    /// @notice Unconditionally reverts because this facet does not own this ERC-4626 selector.
    /// @dev Exists only to satisfy concrete inheritance; intended calls are routed by the diamond proxy to the owning facet.
    /// @return Never returns.
    function mint(uint256, address) public virtual override returns (uint256) {
        revert();
    }

    /// @notice Unconditionally reverts because this facet does not own this ERC-4626 selector.
    /// @dev Exists only to satisfy concrete inheritance; intended calls are routed by the diamond proxy to the owning facet.
    /// @return Never returns.
    function withdraw(uint256, address, address) public virtual override returns (uint256) {
        revert();
    }

    /// @notice Unconditionally reverts because this facet does not own this ERC-4626 selector.
    /// @dev Exists only to satisfy concrete inheritance; intended calls are routed by the diamond proxy to the owning facet.
    /// @return Never returns.
    function redeem(uint256, address, address) public virtual override returns (uint256) {
        revert();
    }

    /// @inheritdoc ERC4626Vault
    /// @dev Returns zero while vault operations are paused, and otherwise applies per-call deposit and total-assets caps.
    ///      The total-assets cap is fee-aware because deposit limits are enforced on net managed assets.
    function maxDeposit(address receiver) public view virtual override returns (uint256) {
        if (receiver == address(0) || _vaultOperationsPaused()) {
            return 0;
        }

        uint256 maxAssets = type(uint256).max;
        (uint128 maxTotalAssets_, uint128 maxDeposit_,,,) = LibERC4626VaultControlLogic.limitConfig();

        if (maxDeposit_ != 0) {
            maxAssets = maxDeposit_;
        }

        if (maxTotalAssets_ != 0) {
            uint256 currentAssets = totalAssets();
            if (currentAssets >= maxTotalAssets_) {
                return 0;
            }

            uint256 remainingAssets = maxTotalAssets_ - currentAssets;
            // The cap is expressed in net managed assets, so the gross deposit ceiling must be fee-aware;
            // otherwise a post-fee credit could exceed the configured cap.
            uint256 capBasedMaxAssets = LibERC4626VaultControlLogic.grossUpForDepositFee(remainingAssets);
            (uint256 creditedAssets,) = LibERC4626VaultControlLogic.netAfterDepositFee(capBasedMaxAssets);
            if (creditedAssets > remainingAssets) {
                capBasedMaxAssets -= 1;
            }
            if (capBasedMaxAssets < maxAssets) {
                maxAssets = capBasedMaxAssets;
            }
        }

        return maxAssets;
    }

    /// @inheritdoc ERC4626Vault
    /// @dev Returns zero while vault operations are paused, and otherwise applies per-call mint and total-assets caps.
    function maxMint(address receiver) public view virtual override returns (uint256) {
        if (receiver == address(0) || _vaultOperationsPaused()) {
            return 0;
        }

        uint256 maxShares = type(uint256).max;
        (uint128 maxTotalAssets_,, uint128 maxMint_,,) = LibERC4626VaultControlLogic.limitConfig();

        if (maxMint_ != 0) {
            maxShares = maxMint_;
        }

        if (maxTotalAssets_ != 0) {
            uint256 currentAssets = totalAssets();
            if (currentAssets >= maxTotalAssets_) {
                return 0;
            }

            uint256 remainingAssets = maxTotalAssets_ - currentAssets;
            uint256 capBasedMaxShares = _convertToShares(remainingAssets, Rounding.Down);
            if (capBasedMaxShares < maxShares) {
                maxShares = capBasedMaxShares;
            }
        }

        return maxShares;
    }

    /// @inheritdoc ERC4626Vault
    /// @dev Returns zero while paused or empty, caps by immediate withdrawable liquidity, then reports net assets after fees
    ///      and any configured per-call withdraw limit.
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        if (owner == address(0) || _vaultOperationsPaused() || totalAssets() == 0) {
            return 0;
        }

        uint256 grossAssets = _convertToAssets(balanceOf(owner), Rounding.Down);
        uint256 liquidityCapAssets = _withdrawLiquidityCapAssets();
        if (grossAssets > liquidityCapAssets) {
            grossAssets = liquidityCapAssets;
        }
        // Withdraw limits are expressed in what the receiver can actually take out, so maxWithdraw uses
        // the net-after-fee view after immediate-liquidity capping rather than gross accounting assets.
        (uint256 netAssets,) = LibERC4626VaultControlLogic.withdrawNetFromGross(grossAssets);

        (,,, uint128 maxWithdraw_,) = LibERC4626VaultControlLogic.limitConfig();
        if (maxWithdraw_ != 0 && netAssets > maxWithdraw_) {
            return maxWithdraw_;
        }

        return netAssets;
    }

    /// @inheritdoc ERC4626Vault
    /// @dev Returns zero while paused or empty, caps shares by immediate withdrawable liquidity, then applies any configured
    ///      per-call redeem limit.
    function maxRedeem(address owner) public view virtual override returns (uint256) {
        if (owner == address(0) || _vaultOperationsPaused() || totalAssets() == 0) {
            return 0;
        }

        uint256 redeemableShares = balanceOf(owner);
        uint256 liquidityCapAssets = _withdrawLiquidityCapAssets();
        if (liquidityCapAssets != type(uint256).max) {
            uint256 liquidityCappedShares = _convertToShares(liquidityCapAssets, Rounding.Down);
            if (liquidityCappedShares < redeemableShares) {
                redeemableShares = liquidityCappedShares;
            }
        }

        (,,,, uint128 maxRedeem_) = LibERC4626VaultControlLogic.limitConfig();
        if (maxRedeem_ != 0 && redeemableShares > maxRedeem_) {
            return maxRedeem_;
        }

        return redeemableShares;
    }

    /// @inheritdoc ERC4626Vault
    /// @dev Deposit preview converts the post-fee net assets that would be credited to managed accounting.
    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        (uint256 netAssets,) = LibERC4626VaultControlLogic.netAfterDepositFee(assets);
        return _convertToShares(netAssets, Rounding.Down);
    }

    /// @inheritdoc ERC4626Vault
    /// @dev Mint preview returns the gross assets required to credit the fee-adjusted net assets for `shares`.
    function previewMint(uint256 shares) public view virtual override returns (uint256) {
        uint256 netAssets = _convertToAssets(shares, Rounding.Up);
        return LibERC4626VaultControlLogic.grossUpForDepositFee(netAssets);
    }

    /// @inheritdoc ERC4626Vault
    /// @dev Withdraw preview returns shares needed to cover the gross accounting assets backing the requested net assets.
    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        (uint256 grossAssets,) = LibERC4626VaultControlLogic.withdrawGrossFromNet(assets);
        return _convertToShares(grossAssets, Rounding.Up);
    }

    /// @inheritdoc ERC4626Vault
    /// @dev Redeem preview converts shares to gross accounting assets first, then subtracts any withdraw fee.
    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        uint256 grossAssets = _convertToAssets(shares, Rounding.Down);
        // Redeem previews follow the same boundary: shares map to gross accounting assets first, then
        // withdraw fees determine the receiver's net assets.
        (uint256 netAssets,) = LibERC4626VaultControlLogic.withdrawNetFromGross(grossAssets);
        return netAssets;
    }

    /// @notice Executes a fee-aware and limit-aware ERC-4626 deposit.
    /// @param assets Gross assets paid by the caller.
    /// @param receiver Account receiving minted shares.
    /// @return shares Shares minted to `receiver`.
    function _depositWithControls(uint256 assets, address receiver) internal returns (uint256 shares) {
        _requireInitialized();
        _requireNonZeroAddress(receiver);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert IERC4626VaultControls.ERC4626VaultDepositLimitExceeded(assets, maxAssets);
        }

        (uint256 netAssets, uint256 feeAssets) = LibERC4626VaultControlLogic.netAfterDepositFee(assets);
        _enforceTotalAssetsCap(netAssets);

        shares = _convertToShares(netAssets, Rounding.Down);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        _safeTransferFromAsset(msg.sender, address(this), assets);
        _increaseManagedAssets(netAssets);
        _mintShares(receiver, shares);
        _payoutFee(feeAssets);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @notice Executes a fee-aware and limit-aware ERC-4626 mint.
    /// @param shares Exact shares to mint.
    /// @param receiver Account receiving minted shares.
    /// @return assets Gross assets paid by the caller.
    function _mintWithControls(uint256 shares, address receiver) internal returns (uint256 assets) {
        _requireInitialized();
        _requireNonZeroAddress(receiver);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert IERC4626VaultControls.ERC4626VaultMintLimitExceeded(shares, maxShares);
        }

        uint256 netAssets = _convertToAssets(shares, Rounding.Up);
        if (netAssets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        assets = LibERC4626VaultControlLogic.grossUpForDepositFee(netAssets);
        uint256 feeAssets = assets - netAssets;

        _enforceTotalAssetsCap(netAssets);
        _safeTransferFromAsset(msg.sender, address(this), assets);
        _increaseManagedAssets(netAssets);
        _mintShares(receiver, shares);
        _payoutFee(feeAssets);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @notice Executes a fee-aware and limit-aware native-asset deposit using `msg.value`.
    /// @param receiver Account receiving minted shares.
    /// @return shares Shares minted to `receiver`.
    function _depositNativeWithControls(address receiver) internal returns (uint256 shares) {
        _requireInitialized();
        _requireNonZeroAddress(receiver);

        uint256 assets = msg.value;
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert IERC4626VaultControls.ERC4626VaultDepositLimitExceeded(assets, maxAssets);
        }

        (uint256 netAssets, uint256 feeAssets) = LibERC4626VaultControlLogic.netAfterDepositFee(assets);
        _enforceTotalAssetsCap(netAssets);

        shares = _convertToShares(netAssets, Rounding.Down);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        _increaseManagedAssets(netAssets);
        _mintShares(receiver, shares);
        _payoutFee(feeAssets);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @notice Executes a fee-aware and limit-aware native-asset mint using exact `msg.value`.
    /// @param shares Exact shares to mint.
    /// @param receiver Account receiving minted shares.
    /// @return assets Required native asset value.
    function _mintNativeWithControls(uint256 shares, address receiver) internal returns (uint256 assets) {
        _requireInitialized();
        _requireNonZeroAddress(receiver);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert IERC4626VaultControls.ERC4626VaultMintLimitExceeded(shares, maxShares);
        }

        uint256 netAssets = _convertToAssets(shares, Rounding.Up);
        if (netAssets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        assets = LibERC4626VaultControlLogic.grossUpForDepositFee(netAssets);
        if (msg.value != assets) {
            revert ERC4626VaultInvalidNativeAssetValue(msg.value, assets);
        }

        uint256 feeAssets = assets - netAssets;

        _enforceTotalAssetsCap(netAssets);
        _increaseManagedAssets(netAssets);
        _mintShares(receiver, shares);
        _payoutFee(feeAssets);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @notice Executes a fee-aware and limit-aware exact-assets withdrawal.
    /// @param assets Net assets paid to `receiver`.
    /// @param receiver Account receiving withdrawn assets.
    /// @param owner Account whose shares are burned.
    /// @return shares Shares burned from `owner`.
    function _withdrawWithControls(uint256 assets, address receiver, address owner) internal returns (uint256 shares) {
        _requireInitialized();
        _requireNonZeroAddress(receiver);
        _requireNonZeroAddress(owner);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert IERC4626VaultControls.ERC4626VaultWithdrawLimitExceeded(assets, maxAssets);
        }

        (uint256 grossAssets, uint256 feeAssets) = LibERC4626VaultControlLogic.withdrawGrossFromNet(assets);
        shares = _convertToShares(grossAssets, Rounding.Up);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _burnShares(owner, shares);
        _decreaseManagedAssetsForAssetExit(grossAssets);
        _safeTransferAsset(receiver, assets);
        _payoutFee(feeAssets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /// @notice Executes a fee-aware and limit-aware exact-shares redeem.
    /// @param shares Shares burned from `owner`.
    /// @param receiver Account receiving withdrawn assets.
    /// @param owner Account whose shares are burned.
    /// @return assets Net assets paid to `receiver`.
    function _redeemWithControls(uint256 shares, address receiver, address owner) internal returns (uint256 assets) {
        _requireInitialized();
        _requireNonZeroAddress(receiver);
        _requireNonZeroAddress(owner);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert IERC4626VaultControls.ERC4626VaultRedeemLimitExceeded(shares, maxShares);
        }

        uint256 grossAssets = _convertToAssets(shares, Rounding.Down);
        uint256 feeAssets;
        (assets, feeAssets) = LibERC4626VaultControlLogic.withdrawNetFromGross(grossAssets);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _burnShares(owner, shares);
        _decreaseManagedAssetsForAssetExit(grossAssets);
        _safeTransferAsset(receiver, assets);
        _payoutFee(feeAssets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /// @notice Reverts if adding managed assets would exceed the configured total-assets cap.
    /// @param additionalAssets Net managed assets about to be added.
    function _enforceTotalAssetsCap(uint256 additionalAssets) internal view {
        (uint128 maxTotalAssets_,,,,) = LibERC4626VaultControlLogic.limitConfig();
        if (maxTotalAssets_ == 0) {
            return;
        }

        uint256 currentAssets = totalAssets();
        uint256 nextAssets = currentAssets + additionalAssets;
        if (nextAssets > maxTotalAssets_) {
            revert IERC4626VaultControls.ERC4626VaultTotalAssetsCapExceeded(
                currentAssets, additionalAssets, maxTotalAssets_
            );
        }
    }

    /// @notice Transfers collected fees to the configured fee recipient.
    /// @param feeAssets Fee amount to pay.
    function _payoutFee(uint256 feeAssets) internal {
        if (feeAssets == 0) {
            return;
        }

        _safeTransferAsset(LibERC4626VaultControlLogic.feeRecipient(), feeAssets);
    }

    /// @notice Returns the immediate gross assets available for withdraw/redeem views.
    /// @return Gross asset liquidity cap, or max uint256 when uncapped.
    function _withdrawLiquidityCapAssets() internal view virtual returns (uint256) {
        return type(uint256).max;
    }

    /// @notice Returns whether vault operations are currently paused for this facet context.
    /// @return True when vault operations should be treated as paused.
    function _vaultOperationsPaused() internal view virtual returns (bool);
}

/// @title ERC4626VaultControlSurface
/// @notice Shared hosted and standalone control-plane surface for vault config and governance.
abstract contract ERC4626VaultControlSurface is VaultFacetControl, IERC4626VaultControls {
    /// @inheritdoc IERC4626VaultControls
    // forge-lint: disable-next-line(mixed-case-function) -- interface role getter name is selector-stable.
    function VAULT_MANAGER_ROLE()
        public
        pure
        virtual
        override(VaultFacetControl, IERC4626VaultControls)
        returns (bytes32)
    {
        return VaultFacetControl.VAULT_MANAGER_ROLE();
    }

    /// @inheritdoc IERC4626VaultControls
    function feeConfig()
        public
        view
        virtual
        override
        returns (uint16 depositFeeBps, uint16 withdrawFeeBps, address feeRecipient)
    {
        return LibERC4626VaultControlLogic.feeConfig();
    }

    /// @inheritdoc IERC4626VaultControls
    function limitConfig()
        public
        view
        virtual
        override
        returns (uint128 maxTotalAssets, uint128 maxDeposit, uint128 maxMint, uint128 maxWithdraw, uint128 maxRedeem)
    {
        return LibERC4626VaultControlLogic.limitConfig();
    }

    /// @inheritdoc IERC4626VaultControls
    /// @dev Requires `VAULT_MANAGER_ROLE`, rejects fee rates at or above 100%, and requires a nonzero recipient
    ///      whenever either fee is nonzero.
    function setFeeConfig(uint16 depositFeeBps, uint16 withdrawFeeBps, address feeRecipient)
        public
        virtual
        override
        onlyRole(VAULT_MANAGER_ROLE())
    {
        LibERC4626VaultControlLogic.validateFeeBps(depositFeeBps);
        LibERC4626VaultControlLogic.validateFeeBps(withdrawFeeBps);

        if ((depositFeeBps != 0 || withdrawFeeBps != 0) && feeRecipient == address(0)) {
            revert IERC4626VaultControls.ERC4626VaultInvalidFeeRecipient();
        }

        (uint16 previousDepositFeeBps, uint16 previousWithdrawFeeBps, address previousFeeRecipient) =
            LibERC4626VaultControlLogic.feeConfig();
        LibERC4626VaultStorage.FeeConfig storage fees = LibERC4626VaultStorage.layout().fees;

        fees.depositFeeBps = depositFeeBps;
        fees.withdrawFeeBps = withdrawFeeBps;
        fees.feeRecipient = feeRecipient;

        emit VaultFeeConfigUpdated(
            previousDepositFeeBps,
            previousWithdrawFeeBps,
            previousFeeRecipient,
            depositFeeBps,
            withdrawFeeBps,
            feeRecipient,
            msg.sender
        );
    }

    /// @inheritdoc IERC4626VaultControls
    function setLimitConfig(
        uint128 maxTotalAssets,
        uint128 maxDeposit,
        uint128 maxMint,
        uint128 maxWithdraw,
        uint128 maxRedeem
    ) public virtual override onlyRole(VAULT_MANAGER_ROLE()) {
        LibERC4626VaultStorage.LimitConfig storage limits = LibERC4626VaultStorage.layout().limits;

        limits.maxTotalAssets = maxTotalAssets;
        limits.maxDeposit = maxDeposit;
        limits.maxMint = maxMint;
        limits.maxWithdraw = maxWithdraw;
        limits.maxRedeem = maxRedeem;

        emit VaultLimitConfigUpdated(maxTotalAssets, maxDeposit, maxMint, maxWithdraw, maxRedeem, msg.sender);
    }
}
