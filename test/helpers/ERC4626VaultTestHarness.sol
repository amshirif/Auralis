// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC4626VaultBase} from "../../src/vault/ERC4626VaultBase.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

contract MockAssetWithDecimals {
    uint8 internal _decimals;

    constructor(uint8 decimals_) {
        _decimals = decimals_;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }
}

contract NoMetadataAsset {}

contract ERC4626VaultHarness is ERC4626VaultBase {
    function initialize(address vaultAsset, string calldata vaultName, string calldata vaultSymbol) external {
        _initializeErc4626Vault(vaultAsset, vaultName, vaultSymbol);
    }

    function mintShares(address account, uint256 shares) external {
        _mintShares(account, shares);
    }

    function burnShares(address account, uint256 shares) external {
        _burnShares(account, shares);
    }

    function addManagedAssets(uint256 assets) external {
        _increaseManagedAssets(assets);
    }

    function removeManagedAssets(uint256 assets) external {
        _decreaseManagedAssets(assets);
    }

    function convertToSharesDown(uint256 assets) external view returns (uint256) {
        return _convertToShares(assets, Rounding.Down);
    }

    function convertToSharesUp(uint256 assets) external view returns (uint256) {
        return _convertToShares(assets, Rounding.Up);
    }

    function convertToAssetsDown(uint256 shares) external view returns (uint256) {
        return _convertToAssets(shares, Rounding.Down);
    }

    function convertToAssetsUp(uint256 shares) external view returns (uint256) {
        return _convertToAssets(shares, Rounding.Up);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transferShares(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _setAllowance(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _transferShares(from, to, value);
        return true;
    }

    function transferFromNoReturn(address from, address to, uint256 value) external {
        _spendAllowance(from, msg.sender, value);
        _transferShares(from, to, value);
    }
}

abstract contract ERC4626VaultFixture is TestBase {
    address internal admin = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal eve = address(0xE11E);

    MockAssetWithDecimals internal asset;
    ERC4626VaultHarness internal vault;

    function setUp() public virtual {
        asset = new MockAssetWithDecimals(6);
        vault = new ERC4626VaultHarness();
    }

    function _initializeVault() internal {
        vault.initialize(address(asset), "Vault Share", "vSHARE");
    }
}
