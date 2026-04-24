// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AMMRouter} from "../src/amm/AMMRouter.sol";
import {AMMPair} from "../src/amm/AMMPair.sol";
import {AMMRouterFixture, RejectingNativeReceiver} from "./helpers/AMMRouterTestHarness.sol";
import {FalseReturningAMMToken, MockAMMToken} from "./helpers/AMMPairTestHarness.sol";

contract AMMRouterCoreTest is AMMRouterFixture {
    function testConstructorSetsFactoryAndWrappedNativeAndRejectsZeroAddresses() public view {
        assertTrue(router.factory() == address(factory), "factory mismatch");
        assertTrue(router.wrappedNative() == address(wrappedNativeToken), "wrapped native mismatch");
    }

    function testConstructorRevertsForZeroAddresses() public {
        VM.expectRevert(AMMRouter.AMMRouterZeroAddress.selector);
        new AMMRouter(address(0), address(wrappedNativeToken));

        VM.expectRevert(AMMRouter.AMMRouterZeroAddress.selector);
        new AMMRouter(address(factory), address(0));
    }

    function testQuoteMathAndPathTraversalHelpersMatchExpectedValues() public {
        _provideRouterLiquidity(token0, token1, alice, 10_000, 20_000, alice);
        _provideRouterLiquidity(token1, token2, alice, 20_000, 10_000, alice);

        assertTrue(router.quote(500, 10_000, 20_000) == 1_000, "quote mismatch");

        uint256 expectedHopOneOut = _getAmountOut(1_000, 10_000, 20_000);
        uint256 expectedHopTwoOut = _getAmountOut(expectedHopOneOut, 20_000, 10_000);
        uint256[] memory amountsOut =
            router.getAmountsOut(1_000, _path(address(token0), address(token1), address(token2)));
        assertTrue(amountsOut[0] == 1_000, "amountsOut input mismatch");
        assertTrue(amountsOut[1] == expectedHopOneOut, "amountsOut first hop mismatch");
        assertTrue(amountsOut[2] == expectedHopTwoOut, "amountsOut second hop mismatch");

        uint256 expectedHopTwoIn = router.getAmountIn(700, 20_000, 10_000);
        uint256 expectedHopOneIn = router.getAmountIn(expectedHopTwoIn, 10_000, 20_000);
        uint256[] memory amountsIn = router.getAmountsIn(700, _path(address(token0), address(token1), address(token2)));
        assertTrue(amountsIn[0] == expectedHopOneIn, "amountsIn first hop mismatch");
        assertTrue(amountsIn[1] == expectedHopTwoIn, "amountsIn second hop mismatch");
        assertTrue(amountsIn[2] == 700, "amountsIn output mismatch");
    }

    function testAddLiquidityCreatesPairAndMintsLpToRecipient() public {
        MockAMMToken unsortedA = new MockAMMToken("Token A", "TKA", 18);
        MockAMMToken unsortedB = new MockAMMToken("Token B", "TKB", 18);
        unsortedA.mint(alice, 10_000);
        unsortedB.mint(alice, 20_000);

        VM.startPrank(alice);
        assertTrue(unsortedA.approve(address(router), 10_000), "approve tokenA should succeed");
        assertTrue(unsortedB.approve(address(router), 20_000), "approve tokenB should succeed");
        (uint256 amountA, uint256 amountB, uint256 liquidity) =
            router.addLiquidity(address(unsortedB), address(unsortedA), 20_000, 10_000, 20_000, 10_000, alice, DEADLINE);
        VM.stopPrank();

        address pairAddress = factory.getPair(address(unsortedA), address(unsortedB));
        assertTrue(pairAddress != address(0), "pair should be created");
        assertTrue(amountA == 20_000, "amountA mismatch");
        assertTrue(amountB == 10_000, "amountB mismatch");
        assertTrue(liquidity == 13_142, "liquidity mismatch");

        AMMPair createdPair = AMMPair(pairAddress);
        assertTrue(createdPair.balanceOf(alice) == liquidity, "lp balance mismatch");

        (uint112 reserve0_, uint112 reserve1_,) = createdPair.getReserves();
        (uint112 expectedReserve0, uint112 expectedReserve1) = address(unsortedA) < address(unsortedB)
            ? (uint112(10_000), uint112(20_000))
            : (uint112(20_000), uint112(10_000));
        assertTrue(reserve0_ == expectedReserve0, "reserve0 mismatch");
        assertTrue(reserve1_ == expectedReserve1, "reserve1 mismatch");
    }

    function testAddLiquidityUsesOptimalExistingRatioAndLeavesUnusedBalanceWithCaller() public {
        _provideRouterLiquidity(token0, token1, alice, 10_000, 20_000, alice);

        token0.mint(bob, 5_000);
        token1.mint(bob, 20_000);

        VM.startPrank(bob);
        assertTrue(token0.approve(address(router), 5_000), "approve token0 should succeed");
        assertTrue(token1.approve(address(router), 20_000), "approve token1 should succeed");
        (uint256 amountA, uint256 amountB,) =
            router.addLiquidity(address(token1), address(token0), 20_000, 5_000, 10_000, 5_000, bob, DEADLINE);
        VM.stopPrank();

        assertTrue(amountA == 10_000, "token1 amount mismatch");
        assertTrue(amountB == 5_000, "token0 amount mismatch");
        assertTrue(token1.balanceOf(bob) == 10_000, "unused token1 should remain with caller");

        (uint112 reserve0_, uint112 reserve1_,) = pair.getReserves();
        assertTrue(reserve0_ == 15_000, "reserve0 mismatch after add");
        assertTrue(reserve1_ == 30_000, "reserve1 mismatch after add");
    }

    function testAddLiquidityRevertsWhenSlippageBoundsAreTooTight() public {
        _provideRouterLiquidity(token0, token1, alice, 10_000, 20_000, alice);

        token0.mint(bob, 5_000);
        token1.mint(bob, 20_000);

        VM.startPrank(bob);
        assertTrue(token0.approve(address(router), 5_000), "approve token0 should succeed");
        assertTrue(token1.approve(address(router), 20_000), "approve token1 should succeed");
        VM.expectRevert(abi.encodeWithSelector(AMMRouter.AMMRouterInsufficientAAmount.selector, 10_000, 10_001));
        router.addLiquidity(address(token1), address(token0), 20_000, 5_000, 10_001, 5_000, bob, DEADLINE);
        VM.stopPrank();
    }

    function testAddLiquidityNativeWrapsOnlyUsedAmountAndRefundsExcessNative() public {
        _provideRouterLiquidity(token0, wrappedNativeToken, alice, 10_000, 20_000, alice);

        token0.mint(bob, 5_000);
        VM.deal(bob, 50_000);

        uint256 bobBalanceBefore = bob.balance;
        VM.startPrank(bob);
        assertTrue(token0.approve(address(router), 5_000), "approve token0 should succeed");
        (uint256 amountToken, uint256 amountNative,) =
            router.addLiquidityNative{value: 20_000}(address(token0), 5_000, 5_000, 10_000, bob, DEADLINE);
        VM.stopPrank();

        assertTrue(amountToken == 5_000, "token amount mismatch");
        assertTrue(amountNative == 10_000, "native amount mismatch");
        assertTrue(bob.balance == bobBalanceBefore - 10_000, "native refund mismatch");
        assertTrue(address(router).balance == 0, "router should not retain native balance");
        assertTrue(wrappedNativeToken.balanceOf(address(router)) == 0, "router should not retain wrapped native");

        AMMPair nativePair = AMMPair(factory.getPair(address(token0), address(wrappedNativeToken)));
        (uint112 reserve0_, uint112 reserve1_,) = nativePair.getReserves();
        (uint112 expectedReserve0, uint112 expectedReserve1) = address(token0) < address(wrappedNativeToken)
            ? (uint112(15_000), uint112(30_000))
            : (uint112(30_000), uint112(15_000));
        assertTrue(reserve0_ == expectedReserve0, "native reserve0 mismatch");
        assertTrue(reserve1_ == expectedReserve1, "native reserve1 mismatch");
    }

    function testRemoveLiquidityReturnsAlignedAmountsForCallerTokenOrder() public {
        _provideRouterLiquidity(token0, token1, alice, 10_000, 20_000, alice);

        uint256 burnLiquidity = pair.balanceOf(alice) / 2;
        uint256 totalSupplyBefore = pair.totalSupply();
        (uint112 reserve0Before, uint112 reserve1Before,) = pair.getReserves();
        uint256 expectedToken0 = (burnLiquidity * reserve0Before) / totalSupplyBefore;
        uint256 expectedToken1 = (burnLiquidity * reserve1Before) / totalSupplyBefore;

        VM.prank(alice);
        assertTrue(pair.approve(address(router), burnLiquidity), "approve lp should succeed");

        VM.prank(alice);
        (uint256 amountToken1, uint256 amountToken0) =
            router.removeLiquidity(address(token1), address(token0), burnLiquidity, 0, 0, bob, DEADLINE);

        assertTrue(amountToken1 == expectedToken1, "token1 amount mismatch");
        assertTrue(amountToken0 == expectedToken0, "token0 amount mismatch");
        assertTrue(token1.balanceOf(bob) == expectedToken1, "bob token1 balance mismatch");
        assertTrue(token0.balanceOf(bob) == expectedToken0, "bob token0 balance mismatch");
    }

    function testRemoveLiquidityWithPermitUsesLpPermitApproval() public {
        _provideRouterLiquidity(token0, token1, alice, 10_000, 10_000, alice);

        uint256 liquidity = pair.balanceOf(alice) / 2;
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(ALICE_PK, address(pair), alice, address(router), liquidity, 0, deadline);

        uint256 aliceToken0Before = token0.balanceOf(alice);
        uint256 aliceToken1Before = token1.balanceOf(alice);

        VM.prank(alice);
        (uint256 amount0, uint256 amount1) = _removeLiquidityWithPermit(liquidity, alice, deadline, v, r, s);

        assertTrue(pair.nonces(alice) == 1, "permit nonce mismatch");
        assertTrue(token0.balanceOf(alice) == aliceToken0Before + amount0, "alice token0 delta mismatch");
        assertTrue(token1.balanceOf(alice) == aliceToken1Before + amount1, "alice token1 delta mismatch");
    }

    function testRemoveLiquidityNativeWithPermitUnwrapsAndTransfersNative() public {
        AMMPair nativePair = AMMPair(factory.createPair(address(token0), address(wrappedNativeToken)));
        _provideRouterLiquidity(token0, wrappedNativeToken, alice, 10_000, 10_000, alice);

        uint256 liquidity = nativePair.balanceOf(alice) / 2;
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(ALICE_PK, address(nativePair), alice, address(router), liquidity, 0, deadline);

        uint256 bobNativeBefore = bob.balance;
        uint256 bobTokenBefore = token0.balanceOf(bob);

        VM.prank(alice);
        (uint256 amountToken, uint256 amountNative) =
            _removeLiquidityNativeWithPermit(liquidity, bob, deadline, v, r, s);

        assertTrue(nativePair.nonces(alice) == 1, "native permit nonce mismatch");
        assertTrue(token0.balanceOf(bob) == bobTokenBefore + amountToken, "token payout mismatch");
        assertTrue(bob.balance == bobNativeBefore + amountNative, "native payout mismatch");
        assertTrue(address(router).balance == 0, "router should not retain native balance");
    }

    function testSwapExactTokensForTokensRoutesSingleHop() public {
        _provideRouterLiquidity(token0, token1, alice, 10_000, 10_000, alice);

        token0.mint(bob, 1_000);
        uint256 expectedAmountOut = router.getAmountOut(1_000, 10_000, 10_000);

        VM.startPrank(bob);
        assertTrue(token0.approve(address(router), 1_000), "approve token0 should succeed");
        uint256[] memory amounts = router.swapExactTokensForTokens(
            1_000, expectedAmountOut, _path(address(token0), address(token1)), bob, DEADLINE
        );
        VM.stopPrank();

        assertTrue(amounts[0] == 1_000, "amounts input mismatch");
        assertTrue(amounts[1] == expectedAmountOut, "amounts output mismatch");
        assertTrue(token1.balanceOf(bob) == expectedAmountOut, "bob token1 output mismatch");
    }

    function testSwapTokensForExactTokensRoutesMultiHop() public {
        _provideRouterLiquidity(token0, token1, alice, 10_000, 20_000, alice);
        _provideRouterLiquidity(token1, token2, alice, 20_000, 10_000, alice);

        uint256 amountOut = 700;
        uint256[] memory expectedAmounts =
            router.getAmountsIn(amountOut, _path(address(token0), address(token1), address(token2)));
        token0.mint(bob, expectedAmounts[0]);

        VM.startPrank(bob);
        assertTrue(token0.approve(address(router), expectedAmounts[0]), "approve token0 should succeed");
        uint256[] memory amounts = router.swapTokensForExactTokens(
            amountOut, expectedAmounts[0], _path(address(token0), address(token1), address(token2)), bob, DEADLINE
        );
        VM.stopPrank();

        assertTrue(amounts[0] == expectedAmounts[0], "required input mismatch");
        assertTrue(amounts[2] == amountOut, "exact output mismatch");
        assertTrue(token2.balanceOf(bob) == amountOut, "bob token2 output mismatch");
    }

    function testSwapExactNativeForTokensWrapsInputAndRoutesOutput() public {
        _provideRouterLiquidity(wrappedNativeToken, token0, alice, 10_000, 10_000, alice);

        VM.deal(bob, 5_000);
        uint256 expectedAmountOut = router.getAmountOut(1_000, 10_000, 10_000);

        VM.prank(bob);
        uint256[] memory amounts = router.swapExactNativeForTokens{value: 1_000}(
            expectedAmountOut, _path(address(wrappedNativeToken), address(token0)), bob, DEADLINE
        );

        assertTrue(amounts[0] == 1_000, "native input mismatch");
        assertTrue(amounts[1] == expectedAmountOut, "token output mismatch");
        assertTrue(token0.balanceOf(bob) == expectedAmountOut, "bob token output mismatch");
        assertTrue(address(router).balance == 0, "router should not retain native balance");
    }

    function testSwapNativeForExactTokensRefundsExcessValue() public {
        _provideRouterLiquidity(wrappedNativeToken, token0, alice, 10_000, 10_000, alice);

        uint256[] memory expectedAmounts = router.getAmountsIn(700, _path(address(wrappedNativeToken), address(token0)));
        VM.deal(bob, expectedAmounts[0] + 500);
        uint256 bobNativeBefore = bob.balance;

        VM.prank(bob);
        uint256[] memory amounts = router.swapNativeForExactTokens{value: expectedAmounts[0] + 500}(
            700, _path(address(wrappedNativeToken), address(token0)), bob, DEADLINE
        );

        assertTrue(amounts[0] == expectedAmounts[0], "required native mismatch");
        assertTrue(token0.balanceOf(bob) == 700, "bob token output mismatch");
        assertTrue(bob.balance == bobNativeBefore - expectedAmounts[0], "native refund mismatch");
    }

    function testSwapExactTokensForNativeUnwrapsAndTransfersNative() public {
        _provideRouterLiquidity(token0, wrappedNativeToken, alice, 10_000, 10_000, alice);

        token0.mint(bob, 1_000);
        uint256 expectedNativeOut = router.getAmountOut(1_000, 10_000, 10_000);
        uint256 bobNativeBefore = bob.balance;

        VM.startPrank(bob);
        assertTrue(token0.approve(address(router), 1_000), "approve token0 should succeed");
        uint256[] memory amounts = router.swapExactTokensForNative(
            1_000, expectedNativeOut, _path(address(token0), address(wrappedNativeToken)), bob, DEADLINE
        );
        VM.stopPrank();

        assertTrue(amounts[1] == expectedNativeOut, "native output mismatch");
        assertTrue(bob.balance == bobNativeBefore + expectedNativeOut, "bob native payout mismatch");
        assertTrue(address(router).balance == 0, "router should not retain native balance");
    }

    function testSwapTokensForExactNativeUsesExactInputAndTransfersNative() public {
        _provideRouterLiquidity(token0, wrappedNativeToken, alice, 10_000, 10_000, alice);

        uint256[] memory expectedAmounts = router.getAmountsIn(700, _path(address(token0), address(wrappedNativeToken)));
        token0.mint(bob, expectedAmounts[0]);
        uint256 bobNativeBefore = bob.balance;

        VM.startPrank(bob);
        assertTrue(token0.approve(address(router), expectedAmounts[0]), "approve token0 should succeed");
        uint256[] memory amounts = router.swapTokensForExactNative(
            700, expectedAmounts[0], _path(address(token0), address(wrappedNativeToken)), bob, DEADLINE
        );
        VM.stopPrank();

        assertTrue(amounts[0] == expectedAmounts[0], "exact input mismatch");
        assertTrue(amounts[1] == 700, "native amount mismatch");
        assertTrue(bob.balance == bobNativeBefore + 700, "native payout mismatch");
    }

    function testGetAmountsOutRevertsForMissingPairAndInvalidPath() public {
        address[] memory invalidPath = new address[](1);
        invalidPath[0] = address(token0);
        VM.expectRevert(AMMRouter.AMMRouterInvalidPath.selector);
        router.getAmountsOut(1, invalidPath);

        VM.expectRevert(
            abi.encodeWithSelector(AMMRouter.AMMRouterPairUnavailable.selector, address(token0), address(token2))
        );
        router.getAmountsOut(1, _path(address(token0), address(token2)));
    }

    function testNativeHelpersRevertForInvalidWrappedNativePath() public {
        VM.deal(bob, 1_000);
        VM.prank(bob);
        VM.expectRevert(AMMRouter.AMMRouterInvalidWrappedNativePath.selector);
        router.swapExactNativeForTokens{value: 1_000}(0, _path(address(token0), address(token1)), bob, DEADLINE);

        token0.mint(bob, 1_000);
        VM.startPrank(bob);
        assertTrue(token0.approve(address(router), 1_000), "approve token0 should succeed");
        VM.expectRevert(AMMRouter.AMMRouterInvalidWrappedNativePath.selector);
        router.swapExactTokensForNative(1_000, 0, _path(address(token0), address(token1)), bob, DEADLINE);
        VM.stopPrank();
    }

    function testSwapsRevertForSlippageAndMaxInputBounds() public {
        _provideRouterLiquidity(token0, token1, alice, 10_000, 10_000, alice);

        token0.mint(bob, 1_000);
        uint256 expectedAmountOut = router.getAmountOut(1_000, 10_000, 10_000);
        VM.startPrank(bob);
        assertTrue(token0.approve(address(router), 1_000), "approve token0 should succeed");
        VM.expectRevert(
            abi.encodeWithSelector(
                AMMRouter.AMMRouterInsufficientOutputAmount.selector, expectedAmountOut, expectedAmountOut + 1
            )
        );
        router.swapExactTokensForTokens(
            1_000, expectedAmountOut + 1, _path(address(token0), address(token1)), bob, DEADLINE
        );
        VM.stopPrank();

        uint256[] memory expectedAmounts = router.getAmountsIn(700, _path(address(token0), address(token1)));
        token0.mint(bob, expectedAmounts[0]);
        VM.startPrank(bob);
        assertTrue(token0.approve(address(router), expectedAmounts[0]), "approve token0 should succeed");
        VM.expectRevert(
            abi.encodeWithSelector(
                AMMRouter.AMMRouterExcessiveInputAmount.selector, expectedAmounts[0], expectedAmounts[0] - 1
            )
        );
        router.swapTokensForExactTokens(
            700, expectedAmounts[0] - 1, _path(address(token0), address(token1)), bob, DEADLINE
        );
        VM.stopPrank();
    }

    function testAddLiquidityRevertsWhenTransferFromFails() public {
        FalseReturningAMMToken falseToken = _deployFalseReturningToken();
        address pairAddress = factory.createPair(address(falseToken), address(token1));
        token1.mint(bob, 10_000);
        falseToken.mint(bob, 10_000);

        VM.startPrank(bob);
        assertTrue(token1.approve(address(router), 10_000), "approve token1 should succeed");
        assertTrue(falseToken.approve(address(router), 10_000), "approve false token should succeed");
        VM.expectRevert(
            abi.encodeWithSelector(
                AMMRouter.AMMRouterTransferFromFailed.selector, address(falseToken), bob, pairAddress, 10_000
            )
        );
        router.addLiquidity(address(falseToken), address(token1), 10_000, 10_000, 0, 0, bob, DEADLINE);
        VM.stopPrank();
    }

    function testRouterRejectsDirectNativeTransfersAndNativeRecipientsThatRevert() public {
        VM.deal(address(this), 1);
        (bool success, bytes memory returndata) = address(router).call{value: 1}("");
        assertFalse(success, "direct native transfer should fail");

        bytes4 revertSelector;
        assembly {
            revertSelector := mload(add(returndata, 0x20))
        }
        assertTrue(revertSelector == AMMRouter.AMMRouterInvalidNativeSender.selector, "unexpected direct native revert");

        _provideRouterLiquidity(token0, wrappedNativeToken, alice, 10_000, 10_000, alice);
        RejectingNativeReceiver rejectingReceiver = new RejectingNativeReceiver();

        token0.mint(bob, 1_000);
        VM.startPrank(bob);
        assertTrue(token0.approve(address(router), 1_000), "approve token0 should succeed");
        uint256 expectedNativeOut = router.getAmountOut(1_000, 10_000, 10_000);
        VM.expectRevert(
            abi.encodeWithSelector(
                AMMRouter.AMMRouterNativeTransferFailed.selector, address(rejectingReceiver), expectedNativeOut
            )
        );
        router.swapExactTokensForNative(
            1_000,
            expectedNativeOut,
            _path(address(token0), address(wrappedNativeToken)),
            address(rejectingReceiver),
            DEADLINE
        );
        VM.stopPrank();
    }

    function _removeLiquidityWithPermit(uint256 liquidity, address to, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        return router.removeLiquidityWithPermit(
            address(token0), address(token1), liquidity, 0, 0, to, deadline, false, v, r, s
        );
    }

    function _removeLiquidityNativeWithPermit(
        uint256 liquidity,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal returns (uint256 amountToken, uint256 amountNative) {
        return router.removeLiquidityNativeWithPermit(address(token0), liquidity, 0, 0, to, deadline, false, v, r, s);
    }
}
