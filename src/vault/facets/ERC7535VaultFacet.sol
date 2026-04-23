// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC7535VaultFacet} from "../../interfaces/IERC7535VaultFacet.sol";
import {ERC4626Vault} from "../ERC4626Vault.sol";
import {ERC4626VaultStrategyPricing} from "../ERC4626VaultStrategyPricing.sol";
import {VaultFacetControl} from "../VaultFacetControl.sol";
import {LibVaultAsset} from "../libraries/LibVaultAsset.sol";

/// @title ERC7535VaultFacet
/// @notice Hosted native-asset extension facet for ERC-7535-style vault entrypoints.
contract ERC7535VaultFacet is ERC4626VaultStrategyPricing, VaultFacetControl, IERC7535VaultFacet {
    /// @notice Deposits native asset and mints shares to `receiver`.
    /// @param receiver Receiver of minted shares.
    /// @return shares Minted shares.
    function depositNative(address receiver)
        external
        payable
        virtual
        whenNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        _requireNativeVaultAsset();
        return _depositNativeWithControls(receiver);
    }

    /// @notice Mints `shares` to `receiver` using native asset funding.
    /// @param shares Share amount.
    /// @param receiver Receiver of minted shares.
    /// @return assets Native assets consumed.
    function mintNative(uint256 shares, address receiver)
        external
        payable
        virtual
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        _requireNativeVaultAsset();
        return _mintNativeWithControls(shares, receiver);
    }

    function _vaultOperationsPaused() internal view virtual override returns (bool) {
        return paused();
    }

    function _requireNativeVaultAsset() internal view {
        if (!LibVaultAsset.isNativeAsset(ERC4626Vault.asset())) {
            revert ERC4626VaultNativeAssetDisabled();
        }
    }
}
