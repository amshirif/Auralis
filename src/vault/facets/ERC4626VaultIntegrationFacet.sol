// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "../../interfaces/IERC20.sol";
import {IERC4626VaultIntegrationFacet} from "../../interfaces/IERC4626VaultIntegrationFacet.sol";
import {IERC4626VaultStrategy} from "../../interfaces/IERC4626VaultStrategy.sol";
import {IOracleAdapter} from "../../interfaces/IOracleAdapter.sol";
import {ERC4626Vault} from "../ERC4626Vault.sol";
import {VaultFacetControl} from "../VaultFacetControl.sol";
import {LibERC4626VaultStorage} from "../storage/LibERC4626VaultStorage.sol";

/// @title ERC4626VaultIntegrationFacet
/// @notice Hosted integration/config facet for oracle references and active strategy lifecycle operations.
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

    /// @notice Returns the vault's current stored book debt allocated to the configured strategy.
    /// @return The strategy debt amount.
    function strategyDebt() public view returns (uint256) {
        return LibERC4626VaultStorage.layout().strategyDebt;
    }

    /// @notice Returns the vault's idle underlying asset balance.
    /// @return The idle asset amount held directly by the vault.
    function idleAssets() public view returns (uint256) {
        _requireInitialized();
        return IERC20(asset()).balanceOf(address(this));
    }

    /// @notice Returns the configured strategy's live reported assets.
    /// @return The live strategy asset amount, or zero when no strategy is configured.
    function liveStrategyAssets() public view returns (uint256) {
        _requireInitialized();
        address configuredStrategy = strategy();
        if (configuredStrategy == address(0)) {
            return 0;
        }

        return IERC4626VaultStrategy(configuredStrategy).totalAssets();
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
        uint256 currentStrategyDebt = layout.strategyDebt;
        if (currentStrategyDebt != 0) {
            revert ERC4626VaultStrategyDebtOutstanding(currentStrategyDebt);
        }

        if (newStrategy != address(0)) {
            _validateStrategyBinding(newStrategy);
        }

        address previousStrategy = layout.strategy;
        layout.strategy = newStrategy;
        layout.strategyReportedAssets = 0;
        layout.strategyEmergencyExit = false;

        emit VaultStrategyUpdated(previousStrategy, newStrategy, msg.sender);
    }

    /// @notice Deploys idle vault assets into the configured strategy.
    /// @param assets The asset amount to deploy.
    function deployToStrategy(uint256 assets) public {
        _requireInitialized();
        _checkRole(VAULT_MANAGER_ROLE(), msg.sender);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        IERC4626VaultStrategy configuredStrategy = _configuredStrategy();
        uint256 availableIdleAssets = _availableIdleAssetsForStrategy();
        if (assets > availableIdleAssets) {
            revert ERC4626VaultStrategyInsufficientIdleAssets(assets, availableIdleAssets);
        }

        _safeTransferAsset(address(configuredStrategy), assets);
        configuredStrategy.deployFunds(assets);

        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        layout.strategyDebt += assets;
        layout.strategyReportedAssets = 0;

        emit VaultStrategyDeployed(assets, layout.strategyDebt, msg.sender);
    }

    /// @notice Withdraws assets from the configured strategy back to the vault.
    /// @param assets The asset amount to withdraw.
    function withdrawFromStrategy(uint256 assets) public {
        _requireInitialized();
        _checkRole(VAULT_MANAGER_ROLE(), msg.sender);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        IERC4626VaultStrategy configuredStrategy = _configuredStrategy();
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        uint256 currentStrategyDebt = layout.strategyDebt;
        if (assets > currentStrategyDebt) {
            revert ERC4626VaultStrategyDebtOutstanding(currentStrategyDebt);
        }

        uint256 returnedAssets = configuredStrategy.withdrawToVault(assets);
        if (returnedAssets != assets) {
            revert ERC4626VaultStrategyUnexpectedWithdrawResult(assets, returnedAssets);
        }

        layout.strategyDebt = currentStrategyDebt - assets;
        layout.strategyReportedAssets = 0;

        emit VaultStrategyWithdrawn(assets, layout.strategyDebt, msg.sender);
    }

    /// @notice Syncs live strategy assets into vault book accounting.
    function syncStrategyAssets() public {
        _requireInitialized();
        _checkRole(VAULT_MANAGER_ROLE(), msg.sender);

        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        uint256 previousDebt = layout.strategyDebt;
        uint256 liveAssets = _configuredStrategy().totalAssets();

        if (liveAssets > previousDebt) {
            _increaseManagedAssets(liveAssets - previousDebt);
        } else if (previousDebt > liveAssets) {
            _decreaseManagedAssets(previousDebt - liveAssets);
        }

        layout.strategyDebt = liveAssets;
        layout.strategyReportedAssets = 0;

        emit VaultStrategySynced(previousDebt, liveAssets, msg.sender);
    }

    function _configuredStrategy() internal view returns (IERC4626VaultStrategy configuredStrategy) {
        address configuredStrategyAddress = strategy();
        if (configuredStrategyAddress == address(0)) {
            revert ERC4626VaultStrategyNotConfigured();
        }

        configuredStrategy = IERC4626VaultStrategy(configuredStrategyAddress);
    }

    function _validateStrategyBinding(address newStrategy) internal view {
        IERC4626VaultStrategy candidateStrategy = IERC4626VaultStrategy(newStrategy);
        address expectedVault = address(this);
        address actualVault = candidateStrategy.vault();
        if (actualVault != expectedVault) {
            revert ERC4626VaultStrategyInvalidVault(newStrategy, expectedVault, actualVault);
        }

        address expectedAsset = asset();
        address actualAsset = candidateStrategy.asset();
        if (actualAsset != expectedAsset) {
            revert ERC4626VaultStrategyInvalidAsset(newStrategy, expectedAsset, actualAsset);
        }
    }

    function _availableIdleAssetsForStrategy() internal view returns (uint256) {
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        uint256 actualIdleAssets = IERC20(asset()).balanceOf(address(this));
        uint256 idleBookAssets = layout.totalManagedAssets - layout.strategyDebt;
        return actualIdleAssets < idleBookAssets ? actualIdleAssets : idleBookAssets;
    }
}
