// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "../interfaces/IERC165.sol";
import {IERC4626VaultControls} from "../interfaces/IERC4626VaultControls.sol";
import {LibERC4626VaultStorage} from "./storage/LibERC4626VaultStorage.sol";
import {ERC4626Vault} from "./ERC4626Vault.sol";
import {VaultFacetControl} from "./VaultFacetControl.sol";

/// @title ERC4626VaultControls
/// @notice ERC-4626 extension with role-gated fee/limit controls and safety hooks.
abstract contract ERC4626VaultControls is ERC4626Vault, VaultFacetControl, IERC4626VaultControls {
    /// @dev Basis points denominator.
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    /// @param initialAdmin Account receiving admin, pauser, and manager roles.
    /// @param vaultAsset Underlying vault asset token.
    /// @param vaultName ERC-20 share token name.
    /// @param vaultSymbol ERC-20 share token symbol.
    constructor(address initialAdmin, address vaultAsset, string memory vaultName, string memory vaultSymbol) {
        _initializeVaultFacetControl(initialAdmin);
        _initializeErc4626Vault(vaultAsset, vaultName, vaultSymbol);
    }

    /// @notice Role that can manage vault fees and limits.
    /// @return The vault manager role identifier.
    function VAULT_MANAGER_ROLE()
        public
        pure
        virtual
        override(VaultFacetControl, IERC4626VaultControls)
        returns (bytes32)
    {
        return VaultFacetControl.VAULT_MANAGER_ROLE();
    }

    /// @notice Returns true if this contract implements `interfaceId`.
    /// @param interfaceId The interface identifier.
    /// @return True if the interface is supported.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(VaultFacetControl, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC4626VaultControls).interfaceId || interfaceId == type(IERC165).interfaceId
            || VaultFacetControl.supportsInterface(interfaceId);
    }

    /// @notice Returns current fee configuration.
    /// @return depositFeeBps Deposit fee in basis points.
    /// @return withdrawFeeBps Withdraw fee in basis points.
    /// @return feeRecipient Fee recipient account.
    function feeConfig() public view returns (uint16 depositFeeBps, uint16 withdrawFeeBps, address feeRecipient) {
        LibERC4626VaultStorage.FeeConfig storage fees = LibERC4626VaultStorage.layout().fees;
        return (fees.depositFeeBps, fees.withdrawFeeBps, fees.feeRecipient);
    }

    /// @notice Returns current limit configuration.
    /// @return limitMaxTotalAssets Cap for managed assets (`0` means unlimited).
    /// @return limitMaxDeposit Per-call deposit limit (`0` means unlimited).
    /// @return limitMaxMint Per-call mint limit (`0` means unlimited).
    /// @return limitMaxWithdraw Per-call withdraw limit (`0` means unlimited).
    /// @return limitMaxRedeem Per-call redeem limit (`0` means unlimited).
    function limitConfig()
        public
        view
        returns (
            uint128 limitMaxTotalAssets,
            uint128 limitMaxDeposit,
            uint128 limitMaxMint,
            uint128 limitMaxWithdraw,
            uint128 limitMaxRedeem
        )
    {
        LibERC4626VaultStorage.LimitConfig storage limits = LibERC4626VaultStorage.layout().limits;
        return (limits.maxTotalAssets, limits.maxDeposit, limits.maxMint, limits.maxWithdraw, limits.maxRedeem);
    }

    /// @notice Sets fee configuration.
    /// @dev Caller must have `VAULT_MANAGER_ROLE`.
    /// @param depositFeeBps Deposit fee in basis points.
    /// @param withdrawFeeBps Withdraw fee in basis points.
    /// @param feeRecipient Fee recipient account.
    function setFeeConfig(uint16 depositFeeBps, uint16 withdrawFeeBps, address feeRecipient)
        public
        onlyRole(VAULT_MANAGER_ROLE())
    {
        _validateFeeBps(depositFeeBps);
        _validateFeeBps(withdrawFeeBps);

        if ((depositFeeBps != 0 || withdrawFeeBps != 0) && feeRecipient == address(0)) {
            revert ERC4626VaultInvalidFeeRecipient();
        }

        LibERC4626VaultStorage.FeeConfig storage fees = LibERC4626VaultStorage.layout().fees;
        uint16 previousDepositFeeBps = fees.depositFeeBps;
        uint16 previousWithdrawFeeBps = fees.withdrawFeeBps;
        address previousFeeRecipient = fees.feeRecipient;

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

    /// @notice Sets limit configuration.
    /// @dev Caller must have `VAULT_MANAGER_ROLE`.
    /// @param limitMaxTotalAssets Cap for managed assets (`0` means unlimited).
    /// @param limitMaxDeposit Per-call deposit limit (`0` means unlimited).
    /// @param limitMaxMint Per-call mint limit (`0` means unlimited).
    /// @param limitMaxWithdraw Per-call withdraw limit (`0` means unlimited).
    /// @param limitMaxRedeem Per-call redeem limit (`0` means unlimited).
    function setLimitConfig(
        uint128 limitMaxTotalAssets,
        uint128 limitMaxDeposit,
        uint128 limitMaxMint,
        uint128 limitMaxWithdraw,
        uint128 limitMaxRedeem
    ) public onlyRole(VAULT_MANAGER_ROLE()) {
        LibERC4626VaultStorage.LimitConfig storage limits = LibERC4626VaultStorage.layout().limits;

        limits.maxTotalAssets = limitMaxTotalAssets;
        limits.maxDeposit = limitMaxDeposit;
        limits.maxMint = limitMaxMint;
        limits.maxWithdraw = limitMaxWithdraw;
        limits.maxRedeem = limitMaxRedeem;

        emit VaultLimitConfigUpdated(
            limitMaxTotalAssets, limitMaxDeposit, limitMaxMint, limitMaxWithdraw, limitMaxRedeem, msg.sender
        );
    }

    /// @notice Returns max assets `receiver` can deposit.
    /// @param receiver Target receiver.
    /// @return Max asset amount accepted.
    function maxDeposit(address receiver) public view virtual override returns (uint256) {
        if (receiver == address(0) || paused()) {
            return 0;
        }

        uint256 maxAssets = type(uint256).max;
        LibERC4626VaultStorage.LimitConfig storage limits = LibERC4626VaultStorage.layout().limits;

        if (limits.maxDeposit != 0) {
            maxAssets = limits.maxDeposit;
        }

        if (limits.maxTotalAssets != 0) {
            uint256 currentAssets = totalAssets();
            if (currentAssets >= limits.maxTotalAssets) {
                return 0;
            }

            uint256 remainingAssets = limits.maxTotalAssets - currentAssets;
            uint256 capBasedMaxAssets = _grossUpForDepositFee(remainingAssets);
            if (capBasedMaxAssets < maxAssets) {
                maxAssets = capBasedMaxAssets;
            }
        }

        return maxAssets;
    }

    /// @notice Returns max shares `receiver` can mint.
    /// @param receiver Target receiver.
    /// @return Max shares accepted.
    function maxMint(address receiver) public view virtual override returns (uint256) {
        if (receiver == address(0) || paused()) {
            return 0;
        }

        uint256 maxShares = type(uint256).max;
        LibERC4626VaultStorage.LimitConfig storage limits = LibERC4626VaultStorage.layout().limits;

        if (limits.maxMint != 0) {
            maxShares = limits.maxMint;
        }

        if (limits.maxTotalAssets != 0) {
            uint256 currentAssets = totalAssets();
            if (currentAssets >= limits.maxTotalAssets) {
                return 0;
            }

            uint256 remainingAssets = limits.maxTotalAssets - currentAssets;
            uint256 capBasedMaxShares = _convertToShares(remainingAssets, Rounding.Down);
            if (capBasedMaxShares < maxShares) {
                maxShares = capBasedMaxShares;
            }
        }

        return maxShares;
    }

    /// @notice Returns max assets `owner` can withdraw.
    /// @param owner Share owner.
    /// @return Max withdrawable assets.
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        if (owner == address(0) || paused()) {
            return 0;
        }

        uint256 grossAssets = _convertToAssets(balanceOf(owner), Rounding.Down);
        (uint256 netAssets,) = _withdrawNetFromGross(grossAssets);

        uint128 configuredMaxWithdraw = LibERC4626VaultStorage.layout().limits.maxWithdraw;
        if (configuredMaxWithdraw != 0 && netAssets > configuredMaxWithdraw) {
            return configuredMaxWithdraw;
        }

        return netAssets;
    }

    /// @notice Returns max shares `owner` can redeem.
    /// @param owner Share owner.
    /// @return Max redeemable shares.
    function maxRedeem(address owner) public view virtual override returns (uint256) {
        if (owner == address(0) || paused()) {
            return 0;
        }

        uint256 redeemableShares = balanceOf(owner);
        uint128 configuredMaxRedeem = LibERC4626VaultStorage.layout().limits.maxRedeem;
        if (configuredMaxRedeem != 0 && redeemableShares > configuredMaxRedeem) {
            return configuredMaxRedeem;
        }

        return redeemableShares;
    }

    /// @notice Returns shares minted by depositing `assets`.
    /// @param assets Asset amount.
    /// @return Estimated shares.
    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        (uint256 netAssets,) = _netAfterDepositFee(assets);
        return _convertToShares(netAssets, Rounding.Down);
    }

    /// @notice Returns assets required to mint `shares`.
    /// @param shares Share amount.
    /// @return Required assets.
    function previewMint(uint256 shares) public view virtual override returns (uint256) {
        uint256 netAssets = _convertToAssets(shares, Rounding.Up);
        return _grossUpForDepositFee(netAssets);
    }

    /// @notice Returns shares burned by withdrawing `assets`.
    /// @param assets Asset amount.
    /// @return Estimated shares burned.
    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        (uint256 grossAssets,) = _withdrawGrossFromNet(assets);
        return _convertToShares(grossAssets, Rounding.Up);
    }

    /// @notice Returns assets received by redeeming `shares`.
    /// @param shares Share amount.
    /// @return Estimated assets returned.
    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        uint256 grossAssets = _convertToAssets(shares, Rounding.Down);
        (uint256 netAssets,) = _withdrawNetFromGross(grossAssets);
        return netAssets;
    }

    /// @notice Deposits `assets` and mints shares to `receiver`.
    /// @param assets Asset amount.
    /// @param receiver Receiver of minted shares.
    /// @return shares Minted shares.
    function deposit(uint256 assets, address receiver)
        public
        virtual
        override
        whenNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        _requireInitialized();
        _requireNonZeroAddress(receiver);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626VaultDepositLimitExceeded(assets, maxAssets);
        }

        (uint256 netAssets, uint256 feeAssets) = _netAfterDepositFee(assets);
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

    /// @notice Mints `shares` to `receiver`.
    /// @param shares Share amount.
    /// @param receiver Receiver of minted shares.
    /// @return assets Deposited assets.
    function mint(uint256 shares, address receiver)
        public
        virtual
        override
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        _requireInitialized();
        _requireNonZeroAddress(receiver);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626VaultMintLimitExceeded(shares, maxShares);
        }

        uint256 netAssets = _convertToAssets(shares, Rounding.Up);
        if (netAssets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        assets = _grossUpForDepositFee(netAssets);
        uint256 feeAssets = assets - netAssets;

        _enforceTotalAssetsCap(netAssets);
        _safeTransferFromAsset(msg.sender, address(this), assets);
        _increaseManagedAssets(netAssets);
        _mintShares(receiver, shares);
        _payoutFee(feeAssets);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @notice Withdraws `assets` to `receiver` from `owner`.
    /// @param assets Asset amount.
    /// @param receiver Asset receiver.
    /// @param owner Share owner.
    /// @return shares Burned shares.
    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        override
        whenNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        _requireInitialized();
        _requireNonZeroAddress(receiver);
        _requireNonZeroAddress(owner);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626VaultWithdrawLimitExceeded(assets, maxAssets);
        }

        (uint256 grossAssets, uint256 feeAssets) = _withdrawGrossFromNet(assets);
        shares = _convertToShares(grossAssets, Rounding.Up);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _burnShares(owner, shares);
        _decreaseManagedAssets(grossAssets);
        _safeTransferAsset(receiver, assets);
        _payoutFee(feeAssets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /// @notice Redeems `shares` from `owner` to `receiver`.
    /// @param shares Share amount.
    /// @param receiver Asset receiver.
    /// @param owner Share owner.
    /// @return assets Returned assets.
    function redeem(uint256 shares, address receiver, address owner)
        public
        virtual
        override
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        _requireInitialized();
        _requireNonZeroAddress(receiver);
        _requireNonZeroAddress(owner);
        if (shares == 0) {
            revert ERC4626VaultZeroShares();
        }

        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626VaultRedeemLimitExceeded(shares, maxShares);
        }

        uint256 grossAssets = _convertToAssets(shares, Rounding.Down);
        uint256 feeAssets;
        (assets, feeAssets) = _withdrawNetFromGross(grossAssets);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _burnShares(owner, shares);
        _decreaseManagedAssets(grossAssets);
        _safeTransferAsset(receiver, assets);
        _payoutFee(feeAssets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /// @dev Enforces configured total-assets cap.
    /// @param additionalAssets Assets to be added to managed accounting.
    function _enforceTotalAssetsCap(uint256 additionalAssets) internal view {
        uint128 cap = LibERC4626VaultStorage.layout().limits.maxTotalAssets;
        if (cap == 0) {
            return;
        }

        uint256 currentAssets = totalAssets();
        uint256 nextAssets = currentAssets + additionalAssets;
        if (nextAssets > cap) {
            revert ERC4626VaultTotalAssetsCapExceeded(currentAssets, additionalAssets, cap);
        }
    }

    /// @dev Returns net deposit assets and fee amount from a gross input.
    /// @param assets Gross deposit asset amount.
    /// @return netAssets Net assets credited to vault accounting.
    /// @return feeAssets Fee assets paid out.
    function _netAfterDepositFee(uint256 assets) internal view returns (uint256 netAssets, uint256 feeAssets) {
        uint16 depositFeeBps = LibERC4626VaultStorage.layout().fees.depositFeeBps;
        feeAssets = _feeOnRaw(assets, depositFeeBps, Rounding.Down);
        netAssets = assets - feeAssets;
    }

    /// @dev Returns gross deposit amount needed to credit `netAssets`.
    /// @param netAssets Desired net assets credited to vault accounting.
    /// @return grossAssets Gross assets that must be transferred in.
    function _grossUpForDepositFee(uint256 netAssets) internal view returns (uint256 grossAssets) {
        uint16 depositFeeBps = LibERC4626VaultStorage.layout().fees.depositFeeBps;
        if (depositFeeBps == 0 || netAssets == 0) {
            return netAssets;
        }

        uint256 denominator = BPS_DENOMINATOR - depositFeeBps;
        grossAssets = _mulDiv(netAssets, BPS_DENOMINATOR, denominator, Rounding.Up);

        (uint256 creditedAssets,) = _netAfterDepositFee(grossAssets);
        if (creditedAssets < netAssets) {
            grossAssets += 1;
        }
    }

    /// @dev Returns gross withdraw assets and fee from a requested net output.
    /// @param assets Requested receiver assets.
    /// @return grossAssets Gross assets removed from managed accounting.
    /// @return feeAssets Fee assets paid out.
    function _withdrawGrossFromNet(uint256 assets) internal view returns (uint256 grossAssets, uint256 feeAssets) {
        uint16 withdrawFeeBps = LibERC4626VaultStorage.layout().fees.withdrawFeeBps;
        feeAssets = _feeOnRaw(assets, withdrawFeeBps, Rounding.Up);
        grossAssets = assets + feeAssets;
    }

    /// @dev Returns receiver assets and fee from a gross redeemed amount.
    /// @param grossAssets Gross assets removed from managed accounting.
    /// @return netAssets Assets sent to receiver.
    /// @return feeAssets Fee assets paid out.
    function _withdrawNetFromGross(uint256 grossAssets) internal view returns (uint256 netAssets, uint256 feeAssets) {
        uint16 withdrawFeeBps = LibERC4626VaultStorage.layout().fees.withdrawFeeBps;
        feeAssets = _feeOnRaw(grossAssets, withdrawFeeBps, Rounding.Down);
        netAssets = grossAssets - feeAssets;
    }

    /// @dev Pays `feeAssets` to configured fee recipient when non-zero.
    /// @param feeAssets Fee amount to transfer.
    function _payoutFee(uint256 feeAssets) internal {
        if (feeAssets == 0) {
            return;
        }

        address recipient = LibERC4626VaultStorage.layout().fees.feeRecipient;
        _safeTransferAsset(recipient, feeAssets);
    }

    /// @dev Reverts when `feeBps` is invalid.
    /// @param feeBps Fee basis points.
    function _validateFeeBps(uint16 feeBps) internal pure {
        if (feeBps >= BPS_DENOMINATOR) {
            revert ERC4626VaultInvalidFeeBps(feeBps);
        }
    }

    /// @dev Returns fee amount for `assets` and `feeBps` with controlled rounding.
    /// @param assets Asset amount used for fee computation.
    /// @param feeBps Fee basis points.
    /// @param rounding Rounding direction.
    /// @return Computed fee amount.
    function _feeOnRaw(uint256 assets, uint16 feeBps, Rounding rounding) internal pure returns (uint256) {
        if (feeBps == 0 || assets == 0) {
            return 0;
        }

        return _mulDiv(assets, feeBps, BPS_DENOMINATOR, rounding);
    }
}
