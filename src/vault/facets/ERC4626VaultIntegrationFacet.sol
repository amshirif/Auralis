// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626VaultIntegrationFacet} from "../../interfaces/IERC4626VaultIntegrationFacet.sol";
import {IERC4626VaultStrategy} from "../../interfaces/IERC4626VaultStrategy.sol";
import {IERC7540VaultSettlementFacet} from "../../interfaces/IERC7540VaultSettlementFacet.sol";
import {IOracleAdapter} from "../../interfaces/IOracleAdapter.sol";
import {ERC4626Vault} from "../ERC4626Vault.sol";
import {VaultFacetControl} from "../VaultFacetControl.sol";
import {LibERC7540RequestAccounting} from "../libraries/LibERC7540RequestAccounting.sol";
import {LibVaultFacetConstants} from "../libraries/LibVaultFacetConstants.sol";
import {LibERC4626VaultStorage} from "../storage/LibERC4626VaultStorage.sol";

/// @title ERC4626VaultIntegrationFacet
/// @notice Hosted integration/config facet for oracle references and active strategy lifecycle operations.
contract ERC4626VaultIntegrationFacet is
    ERC4626Vault,
    VaultFacetControl,
    IERC4626VaultIntegrationFacet,
    IERC7540VaultSettlementFacet
{
    /// @notice Returns the pause scope that gates manager settlement entrypoints.
    /// @return The settlement pause scope identifier.
    function ASYNC_SETTLEMENT_SCOPE() public pure returns (bytes32) {
        return LibVaultFacetConstants.ASYNC_SETTLEMENT_SCOPE;
    }

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

    /// @notice Returns true when the current strategy is in emergency-exit mode.
    /// @return True when emergency exit is active.
    function strategyEmergencyExit() public view returns (bool) {
        return LibERC4626VaultStorage.layout().strategyEmergencyExit;
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
        return _idleAssetBalance();
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
    function setStrategy(address newStrategy) public nonReentrant {
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
        // Reported assets belong to the previous strategy lifecycle and must be cleared so stale operator
        // state does not survive a replacement.
        layout.strategyReportedAssets = 0;
        layout.strategyEmergencyExit = false;

        emit VaultStrategyUpdated(previousStrategy, newStrategy, msg.sender);
    }

    /// @notice Deploys idle vault assets into the configured strategy.
    /// @param assets The asset amount to deploy.
    function deployToStrategy(uint256 assets) public nonReentrant {
        _requireInitialized();
        _checkRole(VAULT_MANAGER_ROLE(), msg.sender);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        if (layout.strategyEmergencyExit) {
            revert ERC4626VaultStrategyEmergencyExitActive();
        }

        IERC4626VaultStrategy configuredStrategy = _configuredStrategy();
        uint256 availableIdleAssets = _availableIdleAssetsForStrategyDeploy();
        if (assets > availableIdleAssets) {
            revert ERC4626VaultStrategyInsufficientIdleAssets(assets, availableIdleAssets);
        }

        _safeTransferAsset(address(configuredStrategy), assets);
        configuredStrategy.deployFunds(assets);

        layout.strategyDebt += assets;
        layout.strategyReportedAssets = 0;

        emit VaultStrategyDeployed(assets, layout.strategyDebt, msg.sender);
    }

    /// @notice Withdraws assets from the configured strategy back to the vault.
    /// @param assets The requested asset amount to withdraw.
    /// @return returnedAssets The actual returned asset amount.
    function withdrawFromStrategy(uint256 assets) public nonReentrant returns (uint256 returnedAssets) {
        _requireInitialized();
        _checkRole(VAULT_MANAGER_ROLE(), msg.sender);
        if (assets == 0) {
            revert ERC4626VaultZeroAssets();
        }

        _configuredStrategy();
        uint256 postCallLiveAssets;
        (returnedAssets, postCallLiveAssets) = _withdrawStrategyAssets(assets);
        _reconcileStrategyWithdrawalAccounting(returnedAssets, postCallLiveAssets);

        emit VaultStrategyWithdrawn(assets, returnedAssets, LibERC4626VaultStorage.layout().strategyDebt, msg.sender);
    }

    /// @notice Syncs live strategy assets into vault book accounting.
    function syncStrategyAssets() public nonReentrant {
        _requireInitialized();
        _checkRole(VAULT_MANAGER_ROLE(), msg.sender);

        uint256 liveAssets = _configuredStrategy().totalAssets();
        uint256 previousDebt = _syncStrategyDebtToLiveAssets(liveAssets);

        emit VaultStrategySynced(previousDebt, liveAssets, msg.sender);
    }

    /// @notice Activates emergency-exit mode and attempts to unwind the configured strategy.
    /// @return assetsReturned The actual returned asset amount from the unwind attempt.
    function emergencyExitStrategy() public nonReentrant returns (uint256 assetsReturned) {
        _requireInitialized();
        _checkRole(VAULT_MANAGER_ROLE(), msg.sender);

        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        IERC4626VaultStrategy configuredStrategy = _configuredStrategy();
        layout.strategyEmergencyExit = true;

        try configuredStrategy.withdrawAllToVault() returns (uint256 returnedAssets) {
            uint256 postCallLiveAssets = configuredStrategy.totalAssets();
            assetsReturned = returnedAssets;
            _reconcileStrategyWithdrawalAccounting(assetsReturned, postCallLiveAssets);
            emit VaultStrategyEmergencyExitTriggered(assetsReturned, layout.strategyDebt, msg.sender);
        } catch (bytes memory revertData) {
            emit VaultStrategyEmergencyExitFailed(address(configuredStrategy), msg.sender, revertData);
        }
    }

    /// @notice Moves pending deposit assets into claimable state for `controller`.
    /// @param controller Request controller account.
    /// @param assets Asset amount to settle.
    function settleDepositRequest(address controller, uint256 assets) public {
        _requireInitialized();
        _checkRole(VAULT_MANAGER_ROLE(), msg.sender);
        _requireScopeNotPaused(ASYNC_SETTLEMENT_SCOPE());

        LibERC7540RequestAccounting.movePendingDepositToClaimable(controller, assets);
        emit VaultDepositRequestSettled(controller, assets, msg.sender);
    }

    /// @notice Moves pending redeem shares into claimable state for `controller`.
    /// @param controller Request controller account.
    /// @param shares Share amount to settle.
    function settleRedeemRequest(address controller, uint256 shares) public {
        _requireInitialized();
        _checkRole(VAULT_MANAGER_ROLE(), msg.sender);
        _requireScopeNotPaused(ASYNC_SETTLEMENT_SCOPE());

        LibERC7540RequestAccounting.movePendingRedeemToClaimable(controller, shares);
        emit VaultRedeemRequestSettled(controller, shares, msg.sender);
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

    function _availableIdleAssetsForStrategyDeploy() internal view returns (uint256) {
        LibERC4626VaultStorage.Layout storage layout = LibERC4626VaultStorage.layout();
        uint256 actualIdleAssets = _idleAssetBalance();
        uint256 idleBookAssets = layout.totalManagedAssets - layout.strategyDebt;
        return actualIdleAssets < idleBookAssets ? actualIdleAssets : idleBookAssets;
    }
}
