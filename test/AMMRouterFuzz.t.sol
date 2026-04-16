// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AMMPair} from "../src/amm/AMMPair.sol";
import {AMMHardeningFixture} from "./helpers/AMMHardeningTestHarness.sol";
import {MockAMMToken} from "./helpers/AMMPairTestHarness.sol";

contract AMMRouterFuzzTest is AMMHardeningFixture {
    function testFuzzQuoteHelpersRemainInternallyConsistent(uint8 pathSeed, uint96 amountInRaw) public view {
        address[] memory path_ = _tokenSwapPath(pathSeed);
        (uint256 reserveIn,) = _getAlignedReserves(path_[0], path_[1]);
        uint256 maxAmountIn = reserveIn / 8;
        uint256 amountIn = _boundAmount(amountInRaw, maxAmountIn);
        if (amountIn == 0) {
            return;
        }

        uint256[] memory amountsOut;
        try router.getAmountsOut(amountIn, path_) returns (uint256[] memory quotedAmounts) {
            amountsOut = quotedAmounts;
        } catch {
            return;
        }

        uint256[] memory amountsIn;
        try router.getAmountsIn(amountsOut[amountsOut.length - 1], path_) returns (uint256[] memory requiredAmounts) {
            amountsIn = requiredAmounts;
        } catch {
            return;
        }

        assertTrue(amountsOut[0] == amountIn, "amountsOut input mismatch");
        assertTrue(amountsIn[amountsIn.length - 1] == amountsOut[amountsOut.length - 1], "terminal amount mismatch");
        assertTrue(amountsIn[0] <= amountIn, "reverse quote should not exceed original input");
    }

    function testFuzzAddAndRemoveLiquidityPreserveTokenOrderAlignment(uint96 desiredRaw) public {
        address provider = bob;
        uint256 desiredAmount = _boundAmount(desiredRaw, 100_000);
        uint256 bobToken0Before = token0.balanceOf(provider);
        uint256 bobToken1Before = token1.balanceOf(provider);

        VM.prank(provider);
        (,, uint256 liquidity) = router.addLiquidity(
            address(token1), address(token0), desiredAmount, desiredAmount, 0, 0, provider, DEADLINE
        );

        uint256 removeLiquidityAmount = liquidity / 2;
        if (removeLiquidityAmount == 0) {
            return;
        }

        VM.prank(provider);
        (uint256 amountToken1, uint256 amountToken0) =
            router.removeLiquidity(address(token1), address(token0), removeLiquidityAmount, 0, 0, provider, DEADLINE);

        _recordLiquidityEvent(address(pair01));
        assertTrue(amountToken1 != 0, "token1 removal amount should be nonzero");
        assertTrue(amountToken0 != 0, "token0 removal amount should be nonzero");
        assertTrue(token0.balanceOf(provider) >= bobToken0Before - desiredAmount, "token0 balance regression");
        assertTrue(token1.balanceOf(provider) >= bobToken1Before - desiredAmount, "token1 balance regression");
        _assertRouterZeroBalances();
    }

    function testFuzzExactInSwapRoutesAcrossTrackedPaths(uint8 actorSeed, uint8 pathSeed, uint96 amountInRaw) public {
        address trader = _actor(actorSeed);
        address[] memory path_ = _tokenSwapPath(pathSeed);
        uint256 maxAmountIn = MockAMMToken(path_[0]).balanceOf(trader) / 8;
        uint256 amountIn = _boundAmount(amountInRaw, maxAmountIn);
        if (amountIn == 0) {
            return;
        }

        uint256[] memory quotedAmounts;
        try router.getAmountsOut(amountIn, path_) returns (uint256[] memory pathAmounts) {
            quotedAmounts = pathAmounts;
        } catch {
            return;
        }

        uint256 expectedAmountOut = quotedAmounts[path_.length - 1];
        if (expectedAmountOut == 0) {
            return;
        }
        uint256 recipientBalanceBefore = MockAMMToken(path_[path_.length - 1]).balanceOf(trader);

        VM.prank(trader);
        uint256[] memory amounts = router.swapExactTokensForTokens(amountIn, expectedAmountOut, path_, trader, DEADLINE);

        assertTrue(amounts[0] == amountIn, "swap input mismatch");
        assertTrue(amounts[amounts.length - 1] == expectedAmountOut, "swap output mismatch");
        assertTrue(
            MockAMMToken(path_[path_.length - 1]).balanceOf(trader) == recipientBalanceBefore + expectedAmountOut,
            "recipient output delta mismatch"
        );
        _assertRouterZeroBalances();
    }

    function testFuzzExactOutSwapHonorsMaximumInput(uint8 actorSeed, uint8 pathSeed, uint96 amountOutRaw) public {
        address trader = _actor(actorSeed);
        address[] memory path_ = _tokenSwapPath(pathSeed);
        (, uint256 reserveOut) = _getAlignedReserves(path_[path_.length - 2], path_[path_.length - 1]);
        uint256 amountOut = _boundAmount(amountOutRaw, reserveOut / 8);
        if (amountOut == 0) {
            return;
        }

        uint256[] memory expectedAmounts = router.getAmountsIn(amountOut, path_);
        if (expectedAmounts[0] > MockAMMToken(path_[0]).balanceOf(trader)) {
            return;
        }

        uint256 recipientBalanceBefore = MockAMMToken(path_[path_.length - 1]).balanceOf(trader);
        VM.prank(trader);
        uint256[] memory amounts =
            router.swapTokensForExactTokens(amountOut, expectedAmounts[0], path_, trader, DEADLINE);

        assertTrue(amounts[0] == expectedAmounts[0], "required input mismatch");
        assertTrue(amounts[amounts.length - 1] == amountOut, "exact output mismatch");
        assertTrue(
            MockAMMToken(path_[path_.length - 1]).balanceOf(trader) == recipientBalanceBefore + amountOut,
            "recipient exact output delta mismatch"
        );
        _assertRouterZeroBalances();
    }

    function testFuzzAddLiquidityNativeRefundsUnusedValue(uint96 tokenAmountRaw) public {
        address provider = carol;
        uint256 tokenAmount = _boundAmount(tokenAmountRaw, 100_000);
        uint256 nativeAmount = tokenAmount * 2;
        uint256 nativeBalanceBefore = provider.balance;

        VM.prank(provider);
        (uint256 amountToken, uint256 amountNative,) =
            router.addLiquidityNative{value: nativeAmount}(address(token0), tokenAmount, 0, 0, provider, DEADLINE);

        _recordLiquidityEvent(address(pair0W));
        assertTrue(amountToken == tokenAmount, "native add token amount mismatch");
        assertTrue(amountNative == tokenAmount, "native add used amount mismatch");
        assertTrue(provider.balance == nativeBalanceBefore - amountNative, "unused native refund mismatch");
        _assertRouterZeroBalances();
    }

    function testFuzzSwapNativeForExactTokensRefundsExcessValue(uint8 actorSeed, uint8 pathSeed, uint96 amountOutRaw)
        public
    {
        address trader = _actor(actorSeed);
        address[] memory nativeInPath = _nativeInPath(pathSeed);
        (, uint256 reserveOut) =
            _getAlignedReserves(nativeInPath[nativeInPath.length - 2], nativeInPath[nativeInPath.length - 1]);
        uint256 amountOut = _boundAmount(amountOutRaw, reserveOut / 8);
        if (amountOut == 0) {
            return;
        }

        uint256[] memory amountsIn = router.getAmountsIn(amountOut, nativeInPath);
        uint256 refundPadding = amountOut + 1;
        uint256 nativeBalanceBefore = trader.balance;

        VM.prank(trader);
        uint256[] memory nativeInAmounts = router.swapNativeForExactTokens{value: amountsIn[0] + refundPadding}(
            amountOut, nativeInPath, trader, DEADLINE
        );

        assertTrue(nativeInAmounts[0] == amountsIn[0], "native exact input mismatch");
        assertTrue(trader.balance == nativeBalanceBefore - amountsIn[0], "native refund accounting mismatch");
        _assertRouterZeroBalances();
    }

    function testFuzzSwapTokensForExactNativeUnwrapsOutput(uint8 actorSeed, uint8 pathSeed, uint96 amountOutRaw)
        public
    {
        address trader = _actor(actorSeed);
        address[] memory nativeOutPath = _nativeOutPath(pathSeed);
        (, uint256 reserveOut) =
            _getAlignedReserves(nativeOutPath[nativeOutPath.length - 2], nativeOutPath[nativeOutPath.length - 1]);
        uint256 nativeOut = _boundAmount(amountOutRaw, reserveOut / 8);
        uint256[] memory expectedNativeIn = router.getAmountsIn(nativeOut, nativeOutPath);
        if (expectedNativeIn[0] > MockAMMToken(nativeOutPath[0]).balanceOf(trader)) {
            _assertRouterZeroBalances();
            return;
        }

        uint256 nativeBalanceBeforeOut = trader.balance;
        VM.prank(trader);
        uint256[] memory nativeOutAmounts =
            router.swapTokensForExactNative(nativeOut, expectedNativeIn[0], nativeOutPath, trader, DEADLINE);

        assertTrue(nativeOutAmounts[nativeOutAmounts.length - 1] == nativeOut, "native exact output mismatch");
        assertTrue(trader.balance == nativeBalanceBeforeOut + nativeOut, "native unwrap delta mismatch");
        _assertRouterZeroBalances();
    }
}
