// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC4626VaultStrategy} from "../../src/interfaces/IERC4626VaultStrategy.sol";
import {ERC4626VaultIntegrationFacet} from "../../src/vault/facets/ERC4626VaultIntegrationFacet.sol";
import {LibERC4626VaultStorage} from "../../src/vault/storage/LibERC4626VaultStorage.sol";
import {TestBase} from "./AccessControlTestHarness.sol";
import {MockVaultAsset} from "./ERC4626CoreTestHarness.sol";

contract ERC4626VaultStrategyStorageHarness is ERC4626VaultIntegrationFacet {
    function initializeHostedVaultForStrategyTest(
        address vaultAsset,
        string memory vaultName,
        string memory vaultSymbol,
        address admin
    ) external {
        _initializeVaultFacetControl(admin);
        _initializeErc4626Vault(vaultAsset, vaultName, vaultSymbol);
    }

    function strategyDebtForTest() external view returns (uint256) {
        return LibERC4626VaultStorage.layout().strategyDebt;
    }

    function strategyEmergencyExitForTest() external view returns (bool) {
        return LibERC4626VaultStorage.layout().strategyEmergencyExit;
    }
}

error MockVaultStrategyForcedRevert(bytes4 selector);

abstract contract MockVaultStrategyBase is IERC4626VaultStrategy {
    address internal immutable _vault;
    address internal immutable _asset;

    uint256 internal _trackedAssets;
    uint256 internal _withdrawableAssets;

    constructor(address vault_, address asset_) {
        _vault = vault_;
        _asset = asset_;
    }

    modifier onlyVault() {
        if (msg.sender != _vault) {
            revert ERC4626VaultStrategyOnlyVault(msg.sender, _vault);
        }
        _;
    }

    function vault() external view override returns (address) {
        return _vault;
    }

    function asset() external view override returns (address) {
        return _asset;
    }

    function totalAssets() public view virtual override returns (uint256) {
        return _trackedAssets;
    }

    function maxWithdrawableAssets() public view virtual override returns (uint256) {
        return _min(_trackedAssets, _withdrawableAssets);
    }

    function deployFunds(uint256 assets) external virtual override onlyVault {
        _trackedAssets += assets;
        _withdrawableAssets += assets;
    }

    function withdrawToVault(uint256 assets) external virtual override onlyVault returns (uint256 assetsReturned) {
        assetsReturned = _min(assets, maxWithdrawableAssets());
        _trackedAssets -= assetsReturned;
        _withdrawableAssets -= assetsReturned;
    }

    function withdrawAllToVault() external virtual override onlyVault returns (uint256 assetsReturned) {
        assetsReturned = maxWithdrawableAssets();
        _trackedAssets -= assetsReturned;
        _withdrawableAssets -= assetsReturned;
    }

    function setWithdrawableAssets(uint256 assets) external {
        _withdrawableAssets = _min(assets, _trackedAssets);
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

contract ProfitMockVaultStrategy is MockVaultStrategyBase {
    constructor(address vault_, address asset_) MockVaultStrategyBase(vault_, asset_) {}

    function injectProfit(uint256 assets) external {
        _trackedAssets += assets;
        _withdrawableAssets += assets;
    }
}

contract LossShortfallMockVaultStrategy is MockVaultStrategyBase {
    constructor(address vault_, address asset_) MockVaultStrategyBase(vault_, asset_) {}

    function applyLoss(uint256 lossAssets, uint256 withdrawableAssets_) external {
        _trackedAssets = lossAssets >= _trackedAssets ? 0 : _trackedAssets - lossAssets;
        _withdrawableAssets = _min(withdrawableAssets_, _trackedAssets);
    }
}

contract RevertingMockVaultStrategy is MockVaultStrategyBase {
    bool internal _revertTotalAssets;
    bool internal _revertDeployFunds;
    bool internal _revertWithdrawToVault;
    bool internal _revertWithdrawAllToVault;

    constructor(address vault_, address asset_) MockVaultStrategyBase(vault_, asset_) {}

    function setRevertModes(bool totalAssets_, bool deployFunds_, bool withdrawToVault_, bool withdrawAllToVault_)
        external
    {
        _revertTotalAssets = totalAssets_;
        _revertDeployFunds = deployFunds_;
        _revertWithdrawToVault = withdrawToVault_;
        _revertWithdrawAllToVault = withdrawAllToVault_;
    }

    function totalAssets() public view override returns (uint256) {
        if (_revertTotalAssets) {
            revert MockVaultStrategyForcedRevert(this.totalAssets.selector);
        }
        return super.totalAssets();
    }

    function deployFunds(uint256 assets) external override onlyVault {
        if (_revertDeployFunds) {
            revert MockVaultStrategyForcedRevert(this.deployFunds.selector);
        }
        _trackedAssets += assets;
        _withdrawableAssets += assets;
    }

    function withdrawToVault(uint256 assets) external override onlyVault returns (uint256 assetsReturned) {
        if (_revertWithdrawToVault) {
            revert MockVaultStrategyForcedRevert(this.withdrawToVault.selector);
        }
        assetsReturned = _min(assets, maxWithdrawableAssets());
        _trackedAssets -= assetsReturned;
        _withdrawableAssets -= assetsReturned;
    }

    function withdrawAllToVault() external override onlyVault returns (uint256 assetsReturned) {
        if (_revertWithdrawAllToVault) {
            revert MockVaultStrategyForcedRevert(this.withdrawAllToVault.selector);
        }
        assetsReturned = maxWithdrawableAssets();
        _trackedAssets -= assetsReturned;
        _withdrawableAssets -= assetsReturned;
    }
}

contract EmergencyUnwindMockVaultStrategy is MockVaultStrategyBase {
    constructor(address vault_, address asset_) MockVaultStrategyBase(vault_, asset_) {}

    function withdrawAllToVault() external override onlyVault returns (uint256 assetsReturned) {
        assetsReturned = _trackedAssets;
        _trackedAssets = 0;
        _withdrawableAssets = 0;
    }
}

abstract contract ERC4626VaultStrategyFixture is TestBase {
    address internal admin = address(0xA11CE);
    address internal vault = address(0xA417);
    address internal outsider = address(0x0B5E1D3);

    MockVaultAsset internal asset;
    ERC4626VaultStrategyStorageHarness internal storageHarness;
    ProfitMockVaultStrategy internal profitStrategy;
    LossShortfallMockVaultStrategy internal lossStrategy;
    RevertingMockVaultStrategy internal revertingStrategy;
    EmergencyUnwindMockVaultStrategy internal unwindStrategy;

    function setUp() public virtual {
        asset = new MockVaultAsset("Mock USD", "mUSD", 6);
        storageHarness = new ERC4626VaultStrategyStorageHarness();
        storageHarness.initializeHostedVaultForStrategyTest(address(asset), "Vault Share", "vSHARE", admin);

        profitStrategy = new ProfitMockVaultStrategy(vault, address(asset));
        lossStrategy = new LossShortfallMockVaultStrategy(vault, address(asset));
        revertingStrategy = new RevertingMockVaultStrategy(vault, address(asset));
        unwindStrategy = new EmergencyUnwindMockVaultStrategy(vault, address(asset));
    }
}
