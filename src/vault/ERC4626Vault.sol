// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "../interfaces/IERC20.sol";
import {IERC4626} from "../interfaces/IERC4626.sol";
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

    /// @notice Returns vault underlying asset token address.
    /// @return The underlying asset token.
    function asset() public view virtual override(ERC4626VaultBase, IERC4626) returns (address) {
        return super.asset();
    }

    /// @notice Returns total assets managed by the vault.
    /// @return The total managed asset amount.
    function totalAssets() public view virtual returns (uint256) {
        return totalManagedAssets();
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
    function deposit(uint256 assets, address receiver) public virtual returns (uint256 shares) {
        _requireInitialized();
        _requireNonZeroAddress(receiver);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        shares = previewDeposit(assets);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        _safeTransferFromAsset(msg.sender, address(this), assets);
        _increaseManagedAssets(assets);
        _mintShares(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

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
    function mint(uint256 shares, address receiver) public virtual returns (uint256 assets) {
        _requireInitialized();
        _requireNonZeroAddress(receiver);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        assets = previewMint(shares);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        _safeTransferFromAsset(msg.sender, address(this), assets);
        _increaseManagedAssets(assets);
        _mintShares(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @notice Returns max assets `owner` can withdraw.
    /// @param owner Share owner.
    /// @return Max withdrawable assets.
    function maxWithdraw(address owner) public view virtual returns (uint256) {
        if (owner == address(0)) {
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
    function withdraw(uint256 assets, address receiver, address owner) public virtual returns (uint256 shares) {
        _requireInitialized();
        _requireNonZeroAddress(receiver);
        _requireNonZeroAddress(owner);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        shares = previewWithdraw(assets);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _burnShares(owner, shares);
        _decreaseManagedAssets(assets);
        _safeTransferAsset(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /// @notice Returns max shares `owner` can redeem.
    /// @param owner Share owner.
    /// @return Max redeemable shares.
    function maxRedeem(address owner) public view virtual returns (uint256) {
        if (owner == address(0)) {
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
    function redeem(uint256 shares, address receiver, address owner) public virtual returns (uint256 assets) {
        _requireInitialized();
        _requireNonZeroAddress(receiver);
        _requireNonZeroAddress(owner);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        assets = previewRedeem(shares);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _burnShares(owner, shares);
        _decreaseManagedAssets(assets);
        _safeTransferAsset(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

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
    function _safeTransferAsset(address to, uint256 value) internal {
        (bool success, bytes memory data) = asset().call(abi.encodeCall(IERC20.transfer, (to, value)));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert ERC4626VaultAssetTransferFailed();
        }
    }

    /// @dev Performs ERC-20 transferFrom and handles optional return values.
    /// @param from Asset sender.
    /// @param to Asset receiver.
    /// @param value Asset amount.
    function _safeTransferFromAsset(address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = asset().call(abi.encodeCall(IERC20.transferFrom, (from, to, value)));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert ERC4626VaultAssetTransferFromFailed();
        }
    }
}
