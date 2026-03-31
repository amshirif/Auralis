// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "./IERC165.sol";
import {IOracleAdapter} from "./IOracleAdapter.sol";

/// @title IERC4626VaultIntegrationFacet
/// @notice Hosted integration/config surface for vault oracle wiring and active strategy lifecycle management.
interface IERC4626VaultIntegrationFacet is IERC165 {
    /// @notice Emitted when the configured oracle adapter is updated.
    event VaultOracleAdapterUpdated(
        address indexed previousAdapter, address indexed newAdapter, address indexed sender
    );

    /// @notice Emitted when the configured strategy address is updated.
    event VaultStrategyUpdated(address indexed previousStrategy, address indexed newStrategy, address indexed sender);

    /// @notice Emitted when assets are deployed from the vault into the configured strategy.
    event VaultStrategyDeployed(uint256 assets, uint256 newStrategyDebt, address indexed sender);

    /// @notice Emitted when assets are withdrawn from the configured strategy back to the vault.
    event VaultStrategyWithdrawn(
        uint256 requestedAssets, uint256 returnedAssets, uint256 newStrategyDebt, address indexed sender
    );

    /// @notice Emitted when live strategy assets are synced into vault book accounting.
    event VaultStrategySynced(uint256 previousDebt, uint256 liveAssets, address indexed sender);

    /// @notice Emitted when emergency exit is triggered and the strategy is unwound as far as possible.
    event VaultStrategyEmergencyExitTriggered(uint256 returnedAssets, uint256 newStrategyDebt, address indexed sender);

    /// @notice Emitted when emergency exit is activated but the unwind attempt reverts.
    event VaultStrategyEmergencyExitFailed(address indexed strategy, address indexed sender, bytes revertData);

    /// @notice Thrown when `oracleQuote()` is called without a configured adapter.
    error ERC4626VaultOracleAdapterNotConfigured();

    /// @notice Thrown when a strategy lifecycle action is attempted without a configured strategy.
    error ERC4626VaultStrategyNotConfigured();

    /// @notice Thrown when a strategy clear/swap is attempted while debt is still outstanding.
    /// @param strategyDebt The current outstanding strategy debt.
    error ERC4626VaultStrategyDebtOutstanding(uint256 strategyDebt);

    /// @notice Thrown when a configured strategy is bound to a different vault.
    /// @param strategy The invalid strategy address.
    /// @param expectedVault The expected vault address.
    /// @param actualVault The strategy-reported bound vault address.
    error ERC4626VaultStrategyInvalidVault(address strategy, address expectedVault, address actualVault);

    /// @notice Thrown when a configured strategy is bound to a different asset.
    /// @param strategy The invalid strategy address.
    /// @param expectedAsset The expected asset address.
    /// @param actualAsset The strategy-reported bound asset address.
    error ERC4626VaultStrategyInvalidAsset(address strategy, address expectedAsset, address actualAsset);

    /// @notice Thrown when a deploy attempt exceeds the vault's immediately idle assets.
    /// @param requestedAssets The requested deployment amount.
    /// @param idleAssets The vault's immediately available idle asset amount.
    error ERC4626VaultStrategyInsufficientIdleAssets(uint256 requestedAssets, uint256 idleAssets);

    /// @notice Thrown when a strategy deploy is attempted after emergency exit has been activated.
    error ERC4626VaultStrategyEmergencyExitActive();

    /// @notice Returns the configured external oracle adapter address.
    /// @return The adapter address, or zero when unset.
    function oracleAdapter() external view returns (address);

    /// @notice Returns the configured strategy address.
    /// @return The strategy address, or zero when unset.
    function strategy() external view returns (address);

    /// @notice Returns true when the current strategy is in emergency-exit mode.
    /// @return True when emergency exit is active.
    function strategyEmergencyExit() external view returns (bool);

    /// @notice Returns the vault's current stored book debt allocated to the configured strategy.
    /// @return The strategy debt amount.
    function strategyDebt() external view returns (uint256);

    /// @notice Returns the vault's idle underlying asset balance.
    /// @return The idle asset amount held directly by the vault.
    function idleAssets() external view returns (uint256);

    /// @notice Returns the configured strategy's live reported assets.
    /// @return The live strategy asset amount, or zero when no strategy is configured.
    function liveStrategyAssets() external view returns (uint256);

    /// @notice Returns the latest normalized quote from the configured oracle adapter.
    /// @return quotePayload The latest quote payload.
    function oracleQuote() external view returns (IOracleAdapter.OracleQuote memory quotePayload);

    /// @notice Sets the external oracle adapter reference.
    /// @param newAdapter The new adapter address, or zero to clear.
    function setOracleAdapter(address newAdapter) external;

    /// @notice Sets the configured strategy reference.
    /// @param newStrategy The new strategy address, or zero to clear.
    function setStrategy(address newStrategy) external;

    /// @notice Deploys idle vault assets into the configured strategy.
    /// @param assets The asset amount to deploy.
    function deployToStrategy(uint256 assets) external;

    /// @notice Withdraws assets from the configured strategy back to the vault.
    /// @param assets The requested asset amount to withdraw.
    /// @return assetsReturned The actual returned asset amount.
    function withdrawFromStrategy(uint256 assets) external returns (uint256 assetsReturned);

    /// @notice Syncs live strategy assets into vault book accounting.
    function syncStrategyAssets() external;

    /// @notice Activates emergency-exit mode and attempts to unwind the configured strategy.
    /// @return assetsReturned The actual returned asset amount from the unwind attempt.
    function emergencyExitStrategy() external returns (uint256 assetsReturned);
}
