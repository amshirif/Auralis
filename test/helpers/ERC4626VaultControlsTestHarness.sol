// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC4626VaultControls} from "../../src/vault/ERC4626VaultControls.sol";
import {MockVaultAsset} from "./ERC4626CoreTestHarness.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

contract ReentrantMockVaultAsset is MockVaultAsset {
    bool internal _reenterOnTransferFrom;
    bool internal _reentryAttemptBlocked;
    address internal _reentryTarget;
    bytes internal _reentryPayload;

    constructor() MockVaultAsset("Mock USD", "mUSD", 6) {}

    function configureReentry(address target, bytes calldata payload, bool enabled) external {
        _reentryTarget = target;
        _reentryPayload = payload;
        _reenterOnTransferFrom = enabled;
        _reentryAttemptBlocked = false;
    }

    function reentryAttemptBlocked() external view returns (bool) {
        return _reentryAttemptBlocked;
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        bool success = super.transferFrom(from, to, value);
        if (_reenterOnTransferFrom) {
            (bool callbackSuccess,) = _reentryTarget.call(_reentryPayload);
            if (!callbackSuccess) {
                _reentryAttemptBlocked = true;
            }
        }
        return success;
    }
}

contract ERC4626VaultControlsHarness is ERC4626VaultControls {
    constructor(address initialAdmin, address vaultAsset, string memory vaultName, string memory vaultSymbol)
        ERC4626VaultControls(initialAdmin, vaultAsset, vaultName, vaultSymbol)
    {}

    function probeNonReentrant() external nonReentrant returns (bool) {
        return true;
    }
}

abstract contract ERC4626VaultControlsFixture is TestBase {
    uint256 internal constant INITIAL_ASSETS = 1_000_000;

    address internal admin = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal eve = address(0xE11E);

    ReentrantMockVaultAsset internal asset;
    ERC4626VaultControlsHarness internal vault;

    function setUp() public virtual {
        asset = new ReentrantMockVaultAsset();
        vault = new ERC4626VaultControlsHarness(admin, address(asset), "Vault Share", "vSHARE");

        asset.mint(bob, INITIAL_ASSETS);
        asset.mint(eve, INITIAL_ASSETS);
    }

    function _approveAsset(address owner, uint256 amount) internal {
        VM.prank(owner);
        asset.approve(address(vault), amount);
    }

    function _seedPosition(address owner, uint256 assetsAmount) internal {
        asset.mint(owner, assetsAmount);
        VM.prank(owner);
        asset.approve(address(vault), assetsAmount);
        VM.prank(owner);
        vault.deposit(assetsAmount, owner);
    }
}
