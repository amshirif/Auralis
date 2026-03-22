// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "../../src/interfaces/IERC165.sol";
import {IERC4626VaultControlsFacet} from "../../src/interfaces/IERC4626VaultControlsFacet.sol";
import {ERC4626VaultBase} from "../../src/vault/ERC4626VaultBase.sol";
import {VaultFacetControl} from "../../src/vault/VaultFacetControl.sol";
import {LibERC4626VaultStorage} from "../../src/vault/storage/LibERC4626VaultStorage.sol";
import {TestBase} from "./AccessControlTestHarness.sol";
import {MockAssetWithDecimals, NoMetadataAsset} from "./ERC4626VaultTestHarness.sol";

contract HostedVaultFacetFoundationHarness is ERC4626VaultBase, VaultFacetControl {
    function initializeVault(address vaultAsset, string calldata vaultName, string calldata vaultSymbol, address admin)
        external
    {
        _initializeErc4626Vault(vaultAsset, vaultName, vaultSymbol);
        _initializeVaultFacetControl(admin);
    }

    function initializeControlOnly(address admin) external {
        _initializeVaultFacetControl(admin);
    }

    function feeRecipient() external view returns (address) {
        return LibERC4626VaultStorage.layout().fees.feeRecipient;
    }

    function controlPlaneInitialized() external view returns (bool) {
        return LibERC4626VaultStorage.layout().controlPlaneInitialized;
    }

    function probeNonReentrant() external nonReentrant returns (bool) {
        return true;
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

    function supportsInterface(bytes4 interfaceId) public view override(VaultFacetControl) returns (bool) {
        return
            interfaceId == type(IERC4626VaultControlsFacet).interfaceId
                || VaultFacetControl.supportsInterface(interfaceId);
    }
}

abstract contract VaultFacetFoundationFixture is TestBase {
    address internal admin = address(0xA11CE);
    address internal bob = address(0xB0B);

    MockAssetWithDecimals internal asset;
    HostedVaultFacetFoundationHarness internal vault;

    function setUp() public virtual {
        asset = new MockAssetWithDecimals(6);
        vault = new HostedVaultFacetFoundationHarness();
    }

    function _initializeVault() internal {
        vault.initializeVault(address(asset), "Vault Share", "vSHARE", admin);
    }

    function _newNoMetadataAsset() internal returns (NoMetadataAsset) {
        return new NoMetadataAsset();
    }
}
