// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../../interfaces/IAccessControl.sol";
import {IAccessControlTime} from "../../interfaces/IAccessControlTime.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {IERC20Metadata} from "../../interfaces/IERC20Metadata.sol";
import {IERC165} from "../../interfaces/IERC165.sol";
import {IERC4626} from "../../interfaces/IERC4626.sol";
import {IERC7535VaultFacet} from "../../interfaces/IERC7535VaultFacet.sol";
import {IERC4626VaultBase} from "../../interfaces/IERC4626VaultBase.sol";
import {IERC4626VaultControls} from "../../interfaces/IERC4626VaultControls.sol";
import {IERC4626VaultFacet} from "../../interfaces/IERC4626VaultFacet.sol";
import {IERC4626VaultIntegrationFacet} from "../../interfaces/IERC4626VaultIntegrationFacet.sol";
import {IPausable} from "../../interfaces/IPausable.sol";
import {IReentrancyGuard} from "../../interfaces/IReentrancyGuard.sol";

/// @title LibVaultFacetSelectors
/// @notice Canonical selector groups for hosted vault facet splits.
library LibVaultFacetSelectors {
    /// @notice Returns the hosted vault core selector group.
    function vaultCoreSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](28);
        selectors[0] = IERC4626VaultFacet.initializeVault.selector;
        selectors[1] = IERC4626VaultBase.isVaultInitialized.selector;
        selectors[2] = IERC4626.asset.selector;
        selectors[3] = IERC4626VaultBase.totalManagedAssets.selector;
        selectors[4] = IERC20Metadata.name.selector;
        selectors[5] = IERC20Metadata.symbol.selector;
        selectors[6] = IERC20Metadata.decimals.selector;
        selectors[7] = IERC20.totalSupply.selector;
        selectors[8] = IERC20.balanceOf.selector;
        selectors[9] = IERC20.allowance.selector;
        selectors[10] = IERC20.transfer.selector;
        selectors[11] = IERC20.approve.selector;
        selectors[12] = IERC20.transferFrom.selector;
        selectors[13] = IERC4626.totalAssets.selector;
        selectors[14] = IERC4626.convertToShares.selector;
        selectors[15] = IERC4626.convertToAssets.selector;
        selectors[16] = IERC4626.maxDeposit.selector;
        selectors[17] = IERC4626.previewDeposit.selector;
        selectors[18] = IERC4626.deposit.selector;
        selectors[19] = IERC4626.maxMint.selector;
        selectors[20] = IERC4626.previewMint.selector;
        selectors[21] = IERC4626.mint.selector;
        selectors[22] = IERC4626.maxWithdraw.selector;
        selectors[23] = IERC4626.previewWithdraw.selector;
        selectors[24] = IERC4626.withdraw.selector;
        selectors[25] = IERC4626.maxRedeem.selector;
        selectors[26] = IERC4626.previewRedeem.selector;
        selectors[27] = IERC4626.redeem.selector;
    }

    /// @notice Returns the hosted vault native selector group.
    function vaultNativeSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](2);
        selectors[0] = IERC7535VaultFacet.depositNative.selector;
        selectors[1] = IERC7535VaultFacet.mintNative.selector;
    }

    /// @notice Returns the hosted vault controls selector group.
    function vaultControlsSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](28);
        selectors[0] = IERC4626VaultControls.VAULT_MANAGER_ROLE.selector;
        selectors[1] = IERC4626VaultControls.feeConfig.selector;
        selectors[2] = IERC4626VaultControls.limitConfig.selector;
        selectors[3] = IERC4626VaultControls.setFeeConfig.selector;
        selectors[4] = IERC4626VaultControls.setLimitConfig.selector;
        selectors[5] = IAccessControl.DEFAULT_ADMIN_ROLE.selector;
        selectors[6] = IPausable.PAUSER_ROLE.selector;
        selectors[7] = IAccessControl.hasRole.selector;
        selectors[8] = IAccessControl.getRoleAdmin.selector;
        selectors[9] = IAccessControl.grantRole.selector;
        selectors[10] = IAccessControl.revokeRole.selector;
        selectors[11] = IAccessControl.renounceRole.selector;
        selectors[12] = IAccessControl.getRoleMember.selector;
        selectors[13] = IAccessControl.getRoleMemberCount.selector;
        selectors[14] = IAccessControlTime.grantRoleWithWindow.selector;
        selectors[15] = IAccessControlTime.setRoleWindow.selector;
        selectors[16] = IAccessControlTime.clearRoleWindow.selector;
        selectors[17] = IAccessControlTime.getRoleWindow.selector;
        selectors[18] = IAccessControlTime.hasActiveRole.selector;
        selectors[19] = bytes4(keccak256("paused()"));
        selectors[20] = bytes4(keccak256("paused(bytes32)"));
        selectors[21] = IPausable.scopePaused.selector;
        selectors[22] = IPausable.pause.selector;
        selectors[23] = IPausable.unpause.selector;
        selectors[24] = IPausable.pauseScope.selector;
        selectors[25] = IPausable.unpauseScope.selector;
        selectors[26] = IReentrancyGuard.reentrancyGuardEntered.selector;
        selectors[27] = IERC165.supportsInterface.selector;
    }

    /// @notice Returns the hosted vault integration selector group.
    function vaultIntegrationSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](13);
        selectors[0] = IERC4626VaultIntegrationFacet.oracleAdapter.selector;
        selectors[1] = IERC4626VaultIntegrationFacet.strategy.selector;
        selectors[2] = IERC4626VaultIntegrationFacet.strategyEmergencyExit.selector;
        selectors[3] = IERC4626VaultIntegrationFacet.strategyDebt.selector;
        selectors[4] = IERC4626VaultIntegrationFacet.idleAssets.selector;
        selectors[5] = IERC4626VaultIntegrationFacet.liveStrategyAssets.selector;
        selectors[6] = IERC4626VaultIntegrationFacet.oracleQuote.selector;
        selectors[7] = IERC4626VaultIntegrationFacet.setOracleAdapter.selector;
        selectors[8] = IERC4626VaultIntegrationFacet.setStrategy.selector;
        selectors[9] = IERC4626VaultIntegrationFacet.deployToStrategy.selector;
        selectors[10] = IERC4626VaultIntegrationFacet.withdrawFromStrategy.selector;
        selectors[11] = IERC4626VaultIntegrationFacet.syncStrategyAssets.selector;
        selectors[12] = IERC4626VaultIntegrationFacet.emergencyExitStrategy.selector;
    }
}
