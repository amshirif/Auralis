// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AMMPair} from "../src/amm/AMMPair.sol";
import {MockAMMToken} from "./helpers/AMMPairTestHarness.sol";
import {AMMPairCoreFixture} from "./helpers/AMMPairTestHarness.sol";

contract AMMPairFuzzTest is AMMPairCoreFixture {
    function testFuzzFirstMintLocksMinimumLiquidity(uint96 amount0Raw, uint96 amount1Raw) public {
        AMMPair localPair = _deployPair(address(token0), address(token1));
        uint256 amount0 = _boundAmount(amount0Raw, 1_000_000);
        uint256 amount1 = _boundAmount(amount1Raw, 1_000_000);
        uint256 rootK = _mathSqrt(amount0 * amount1);
        if (rootK <= localPair.MINIMUM_LIQUIDITY()) {
            return;
        }

        uint256 liquidity = _provideLiquidity(localPair, token0, token1, alice, amount0, amount1, alice);

        assertTrue(liquidity == rootK - localPair.MINIMUM_LIQUIDITY(), "first mint liquidity mismatch");
        assertTrue(localPair.balanceOf(BURN_SINK) == localPair.MINIMUM_LIQUIDITY(), "minimum liquidity sink mismatch");
        assertTrue(localPair.balanceOf(alice) == liquidity, "provider lp balance mismatch");
    }

    function testFuzzLaterMintFollowsReserveRatio(uint96 firstAmount0Raw, uint96 secondAmount0Raw) public {
        AMMPair localPair = _deployPair(address(token0), address(token1));
        uint256 firstAmount0 = _boundAmount(firstAmount0Raw, 1_000_000);
        uint256 firstAmount1 = firstAmount0 * 2;
        uint256 rootK = _mathSqrt(firstAmount0 * firstAmount1);
        if (rootK <= localPair.MINIMUM_LIQUIDITY()) {
            return;
        }

        _provideLiquidity(localPair, token0, token1, alice, firstAmount0, firstAmount1, alice);

        uint256 secondAmount0 = _boundAmount(secondAmount0Raw, 500_000);
        uint256 secondAmount1 = secondAmount0 * 2;
        uint256 totalSupplyBefore = localPair.totalSupply();
        (uint112 reserve0Before, uint112 reserve1Before,) = localPair.getReserves();

        uint256 liquidity = _provideLiquidity(localPair, token0, token1, bob, secondAmount0, secondAmount1, bob);
        uint256 expectedLiquidity = _mathMin(
            (secondAmount0 * totalSupplyBefore) / reserve0Before, (secondAmount1 * totalSupplyBefore) / reserve1Before
        );

        assertTrue(liquidity == expectedLiquidity, "later mint liquidity mismatch");
    }

    function testFuzzBurnRedeemsProRata(uint96 amount0Raw, uint96 burnRaw) public {
        AMMPair localPair = _deployPair(address(token0), address(token1));
        uint256 amount0 = _boundAmount(amount0Raw, 1_000_000);
        uint256 amount1 = amount0;
        uint256 rootK = _mathSqrt(amount0 * amount1);
        if (rootK <= localPair.MINIMUM_LIQUIDITY()) {
            return;
        }

        _provideLiquidity(localPair, token0, token1, alice, amount0, amount1, alice);

        uint256 burnLiquidity = _boundAmount(burnRaw, localPair.balanceOf(alice));
        uint256 totalSupplyBefore = localPair.totalSupply();
        (uint112 reserve0Before, uint112 reserve1Before,) = localPair.getReserves();
        uint256 expectedAmount0 = (burnLiquidity * reserve0Before) / totalSupplyBefore;
        uint256 expectedAmount1 = (burnLiquidity * reserve1Before) / totalSupplyBefore;

        VM.prank(alice);
        localPair.transfer(address(localPair), burnLiquidity);

        (uint256 amount0Out, uint256 amount1Out) = localPair.burn(alice);

        assertTrue(amount0Out == expectedAmount0, "burn amount0 mismatch");
        assertTrue(amount1Out == expectedAmount1, "burn amount1 mismatch");
    }

    function testFuzzSwapRespectsQuotedOutput(uint96 amountInRaw) public {
        _provideLiquidity(pair, token0, token1, alice, 500_000, 500_000, alice);

        uint256 amountIn = _boundAmount(amountInRaw, 100_000);
        uint256 expectedAmountOut = _getAmountOut(amountIn, 500_000, 500_000);
        if (expectedAmountOut == 0) {
            return;
        }

        token0.mint(bob, amountIn);
        VM.prank(bob);
        token0.transfer(address(pair), amountIn);

        VM.prank(bob);
        pair.swap(0, expectedAmountOut, bob, "");

        (uint112 reserve0After, uint112 reserve1After,) = pair.getReserves();
        assertTrue(reserve0After == 500_000 + amountIn, "reserve0 mismatch after swap");
        assertTrue(reserve1After == 500_000 - expectedAmountOut, "reserve1 mismatch after swap");
        assertTrue(token1.balanceOf(bob) == expectedAmountOut, "quoted output mismatch");
    }

    function testFuzzSkimAndSyncHandleExcessBalances(uint96 excess0Raw, uint96 excess1Raw) public {
        _provideLiquidity(pair, token0, token1, alice, 250_000, 250_000, alice);

        uint256 excess0 = _boundAmount(excess0Raw, 100_000);
        uint256 excess1 = _boundAmount(excess1Raw, 100_000);
        token0.mint(address(pair), excess0);
        token1.mint(address(pair), excess1);

        pair.skim(carol);
        assertTrue(token0.balanceOf(carol) == excess0, "skimmed token0 mismatch");
        assertTrue(token1.balanceOf(carol) == excess1, "skimmed token1 mismatch");

        token0.mint(address(pair), excess0);
        token1.mint(address(pair), excess1);
        pair.sync();

        (uint112 reserve0After, uint112 reserve1After,) = pair.getReserves();
        assertTrue(reserve0After == 250_000 + excess0, "synced reserve0 mismatch");
        assertTrue(reserve1After == 250_000 + excess1, "synced reserve1 mismatch");
    }

    function _boundAmount(uint256 raw, uint256 max) internal pure returns (uint256 amount) {
        if (max == 0) {
            return 0;
        }

        amount = (raw % max) + 1;
    }
}
