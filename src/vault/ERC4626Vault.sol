// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626} from "../interfaces/IERC4626.sol";
import {IERC4626VaultStrategy} from "../interfaces/IERC4626VaultStrategy.sol";
import {LibVaultAsset} from "./libraries/LibVaultAsset.sol";
import {LibERC4626VaultStorage} from "./storage/LibERC4626VaultStorage.sol";
import {ERC4626VaultBase} from "./ERC4626VaultBase.sol";

/// @title ERC4626Vault
/// @notice ERC-4626 core vault flows built on top of diamond-ready vault storage.
abstract contract ERC4626Vault is ERC4626VaultBase, IERC4626 {
    /// @notice Thrown when assets input is zero.
    error ERC4626VaultZeroAssets();
    /// @notice Thrown when shares input is zero.
    error ERC4626VaultZeroShares();
    /// @notice Thrown when asset transfer fails.
    error ERC4626VaultAssetTransferFailed();
    /// @notice Thrown when asset transferFrom fails.
    error ERC4626VaultAssetTransferFromFailed();
    /// @notice Thrown when the vault cannot source enough immediate liquidity for a withdrawal flow.
    /// @param requiredAssets The gross asset amount required.
    /// @param availableAssets The currently sourced idle asset amount.
    error ERC4626VaultInsufficientLiquidity(uint256 requiredAssets, uint256 availableAssets);
    /// @notice Thrown when a native vault requires the hosted native entrypoint.
    error ERC4626VaultNativeAssetUseNativeEntrypoint();
    /// @notice Thrown when a native-only entrypoint is used on an ERC-20 vault.
    error ERC4626VaultNativeAssetDisabled();
    /// @notice Thrown when `msg.value` does not match the required native asset amount.
    /// @param supplied Native value supplied by caller.
    /// @param required Native value required by the operation.
    error ERC4626VaultInvalidNativeAssetValue(uint256 supplied, uint256 required);

    /// @notice Returns vault underlying asset token address.
    /// @return The underlying asset token.
    function asset() public view virtual override(ERC4626VaultBase, IERC4626) returns (address) {
        return super.asset();
    }

    /// @notice Returns total assets managed by the vault.
    /// @return The total managed asset amount.
    function totalAssets() public view virtual returns (uint256) {
        // ERC-4626 math intentionally follows managed pricing state instead of raw balance so direct
        // transfers and native surplus cannot change pricing implicitly.
        return _managedAssetsForPricing();
    }

    /// @notice Converts `assets` to shares, rounding down.
    /// @param assets Asset amount to convert.
    /// @return Estimated shares.
    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        return _convertToShares(assets, Rounding.Down);
    }

    /// @notice Converts `shares` to assets, rounding down.
    /// @param shares Share amount to convert.
    /// @return Estimated assets.
    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(shares, Rounding.Down);
    }

    /// @notice Returns max assets `receiver` can deposit.
    /// @param receiver Target receiver.
    /// @return Max asset amount accepted.
    function maxDeposit(address receiver) public view virtual returns (uint256) {
        return receiver == address(0) ? 0 : type(uint256).max;
    }

    /// @notice Returns shares minted by depositing `assets`.
    /// @param assets Asset amount.
    /// @return Estimated shares.
    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return _convertToShares(assets, Rounding.Down);
    }

    /// @notice Deposits `assets` and mints shares to `receiver`.
    /// @param assets Asset amount.
    /// @param receiver Receiver of minted shares.
    /// @return shares Minted shares.
    function deposit(uint256 assets, address receiver) public virtual returns (uint256 shares);

    /// @notice Returns max shares `receiver` can mint.
    /// @param receiver Target receiver.
    /// @return Max shares accepted.
    function maxMint(address receiver) public view virtual returns (uint256) {
        return receiver == address(0) ? 0 : type(uint256).max;
    }

    /// @notice Returns assets required to mint `shares`.
    /// @param shares Share amount.
    /// @return Required assets.
    function previewMint(uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(shares, Rounding.Up);
    }

    /// @notice Mints `shares` to `receiver`.
    /// @param shares Share amount.
    /// @param receiver Receiver of minted shares.
    /// @return assets Deposited assets.
    function mint(uint256 shares, address receiver) public virtual returns (uint256 assets);

    /// @notice Returns max assets `owner` can withdraw.
    /// @param owner Share owner.
    /// @return Max withdrawable assets.
    function maxWithdraw(address owner) public view virtual returns (uint256) {
        if (owner == address(0) || totalAssets() == 0) {
            return 0;
        }
        return _convertToAssets(balanceOf(owner), Rounding.Down);
    }

    /// @notice Returns shares burned by withdrawing `assets`.
    /// @param assets Asset amount.
    /// @return Estimated shares burned.
    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        return _convertToShares(assets, Rounding.Up);
    }

    /// @notice Withdraws `assets` to `receiver` from `owner`.
    /// @param assets Asset amount.
    /// @param receiver Asset receiver.
    /// @param owner Share owner.
    /// @return shares Burned shares.
    function withdraw(uint256 assets, address receiver, address owner) public virtual returns (uint256 shares);

    /// @notice Returns max shares `owner` can redeem.
    /// @param owner Share owner.
    /// @return Max redeemable shares.
    function maxRedeem(address owner) public view virtual returns (uint256) {
        if (owner == address(0) || totalAssets() == 0) {
            return 0;
        }
        return balanceOf(owner);
    }

    /// @notice Returns assets received by redeeming `shares`.
    /// @param shares Share amount.
    /// @return Estimated assets returned.
    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(shares, Rounding.Down);
    }

    /// @notice Redeems `shares` from `owner` to `receiver`.
    /// @param shares Share amount.
    /// @param receiver Asset receiver.
    /// @param owner Share owner.
    /// @return assets Returned assets.
    function redeem(uint256 shares, address receiver, address owner) public virtual returns (uint256 assets);

    /// @notice Transfers shares from caller to `to`.
    /// @param to Recipient account.
    /// @param value Share amount.
    /// @return True when transfer succeeds.
    function transfer(address to, uint256 value) public virtual returns (bool) {
        _transferShares(msg.sender, to, value);
        return true;
    }

    /// @notice Sets allowance from caller to `spender`.
    /// @param spender Approved spender.
    /// @param value New allowance.
    /// @return True when approval succeeds.
    function approve(address spender, uint256 value) public virtual returns (bool) {
        _setAllowance(msg.sender, spender, value);
        return true;
    }

    /// @notice Transfers shares from `from` to `to` using allowance.
    /// @param from Share owner.
    /// @param to Recipient account.
    /// @param value Share amount.
    /// @return True when transfer succeeds.
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _transferShares(from, to, value);
        return true;
    }

    /// @dev Performs ERC-20 transfer and handles optional return values.
    /// @param to Asset receiver.
    /// @param value Asset amount.
    function _safeTransferAsset(address to, uint256 value) internal virtual {
        if (!LibVaultAsset.transferOut(asset(), to, value)) {
            revert ERC4626VaultAssetTransferFailed();
        }
    }

    /// @dev Performs ERC-20 transferFrom and handles optional return values.
    /// @param from Asset sender.
    /// @param to Asset receiver.
    /// @param value Asset amount.
    function _safeTransferFromAsset(address from, address to, uint256 value) internal virtual {
        if (LibVaultAsset.isNativeAsset(asset())) {
            revert ERC4626VaultNativeAssetUseNativeEntrypoint();
        }

        if (!LibVaultAsset.transferIn(asset(), from, to, value)) {
            revert ERC4626VaultAssetTransferFromFailed();
        }
    }

    /// @dev Decreases managed assets for a user exit while ignoring untracked native surplus.
    /// @dev Forced ETH can increase `address(this).balance` without increasing managed assets. When a native
    ///      withdrawal is satisfied from that surplus, book accounting must only burn the tracked portion.
    /// @param assets Gross assets exiting the vault.
    function _decreaseManagedAssetsForAssetExit(uint256 assets) internal {
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        if (LibVaultAsset.isNativeAsset(layout.asset) && layout.strategyDebt != 0) {
            uint256 nativeSurplus =
                LibVaultAsset.balanceOfSelf(layout.asset) - (layout.totalManagedAssets - layout.strategyDebt);
            if (nativeSurplus >= assets) {
                return;
            }

            unchecked {
                assets -= nativeSurplus;
            }
        }

        _decreaseManagedAssets(assets);
    }

    /// @dev Returns the vault's immediately idle asset balance.
    /// @return Immediately held asset balance.
    function _idleAssetBalance() internal view returns (uint256) {
        return LibVaultAsset.balanceOfSelf(asset());
    }

    /// @dev Returns the tracked idle assets available to support exits when a strategy is active.
    /// @dev Raw idle balances can exceed tracked idle because of pending async deposits or direct transfers.
    ///      Exit paths that must preserve strategy-debt accounting use the smaller tracked value instead.
    /// @return Tracked idle assets available for exits.
    function _trackedIdleAssetBalance() internal view returns (uint256) {
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        uint256 actualIdleAssets = _idleAssetBalance();
        uint256 idleBookAssets = layout.totalManagedAssets - layout.strategyDebt;
        return actualIdleAssets < idleBookAssets ? actualIdleAssets : idleBookAssets;
    }

    /// @dev Returns the configured strategy's immediately withdrawable assets.
    /// @return Strategy assets that can be withdrawn immediately.
    function _strategyWithdrawableAssets() internal view returns (uint256) {
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        if (layout.strategyDebt == 0) {
            return 0;
        }

        IERC4626VaultStrategy configuredStrategy = IERC4626VaultStrategy(layout.strategy);
        uint256 liveAssets = configuredStrategy.totalAssets();
        uint256 withdrawableAssets = configuredStrategy.maxWithdrawableAssets();
        return liveAssets < withdrawableAssets ? liveAssets : withdrawableAssets;
    }

    /// @dev Pulls assets from the configured strategy back to the vault.
    /// @param assets Requested withdrawal amount.
    /// @return returnedAssets Assets returned by the strategy call.
    /// @return postCallLiveAssets Strategy live assets reported after the call.
    function _withdrawStrategyAssets(uint256 assets)
        internal
        returns (uint256 returnedAssets, uint256 postCallLiveAssets)
    {
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        IERC4626VaultStrategy configuredStrategy = IERC4626VaultStrategy(layout.strategy);
        returnedAssets = configuredStrategy.withdrawToVault(assets);
        postCallLiveAssets = configuredStrategy.totalAssets();
    }

    /// @dev Fully unwinds assets from the configured strategy back to the vault.
    /// @return returnedAssets Assets returned by the strategy call.
    /// @return postCallLiveAssets Strategy live assets reported after the call.
    function _withdrawAllStrategyAssets() internal returns (uint256 returnedAssets, uint256 postCallLiveAssets) {
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        IERC4626VaultStrategy configuredStrategy = IERC4626VaultStrategy(layout.strategy);
        returnedAssets = configuredStrategy.withdrawAllToVault();
        postCallLiveAssets = configuredStrategy.totalAssets();
    }

    /// @dev Realizes strategy mark-to-market changes into book accounting without moving idle vault assets.
    /// @param liveAssets Strategy live assets to sync into stored debt.
    /// @return previousDebt Strategy debt before syncing.
    function _syncStrategyDebtToLiveAssets(uint256 liveAssets) internal returns (uint256 previousDebt) {
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        previousDebt = layout.strategyDebt;

        if (liveAssets > previousDebt) {
            _increaseManagedAssets(liveAssets - previousDebt);
        } else if (previousDebt > liveAssets) {
            _decreaseManagedAssets(previousDebt - liveAssets);
        }

        layout.strategyDebt = liveAssets;
        layout.strategyReportedAssets = 0;
    }

    /// @dev Reconciles book accounting after a strategy withdrawal-like call that returned assets to the vault.
    /// @param returnedAssets Assets returned to the vault by the strategy call.
    /// @param postCallLiveAssets Strategy live assets reported after the call.
    /// @return previousDebt Strategy debt before reconciliation.
    function _reconcileStrategyWithdrawalAccounting(uint256 returnedAssets, uint256 postCallLiveAssets)
        internal
        returns (uint256 previousDebt)
    {
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        previousDebt = layout.strategyDebt;
        uint256 combinedAssets = returnedAssets + postCallLiveAssets;

        if (combinedAssets > previousDebt) {
            _increaseManagedAssets(combinedAssets - previousDebt);
        } else if (previousDebt > combinedAssets) {
            _decreaseManagedAssets(previousDebt - combinedAssets);
        }

        layout.strategyDebt = postCallLiveAssets;
        layout.strategyReportedAssets = 0;
    }
}
