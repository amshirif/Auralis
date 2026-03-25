// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "./IERC165.sol";
import {IOracleAdapter} from "./IOracleAdapter.sol";

/// @title IERC4626VaultIntegrationFacet
/// @notice Hosted integration/config surface for vault oracle and strategy wiring.
interface IERC4626VaultIntegrationFacet is IERC165 {
    /// @notice Emitted when the configured oracle adapter is updated.
    event VaultOracleAdapterUpdated(
        address indexed previousAdapter, address indexed newAdapter, address indexed sender
    );

    /// @notice Emitted when the configured strategy address is updated.
    event VaultStrategyUpdated(address indexed previousStrategy, address indexed newStrategy, address indexed sender);

    /// @notice Emitted when reported strategy assets are updated.
    event VaultStrategyAssetsReported(uint256 previousAssets, uint256 newAssets, address indexed sender);

    /// @notice Thrown when `oracleQuote()` is called without a configured adapter.
    error ERC4626VaultOracleAdapterNotConfigured();

    /// @notice Thrown when `reportStrategyAssets()` is called by an unauthorized account.
    /// @param caller The unauthorized caller.
    /// @param strategy The currently configured strategy address.
    error ERC4626VaultStrategyReporterUnauthorized(address caller, address strategy);

    /// @notice Returns the configured external oracle adapter address.
    /// @return The adapter address, or zero when unset.
    function oracleAdapter() external view returns (address);

    /// @notice Returns the configured strategy address.
    /// @return The strategy address, or zero when unset.
    function strategy() external view returns (address);

    /// @notice Returns the latest reported strategy-held asset amount.
    /// @return The reported asset amount.
    function strategyReportedAssets() external view returns (uint256);

    /// @notice Returns the vault's idle underlying asset balance.
    /// @return The idle asset amount held directly by the vault.
    function idleAssets() external view returns (uint256);

    /// @notice Returns idle assets plus the latest reported strategy assets.
    /// @return The estimated total assets across idle vault balance and strategy reports.
    function estimatedTotalManagedAssets() external view returns (uint256);

    /// @notice Returns the latest normalized quote from the configured oracle adapter.
    /// @return quotePayload The latest quote payload.
    function oracleQuote() external view returns (IOracleAdapter.OracleQuote memory quotePayload);

    /// @notice Sets the external oracle adapter reference.
    /// @param newAdapter The new adapter address, or zero to clear.
    function setOracleAdapter(address newAdapter) external;

    /// @notice Sets the configured strategy reference.
    /// @param newStrategy The new strategy address, or zero to clear.
    function setStrategy(address newStrategy) external;

    /// @notice Updates the latest reported strategy-held asset amount.
    /// @param assets The latest reported asset amount.
    function reportStrategyAssets(uint256 assets) external;
}
