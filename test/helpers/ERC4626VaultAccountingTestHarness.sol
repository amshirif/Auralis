// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {MockVaultAsset, ERC4626VaultCoreHarness} from "./ERC4626CoreTestHarness.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

abstract contract ERC4626VaultAccountingFixture is TestBase {
    uint256 internal constant INITIAL_ASSETS = 1_000_000;
    uint256 internal constant ACTOR_COUNT = 4;

    address internal admin = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA11);
    address internal dave = address(0xD0D);

    MockVaultAsset internal asset;
    ERC4626VaultCoreHarness internal vault;
    address[ACTOR_COUNT] internal actors;

    function setUp() public virtual {
        asset = new MockVaultAsset("Mock USD", "mUSD", 6);
        vault = new ERC4626VaultCoreHarness();
        vault.initialize(address(asset), "Vault Share", "vSHARE");

        actors[0] = admin;
        actors[1] = bob;
        actors[2] = carol;
        actors[3] = dave;

        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            address actor = actors[i];
            asset.mint(actor, INITIAL_ASSETS);
            VM.prank(actor);
            asset.approve(address(vault), type(uint256).max);
        }
    }

    function _actor(uint8 seed) internal view returns (address) {
        return actors[uint256(seed) % ACTOR_COUNT];
    }

    function _boundAmount(uint256 raw, uint256 max) internal pure returns (uint256) {
        if (max == 0) {
            return 0;
        }
        return (raw % max) + 1;
    }

    function _min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

    function _sumActorShareBalances() internal view returns (uint256 sum) {
        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            sum += vault.balanceOf(actors[i]);
        }
    }

    function _sumActorAssetBalances() internal view returns (uint256 sum) {
        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            sum += asset.balanceOf(actors[i]);
        }
    }

    function _seedLowLiquidityState() internal {
        vault.seedPosition(admin, 3, 2);
        asset.mint(address(vault), 2);
    }
}
