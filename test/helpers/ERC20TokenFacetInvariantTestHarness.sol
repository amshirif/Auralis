// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20TokenFacet} from "../../src/interfaces/IERC20TokenFacet.sol";
import {ERC20TokenFacetFixture} from "./ERC20TokenFacetTestHarness.sol";

abstract contract ERC20TokenFacetInvariantFixture is ERC20TokenFacetFixture {
    struct AccountingSnapshot {
        uint256 totalSupply;
        uint256 totalTrackedBalances;
    }

    uint256 internal constant ACTOR_COUNT = 4;
    uint256 internal constant INITIAL_BALANCE = 1_000_000;

    address[ACTOR_COUNT] internal actors;
    uint256[ACTOR_COUNT] internal actorKeys;
    mapping(address => uint256) internal trackedPermitSuccesses;

    function setUp() public virtual override {
        super.setUp();
        _erc20Init(address(facet));

        actors[0] = bob;
        actors[1] = eve;
        actors[2] = carol;
        actors[3] = dave;

        actorKeys[0] = BOB_PK;
        actorKeys[1] = EVE_PK;
        actorKeys[2] = CAROL_PK;
        actorKeys[3] = DAVE_PK;

        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            VM.prank(admin);
            IERC20TokenFacet(address(facet)).mint(actors[i], INITIAL_BALANCE);
        }
    }

    function _actor(uint8 seed) internal view returns (address) {
        return actors[uint256(seed) % ACTOR_COUNT];
    }

    function _actorKey(uint8 seed) internal view returns (uint256) {
        return actorKeys[uint256(seed) % ACTOR_COUNT];
    }

    function _boundAmount(uint256 raw, uint256 max) internal pure returns (uint256) {
        if (max == 0) {
            return 0;
        }
        return (raw % max) + 1;
    }

    function _sumTrackedBalances() internal view returns (uint256 sum) {
        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            sum += IERC20TokenFacet(address(facet)).balanceOf(actors[i]);
        }
    }

    function _snapshotAccounting() internal view returns (AccountingSnapshot memory snapshot) {
        snapshot.totalSupply = IERC20TokenFacet(address(facet)).totalSupply();
        snapshot.totalTrackedBalances = _sumTrackedBalances();
    }

    function _assertAccountingUnchanged(AccountingSnapshot memory snapshot, string memory reason) internal view {
        assertTrue(IERC20TokenFacet(address(facet)).totalSupply() == snapshot.totalSupply, reason);
        assertTrue(_sumTrackedBalances() == snapshot.totalTrackedBalances, reason);
    }
}
