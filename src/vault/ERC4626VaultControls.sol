// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "../interfaces/IERC165.sol";
import {IERC4626} from "../interfaces/IERC4626.sol";
import {IERC4626VaultControls} from "../interfaces/IERC4626VaultControls.sol";
import {ERC4626Vault} from "./ERC4626Vault.sol";
import {ERC4626VaultControlledCore, ERC4626VaultControlSurface} from "./ERC4626VaultControlLogic.sol";
import {VaultFacetControl} from "./VaultFacetControl.sol";

/// @title ERC4626VaultControls
/// @notice ERC-4626 extension with role-gated fee, limit, and safety controls.
abstract contract ERC4626VaultControls is ERC4626VaultControlSurface, ERC4626VaultControlledCore {
    /// @param initialAdmin Account receiving admin, pauser, and manager roles.
    /// @param vaultAsset Underlying vault asset token.
    /// @param vaultName ERC-20 share token name.
    /// @param vaultSymbol ERC-20 share token symbol.
    constructor(address initialAdmin, address vaultAsset, string memory vaultName, string memory vaultSymbol) {
        _initializeVaultFacetControl(initialAdmin);
        _initializeErc4626Vault(vaultAsset, vaultName, vaultSymbol);
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

    /// @notice Deposits `assets` and mints shares to `receiver`.
    /// @param assets Asset amount.
    /// @param receiver Receiver of minted shares.
    /// @return shares Minted shares.
    function deposit(uint256 assets, address receiver)
        public
        virtual
        override(ERC4626Vault)
        whenNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        return _depositWithControls(assets, receiver);
    }

    /// @notice Mints `shares` to `receiver`.
    /// @param shares Share amount.
    /// @param receiver Receiver of minted shares.
    /// @return assets Deposited assets.
    function mint(uint256 shares, address receiver)
        public
        virtual
        override(ERC4626Vault)
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
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
        override(ERC4626Vault)
        whenNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        return _withdrawWithControls(assets, receiver, owner);
    }

    /// @notice Redeems `shares` from `owner` to `receiver`.
    /// @param shares Share amount.
    /// @param receiver Asset receiver.
    /// @param owner Share owner.
    /// @return assets Returned assets.
    function redeem(uint256 shares, address receiver, address owner)
        public
        virtual
        override(ERC4626Vault)
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        return _redeemWithControls(shares, receiver, owner);
    }

    function _vaultOperationsPaused() internal view virtual override returns (bool) {
        return paused();
    }
}
