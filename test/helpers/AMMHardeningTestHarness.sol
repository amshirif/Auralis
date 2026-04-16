// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AMMPair} from "../../src/amm/AMMPair.sol";
import {MockAMMToken} from "./AMMPairTestHarness.sol";
import {AMMRouterFixture} from "./AMMRouterTestHarness.sol";

abstract contract AMMHardeningFixture is AMMRouterFixture {
    uint256 internal constant ACTOR_COUNT = 4;
    uint256 internal constant PAIR_COUNT = 5;
    uint256 internal constant TRACKED_TOKEN_COUNT = 4;
    uint256 internal constant INITIAL_TOKEN_BALANCE = 5_000_000;
    uint256 internal constant INITIAL_NATIVE_BALANCE = 5_000_000;
    address internal dave = address(0xD0D);
    address[ACTOR_COUNT] internal actors;
    address[PAIR_COUNT] internal trackedPairs;
    address[TRACKED_TOKEN_COUNT] internal trackedTokens;
    uint256[PAIR_COUNT] internal expectedKLasts;

    AMMPair internal pair01;
    AMMPair internal pair12;
    AMMPair internal pair02;
    AMMPair internal pair0W;
    AMMPair internal pair1W;

    function setUp() public virtual override {
        super.setUp();

        actors[0] = alice;
        actors[1] = bob;
        actors[2] = carol;
        actors[3] = dave;

        trackedTokens[0] = address(token0);
        trackedTokens[1] = address(token1);
        trackedTokens[2] = address(token2);
        trackedTokens[3] = address(wrappedNativeToken);

        _fundActors();
        _approveTrackedAssets();
        _seedTrackedPairs();
        _approveTrackedPairs();
    }

    function _actor(uint256 seed) internal view returns (address actor) {
        actor = actors[seed % ACTOR_COUNT];
    }

    function _boundAmount(uint256 raw, uint256 max) internal pure returns (uint256 amount) {
        if (max == 0) {
            return 0;
        }

        amount = (raw % max) + 1;
    }

    function _trackedPair(uint256 seed) internal view returns (AMMPair pair_) {
        pair_ = AMMPair(trackedPairs[seed % PAIR_COUNT]);
    }

    function _pairIndex(address pairAddress) internal view returns (uint256 index) {
        for (uint256 i = 0; i < PAIR_COUNT; i++) {
            if (trackedPairs[i] == pairAddress) {
                return i;
            }
        }

        revert("UNKNOWN_PAIR");
    }

    function _trackedToken(uint256 seed) internal view returns (MockAMMToken token_) {
        token_ = MockAMMToken(trackedTokens[seed % TRACKED_TOKEN_COUNT]);
    }

    function _tokenSwapPath(uint256 seed) internal view returns (address[] memory path_) {
        uint256 selector = seed % 6;
        if (selector == 0) {
            return _path(address(token0), address(token1));
        }
        if (selector == 1) {
            return _path(address(token1), address(token2));
        }
        if (selector == 2) {
            return _path(address(token0), address(token2));
        }
        if (selector == 3) {
            return _path(address(token0), address(token1), address(token2));
        }
        if (selector == 4) {
            return _path(address(token2), address(token1), address(token0));
        }
        return _path(address(token2), address(token0), address(token1));
    }

    function _nativeInPath(uint256 seed) internal view returns (address[] memory path_) {
        uint256 selector = seed % 4;
        if (selector == 0) {
            return _path(address(wrappedNativeToken), address(token0));
        }
        if (selector == 1) {
            return _path(address(wrappedNativeToken), address(token1));
        }
        if (selector == 2) {
            return _path(address(wrappedNativeToken), address(token1), address(token2));
        }
        return _path(address(wrappedNativeToken), address(token0), address(token2));
    }

    function _nativeOutPath(uint256 seed) internal view returns (address[] memory path_) {
        uint256 selector = seed % 4;
        if (selector == 0) {
            return _path(address(token0), address(wrappedNativeToken));
        }
        if (selector == 1) {
            return _path(address(token1), address(wrappedNativeToken));
        }
        if (selector == 2) {
            return _path(address(token2), address(token1), address(wrappedNativeToken));
        }
        return _path(address(token2), address(token0), address(wrappedNativeToken));
    }

    function _getAlignedReserves(address tokenA_, address tokenB_)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        address pairAddress = factory.getPair(tokenA_, tokenB_);
        if (pairAddress == address(0)) {
            return (0, 0);
        }

        AMMPair pair_ = AMMPair(pairAddress);
        (uint112 reserve0_, uint112 reserve1_,) = pair_.getReserves();
        if (pair_.token0() == tokenA_) {
            return (reserve0_, reserve1_);
        }
        return (reserve1_, reserve0_);
    }

    function _recordLiquidityEvent(address pairAddress) internal {
        uint256 pairIdx = _pairIndex(pairAddress);
        if (factory.feeTo() == address(0)) {
            expectedKLasts[pairIdx] = 0;
            return;
        }

        (uint112 reserve0_, uint112 reserve1_,) = AMMPair(pairAddress).getReserves();
        expectedKLasts[pairIdx] = uint256(reserve0_) * uint256(reserve1_);
    }

    function _sumTrackedLpBalances(AMMPair pair_) internal view returns (uint256 sum) {
        sum += pair_.balanceOf(BURN_SINK);
        sum += pair_.balanceOf(address(pair_));
        sum += pair_.balanceOf(address(router));
        sum += pair_.balanceOf(address(this));

        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            sum += pair_.balanceOf(actors[i]);
        }
    }

    function _assertRouterZeroBalances() internal view {
        assertTrue(address(router).balance == 0, "router native balance should be zero");

        for (uint256 i = 0; i < TRACKED_TOKEN_COUNT; i++) {
            assertTrue(
                MockAMMToken(trackedTokens[i]).balanceOf(address(router)) == 0, "router token balance should be zero"
            );
        }
    }

    function _assertPairRegistered(AMMPair pair_) internal view {
        address tokenA_ = pair_.token0();
        address tokenB_ = pair_.token1();

        assertTrue(factory.getPair(tokenA_, tokenB_) == address(pair_), "forward pair lookup mismatch");
        assertTrue(factory.getPair(tokenB_, tokenA_) == address(pair_), "reverse pair lookup mismatch");
    }

    function _assertPairReservesDoNotExceedBalances(AMMPair pair_) internal view {
        (uint112 reserve0_, uint112 reserve1_,) = pair_.getReserves();
        assertTrue(
            reserve0_ <= MockAMMToken(pair_.token0()).balanceOf(address(pair_)),
            "reserve0 should not exceed token0 balance"
        );
        assertTrue(
            reserve1_ <= MockAMMToken(pair_.token1()).balanceOf(address(pair_)),
            "reserve1 should not exceed token1 balance"
        );
    }

    function _assertTrackedAmmState() internal view {
        _assertRouterZeroBalances();

        for (uint256 i = 0; i < PAIR_COUNT; i++) {
            AMMPair trackedPair = AMMPair(trackedPairs[i]);
            _assertPairRegistered(trackedPair);
            _assertPairReservesDoNotExceedBalances(trackedPair);
            assertTrue(trackedPair.totalSupply() == _sumTrackedLpBalances(trackedPair), "tracked lp supply mismatch");
            assertTrue(trackedPair.kLast() == expectedKLasts[i], "tracked kLast mismatch");

            if (trackedPair.totalSupply() != 0) {
                assertTrue(
                    trackedPair.balanceOf(BURN_SINK) == trackedPair.MINIMUM_LIQUIDITY(),
                    "minimum liquidity sink mismatch"
                );
            }
        }
    }

    function _seedWrappedToken(address actor, uint256 amount) internal {
        if (amount == 0) {
            return;
        }

        VM.prank(actor);
        wrappedNativeToken.deposit{value: amount}();
    }

    function _fundActors() internal {
        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            address actor = actors[i];
            token0.mint(actor, INITIAL_TOKEN_BALANCE);
            token1.mint(actor, INITIAL_TOKEN_BALANCE);
            token2.mint(actor, INITIAL_TOKEN_BALANCE);
            VM.deal(actor, INITIAL_NATIVE_BALANCE);
        }
    }

    function _approveTrackedAssets() internal {
        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            address actor = actors[i];
            VM.startPrank(actor);
            token0.approve(address(router), type(uint256).max);
            token1.approve(address(router), type(uint256).max);
            token2.approve(address(router), type(uint256).max);
            wrappedNativeToken.approve(address(router), type(uint256).max);
            VM.stopPrank();
        }
    }

    function _approveTrackedPairs() internal {
        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            address actor = actors[i];
            VM.startPrank(actor);
            for (uint256 j = 0; j < PAIR_COUNT; j++) {
                AMMPair(trackedPairs[j]).approve(address(router), type(uint256).max);
            }
            VM.stopPrank();
        }
    }

    function _seedTrackedPairs() internal {
        pair01 = _seedTokenPair(alice, token0, token1, 500_000, 500_000);
        pair12 = _seedTokenPair(alice, token1, token2, 500_000, 250_000);
        pair02 = _seedTokenPair(alice, token0, token2, 400_000, 300_000);
        pair0W = _seedNativePair(alice, token0, 350_000, 350_000);
        pair1W = _seedNativePair(alice, token1, 300_000, 450_000);

        trackedPairs[0] = address(pair01);
        trackedPairs[1] = address(pair12);
        trackedPairs[2] = address(pair02);
        trackedPairs[3] = address(pair0W);
        trackedPairs[4] = address(pair1W);
    }

    function _seedTokenPair(
        address provider,
        MockAMMToken tokenA_,
        MockAMMToken tokenB_,
        uint256 amountA,
        uint256 amountB
    ) internal returns (AMMPair pair_) {
        VM.prank(provider);
        router.addLiquidity(address(tokenA_), address(tokenB_), amountA, amountB, 0, 0, provider, DEADLINE);

        pair_ = AMMPair(factory.getPair(address(tokenA_), address(tokenB_)));
    }

    function _seedNativePair(address provider, MockAMMToken token_, uint256 amountToken, uint256 amountNative)
        internal
        returns (AMMPair pair_)
    {
        VM.prank(provider);
        router.addLiquidityNative{value: amountNative}(address(token_), amountToken, 0, 0, provider, DEADLINE);

        pair_ = AMMPair(factory.getPair(address(token_), address(wrappedNativeToken)));
    }
}
