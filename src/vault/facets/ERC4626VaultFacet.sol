// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626} from "../../interfaces/IERC4626.sol";
import {IERC4626VaultControls} from "../../interfaces/IERC4626VaultControls.sol";
import {IERC4626VaultFacet} from "../../interfaces/IERC4626VaultFacet.sol";
import {IERC4626VaultStrategy} from "../../interfaces/IERC4626VaultStrategy.sol";
import {ERC4626Vault} from "../ERC4626Vault.sol";
import {ERC4626VaultBase} from "../ERC4626VaultBase.sol";
import {ERC4626VaultControlledCore, LibERC4626VaultControlLogic} from "../ERC4626VaultControlLogic.sol";
import {VaultFacetControl} from "../VaultFacetControl.sol";
import {LibVaultAsset} from "../libraries/LibVaultAsset.sol";
import {LibERC4626VaultStorage} from "../storage/LibERC4626VaultStorage.sol";

/// @title ERC4626VaultFacet
/// @notice Hosted ERC-4626 core facet with constructor-free initialization.
contract ERC4626VaultFacet is ERC4626VaultControlledCore, VaultFacetControl, IERC4626VaultFacet {
    /// @notice Returns true when vault storage is initialized.
    /// @return True if initialized.
    function isVaultInitialized() public view virtual override(IERC4626VaultFacet, ERC4626VaultBase) returns (bool) {
        return ERC4626VaultBase.isVaultInitialized();
    }

    /// @notice Returns vault underlying asset token address.
    /// @return The underlying asset token.
    function asset() public view virtual override(ERC4626Vault, IERC4626) returns (address) {
        return ERC4626Vault.asset();
    }

    /// @notice Returns currently managed asset accounting amount.
    /// @return The tracked managed asset amount.
    function totalManagedAssets() public view virtual override(IERC4626VaultFacet, ERC4626VaultBase) returns (uint256) {
        return ERC4626VaultBase.totalManagedAssets();
    }

    /// @notice Initializes the hosted vault core and shared control plane.
    /// @param vaultAsset Underlying vault asset token.
    /// @param vaultName ERC-20 share token name.
    /// @param vaultSymbol ERC-20 share token symbol.
    /// @param admin Account receiving admin, pauser, and vault manager roles.
    function initializeVault(address vaultAsset, string calldata vaultName, string calldata vaultSymbol, address admin)
        external
    {
        if (isVaultInitialized()) {
            revert ERC4626VaultAlreadyInitialized();
        }

        if (_isAccessControlInitialized()) {
            _checkRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }

        _initializeVaultFacetControl(admin);
        _initializeErc4626Vault(vaultAsset, vaultName, vaultSymbol);
    }

    /// @notice Deposits `assets` and mints shares to `receiver`.
    /// @param assets Asset amount.
    /// @param receiver Receiver of minted shares.
    /// @return shares Minted shares.
    function deposit(uint256 assets, address receiver)
        public
        virtual
        override(ERC4626Vault, IERC4626)
        whenNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        if (LibVaultAsset.isNativeAsset(ERC4626Vault.asset())) {
            revert ERC4626VaultNativeAssetUseNativeEntrypoint();
        }

        return _depositWithControls(assets, receiver);
    }

    /// @notice Mints `shares` to `receiver`.
    /// @param shares Share amount.
    /// @param receiver Receiver of minted shares.
    /// @return assets Deposited assets.
    function mint(uint256 shares, address receiver)
        public
        virtual
        override(ERC4626Vault, IERC4626)
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        if (LibVaultAsset.isNativeAsset(ERC4626Vault.asset())) {
            revert ERC4626VaultNativeAssetUseNativeEntrypoint();
        }

        return _mintWithControls(shares, receiver);
    }

    /// @notice Withdraws `assets` to `receiver` from `owner`.
    /// @param assets Asset amount.
    /// @param receiver Asset receiver.
    /// @param owner Share owner.
    /// @return shares Burned shares.
    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        override(ERC4626Vault, IERC4626)
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

        (uint256 grossAssets, uint256 feeAssets) = LibERC4626VaultControlLogic.withdrawGrossFromNet(assets);
        _sourceStrategyLiquidity(grossAssets);

        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert IERC4626VaultControls.ERC4626VaultWithdrawLimitExceeded(assets, maxAssets);
        }

        uint256 availableIdleAssets = _idleAssetBalance();
        if (grossAssets > availableIdleAssets) {
            revert ERC4626VaultInsufficientLiquidity(grossAssets, availableIdleAssets);
        }

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
        override(ERC4626Vault, IERC4626)
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

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _burnShares(owner, shares);
        _decreaseManagedAssets(grossAssets);
        _safeTransferAsset(receiver, assets);
        _payoutFee(feeAssets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function _managedAssetsForPricing() internal view virtual override returns (uint256) {
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        if (layout.strategy == address(0) || layout.strategyDebt == 0) {
            return layout.totalManagedAssets;
        }

        uint256 idleBookAssets = layout.totalManagedAssets - layout.strategyDebt;
        uint256 liveStrategyAssets = IERC4626VaultStrategy(layout.strategy).totalAssets();
        return idleBookAssets + liveStrategyAssets;
    }

    function _withdrawLiquidityCapAssets() internal view virtual override returns (uint256) {
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        if (layout.strategy == address(0) || layout.strategyDebt == 0) {
            return type(uint256).max;
        }

        return _idleAssetBalance() + _strategyWithdrawableAssets();
    }

    function _vaultOperationsPaused() internal view virtual override returns (bool) {
        return paused();
    }

    function _sourceStrategyLiquidity(uint256 requiredGrossAssets) internal {
        if (requiredGrossAssets == 0) {
            return;
        }

        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        if (layout.strategy == address(0) || layout.strategyDebt == 0) {
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
}
