// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "../../interfaces/IERC20.sol";
import {IERC4626VaultIntegrationFacet} from "../../interfaces/IERC4626VaultIntegrationFacet.sol";
import {IOracleAdapter} from "../../interfaces/IOracleAdapter.sol";
import {ERC4626Vault} from "../ERC4626Vault.sol";
import {VaultFacetControl} from "../VaultFacetControl.sol";
import {LibERC4626VaultStorage} from "../storage/LibERC4626VaultStorage.sol";

/// @title ERC4626VaultIntegrationFacet
/// @notice Hosted integration/config facet for oracle references and strategy reports.
contract ERC4626VaultIntegrationFacet is ERC4626Vault, VaultFacetControl, IERC4626VaultIntegrationFacet {
    /// @notice Returns the configured external oracle adapter address.
    /// @return The adapter address, or zero when unset.
    function oracleAdapter() public view returns (address) {
        return LibERC4626VaultStorage.layout().oracleAdapter;
    }

    /// @notice Returns the configured strategy address.
    /// @return The strategy address, or zero when unset.
    function strategy() public view returns (address) {
        return LibERC4626VaultStorage.layout().strategy;
    }

    /// @notice Returns the latest reported strategy-held asset amount.
    /// @return The reported asset amount.
    function strategyReportedAssets() public view returns (uint256) {
        return LibERC4626VaultStorage.layout().strategyReportedAssets;
    }

    /// @notice Returns the vault's idle underlying asset balance.
    /// @return The idle asset amount held directly by the vault.
    function idleAssets() public view returns (uint256) {
        _requireInitialized();
        return IERC20(asset()).balanceOf(address(this));
    }

    /// @notice Returns idle assets plus the latest reported strategy assets.
    /// @return The estimated total assets across idle vault balance and strategy reports.
    function estimatedTotalManagedAssets() public view returns (uint256) {
        return idleAssets() + strategyReportedAssets();
    }

    /// @notice Returns the latest normalized quote from the configured oracle adapter.
    /// @return quotePayload The latest quote payload.
    function oracleQuote() public view returns (IOracleAdapter.OracleQuote memory quotePayload) {
        _requireInitialized();
        address adapter = oracleAdapter();
        if (adapter == address(0)) {
            revert ERC4626VaultOracleAdapterNotConfigured();
        }

        return IOracleAdapter(adapter).quote();
    }

    /// @notice Sets the external oracle adapter reference.
    /// @param newAdapter The new adapter address, or zero to clear.
    function setOracleAdapter(address newAdapter) public {
        _requireInitialized();
        _checkRole(VAULT_MANAGER_ROLE(), msg.sender);
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        address previousAdapter = layout.oracleAdapter;
        layout.oracleAdapter = newAdapter;

        emit VaultOracleAdapterUpdated(previousAdapter, newAdapter, msg.sender);
    }

    /// @notice Sets the configured strategy reference.
    /// @param newStrategy The new strategy address, or zero to clear.
    function setStrategy(address newStrategy) public {
        _requireInitialized();
        _checkRole(VAULT_MANAGER_ROLE(), msg.sender);
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        address previousStrategy = layout.strategy;
        layout.strategy = newStrategy;
        layout.strategyReportedAssets = 0;

        emit VaultStrategyUpdated(previousStrategy, newStrategy, msg.sender);
    }

    /// @notice Updates the latest reported strategy-held asset amount.
    /// @param assets The latest reported asset amount.
    function reportStrategyAssets(uint256 assets) public {
        _requireInitialized();
        address configuredStrategy = strategy();
        if (msg.sender != configuredStrategy || configuredStrategy == address(0)) {
            if (!hasRole(VAULT_MANAGER_ROLE(), msg.sender)) {
                revert ERC4626VaultStrategyReporterUnauthorized(msg.sender, configuredStrategy);
            }
        }

        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        uint256 previousAssets = layout.strategyReportedAssets;
        layout.strategyReportedAssets = assets;

        emit VaultStrategyAssetsReported(previousAssets, assets, msg.sender);
    }
}
