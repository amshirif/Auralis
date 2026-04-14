// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AMMFactory} from "../src/amm/AMMFactory.sol";
import {AMMPair} from "../src/amm/AMMPair.sol";
import {
    AMMPairCoreFixture,
    FalseReturningAMMToken,
    MalformedAMMToken,
    MockAMMToken,
    ReentrantAMMToken,
    SilentAMMToken
} from "./helpers/AMMPairTestHarness.sol";

contract AMMPairCoreTest is AMMPairCoreFixture {
    function testInitializeOnlyFactoryOnceAndRejectsInvalidTokens() public {
        AMMPair unauthorized = new AMMPair();
        assertTrue(unauthorized.factory() == address(this), "unexpected constructor factory");

        VM.prank(alice);
        VM.expectRevert(AMMPair.AMMPairForbidden.selector);
        unauthorized.initialize(address(token0), address(token1));

        AMMPair zeroToken = new AMMPair();
        VM.expectRevert(AMMPair.AMMPairZeroTokenAddress.selector);
        zeroToken.initialize(address(0), address(token1));

        AMMPair identicalToken = new AMMPair();
        VM.expectRevert(AMMPair.AMMPairIdenticalTokens.selector);
        identicalToken.initialize(address(token0), address(token0));

        AMMPair initialized = new AMMPair();
        initialized.initialize(address(token0), address(token1));
        assertTrue(initialized.token0() == address(token0), "token0 mismatch");
        assertTrue(initialized.token1() == address(token1), "token1 mismatch");

        (uint112 reserve0_, uint112 reserve1_, uint32 timestampLast) = initialized.getReserves();
        assertTrue(reserve0_ == 0, "reserve0 should start at zero");
        assertTrue(reserve1_ == 0, "reserve1 should start at zero");
        assertTrue(timestampLast == 0, "timestamp should start at zero");

        VM.expectRevert(AMMPair.AMMPairAlreadyInitialized.selector);
        initialized.initialize(address(token0), address(token1));
    }

    function testFirstLiquidityMintLocksMinimumLiquidityAndUpdatesReserves() public {
        uint256 liquidity = _provideLiquidity(pair, token0, token1, alice, 10_000, 40_000, alice);

        assertTrue(liquidity == 19_000, "first-liquidity mint mismatch");
        assertTrue(pair.balanceOf(alice) == 19_000, "provider lp balance mismatch");
        assertTrue(pair.balanceOf(BURN_SINK) == pair.MINIMUM_LIQUIDITY(), "minimum liquidity not locked");
        assertTrue(pair.totalSupply() == 20_000, "lp total supply mismatch");

        (uint112 reserve0_, uint112 reserve1_,) = pair.getReserves();
        assertTrue(reserve0_ == 10_000, "reserve0 mismatch");
        assertTrue(reserve1_ == 40_000, "reserve1 mismatch");
        assertTrue(pair.kLast() == 0, "kLast should remain zero when fee switch is off");
    }

    function testLaterLiquidityMintUsesCurrentReserveRatio() public {
        _provideLiquidity(pair, token0, token1, alice, 10_000, 10_000, alice);
        uint256 liquidity = _provideLiquidity(pair, token0, token1, bob, 5_000, 5_000, bob);

        assertTrue(liquidity == 5_000, "second liquidity mint mismatch");
        assertTrue(pair.balanceOf(bob) == 5_000, "bob lp balance mismatch");

        (uint112 reserve0_, uint112 reserve1_,) = pair.getReserves();
        assertTrue(reserve0_ == 15_000, "reserve0 mismatch after second mint");
        assertTrue(reserve1_ == 15_000, "reserve1 mismatch after second mint");
    }

    function testBurnRedeemsUnderlyingProRata() public {
        _provideLiquidity(pair, token0, token1, alice, 10_000, 10_000, alice);

        VM.prank(alice);
        assertTrue(pair.transfer(address(pair), 5_000), "lp transfer to pair should succeed");

        (uint256 amount0, uint256 amount1) = pair.burn(alice);
        assertTrue(amount0 == 5_000, "burn amount0 mismatch");
        assertTrue(amount1 == 5_000, "burn amount1 mismatch");
        assertTrue(token0.balanceOf(alice) == 5_000, "alice token0 post-burn mismatch");
        assertTrue(token1.balanceOf(alice) == 5_000, "alice token1 post-burn mismatch");

        (uint112 reserve0_, uint112 reserve1_,) = pair.getReserves();
        assertTrue(reserve0_ == 5_000, "reserve0 mismatch after burn");
        assertTrue(reserve1_ == 5_000, "reserve1 mismatch after burn");
    }

    function testSwapToken1Out() public {
        _provideLiquidity(pair, token0, token1, alice, 10_000, 10_000, alice);

        token0.mint(bob, 1_000);
        VM.prank(bob);
        assertTrue(token0.transfer(address(pair), 1_000), "token0 input transfer should succeed");

        uint256 amount1Out = _getAmountOut(1_000, 10_000, 10_000);
        VM.prank(bob);
        pair.swap(0, amount1Out, bob, "");

        assertTrue(token1.balanceOf(bob) == amount1Out, "token1 output mismatch");

        (uint112 reserve0_, uint112 reserve1_,) = pair.getReserves();
        assertTrue(reserve0_ == 11_000, "reserve0 mismatch after token1-out swap");
        assertTrue(reserve1_ == 10_000 - amount1Out, "reserve1 mismatch after token1-out swap");
    }

    function testSwapToken0Out() public {
        _provideLiquidity(pair, token0, token1, alice, 10_000, 10_000, alice);

        token1.mint(bob, 1_000);
        VM.prank(bob);
        assertTrue(token1.transfer(address(pair), 1_000), "token1 input transfer should succeed");

        uint256 amount0Out = _getAmountOut(1_000, 10_000, 10_000);
        VM.prank(bob);
        pair.swap(amount0Out, 0, bob, "");

        assertTrue(token0.balanceOf(bob) == amount0Out, "token0 output mismatch");

        (uint112 reserve0_, uint112 reserve1_,) = pair.getReserves();
        assertTrue(reserve0_ == 10_000 - amount0Out, "reserve0 mismatch after token0-out swap");
        assertTrue(reserve1_ == 11_000, "reserve1 mismatch after token0-out swap");
    }

    function testSwapRevertsOnInsufficientLiquidity() public {
        _provideLiquidity(pair, token0, token1, alice, 10_000, 10_000, alice);

        VM.expectRevert(AMMPair.AMMPairInsufficientLiquidity.selector);
        pair.swap(10_000, 0, bob, "");
    }

    function testSwapRevertsOnUnsupportedData() public {
        _provideLiquidity(pair, token0, token1, alice, 10_000, 10_000, alice);

        VM.expectRevert(AMMPair.AMMPairUnsupportedSwapData.selector);
        pair.swap(0, 1, bob, hex"01");
    }

    function testSwapRevertsOnInvalidRecipient() public {
        _provideLiquidity(pair, token0, token1, alice, 10_000, 10_000, alice);

        VM.expectRevert(abi.encodeWithSelector(AMMPair.AMMPairInvalidRecipient.selector, address(token0)));
        pair.swap(0, 1, address(token0), "");
    }

    function testSwapRevertsWhenNoInputIsProvided() public {
        _provideLiquidity(pair, token0, token1, alice, 10_000, 10_000, alice);

        VM.expectRevert(AMMPair.AMMPairInsufficientInputAmount.selector);
        pair.swap(0, 100, bob, "");
    }

    function testSwapRevertsOnConstantProductViolation() public {
        _provideLiquidity(pair, token0, token1, alice, 10_000, 10_000, alice);

        token0.mint(bob, 1_000);
        VM.prank(bob);
        assertTrue(token0.transfer(address(pair), 1_000), "token0 input transfer should succeed");

        uint256 invalidAmount1Out = _getAmountOut(1_000, 10_000, 10_000) + 1;
        VM.prank(bob);
        VM.expectRevert(AMMPair.AMMPairKInvariant.selector);
        pair.swap(0, invalidAmount1Out, bob, "");
    }

    function testSkimTransfersOnlyExcessBalances() public {
        _provideLiquidity(pair, token0, token1, alice, 10_000, 10_000, alice);

        token0.mint(address(pair), 500);
        token1.mint(address(pair), 700);

        pair.skim(carol);

        assertTrue(token0.balanceOf(carol) == 500, "skim token0 mismatch");
        assertTrue(token1.balanceOf(carol) == 700, "skim token1 mismatch");

        (uint112 reserve0_, uint112 reserve1_,) = pair.getReserves();
        assertTrue(reserve0_ == 10_000, "skim should not change reserve0");
        assertTrue(reserve1_ == 10_000, "skim should not change reserve1");
    }

    function testSyncUpdatesReservesToActualBalances() public {
        _provideLiquidity(pair, token0, token1, alice, 10_000, 10_000, alice);

        token0.mint(address(pair), 500);
        token1.mint(address(pair), 700);

        pair.sync();

        (uint112 reserve0_, uint112 reserve1_,) = pair.getReserves();
        assertTrue(reserve0_ == 10_500, "reserve0 mismatch after sync");
        assertTrue(reserve1_ == 10_700, "reserve1 mismatch after sync");
    }

    function testPriceAccumulatorsAdvanceAcrossElapsedTime() public {
        _provideLiquidity(pair, token0, token1, alice, 10_000, 20_000, alice);

        VM.warp(block.timestamp + 10);
        pair.sync();

        uint256 expectedPrice0 = uint256(_uqdiv(20_000, 10_000)) * 10;
        uint256 expectedPrice1 = uint256(_uqdiv(10_000, 20_000)) * 10;

        assertTrue(pair.price0CumulativeLast() == expectedPrice0, "price0 cumulative mismatch");
        assertTrue(pair.price1CumulativeLast() == expectedPrice1, "price1 cumulative mismatch");
    }

    function testFeeOnMintsProtocolLiquidityAndUpdatesKLast() public {
        factory.setFeeTo(carol);
        _provideLiquidity(pair, token0, token1, alice, 1_000_000, 1_000_000, alice);

        assertTrue(pair.kLast() == 1_000_000 * 1_000_000, "initial fee-on kLast mismatch");

        token0.mint(bob, 100_000);
        VM.prank(bob);
        assertTrue(token0.transfer(address(pair), 100_000), "token0 input transfer should succeed");

        uint256 amount1Out = _getAmountOut(100_000, 1_000_000, 1_000_000);
        VM.prank(bob);
        pair.swap(0, amount1Out, bob, "");

        (uint112 reserve0_, uint112 reserve1_,) = pair.getReserves();
        uint256 amount0 = 11_000;
        uint256 amount1 = (amount0 * reserve1_) / reserve0_;

        token0.mint(bob, amount0);
        token1.mint(bob, amount1);
        VM.startPrank(bob);
        assertTrue(token0.transfer(address(pair), amount0), "token0 top-up transfer should succeed");
        assertTrue(token1.transfer(address(pair), amount1), "token1 top-up transfer should succeed");
        VM.stopPrank();

        pair.mint(bob);

        assertTrue(pair.balanceOf(carol) > 0, "protocol fee lp should mint");
        (reserve0_, reserve1_,) = pair.getReserves();
        assertTrue(pair.kLast() == uint256(reserve0_) * uint256(reserve1_), "fee-on kLast mismatch");
    }

    function testFeeOffClearsKLastOnNextLiquidityEvent() public {
        factory.setFeeTo(carol);
        _provideLiquidity(pair, token0, token1, alice, 100_000, 100_000, alice);
        assertTrue(pair.kLast() != 0, "kLast should be set while fee switch is on");

        factory.setFeeTo(address(0));
        _provideLiquidity(pair, token0, token1, bob, 10_000, 10_000, bob);

        assertTrue(pair.kLast() == 0, "kLast should clear when fee switch is off");
    }

    function testSwapRevertsWhenOutputTokenReturnsFalse() public {
        FalseReturningAMMToken falseToken = new FalseReturningAMMToken("False Token", "FTK", 18);
        MockAMMToken normalToken = new MockAMMToken("Normal Token", "NTK", 18);
        AMMFactory localFactory = new AMMFactory();
        AMMPair falsePair = AMMPair(localFactory.createPair(address(falseToken), address(normalToken)));

        _seedLiquidityDirect(falsePair, falseToken, normalToken, 10_000, 10_000, alice);
        normalToken.mint(address(falsePair), 1_000);

        if (falsePair.token0() == address(falseToken)) {
            VM.expectRevert(abi.encodeWithSelector(AMMPair.AMMPairTransferFailed.selector, address(falseToken), bob, 1));
            falsePair.swap(1, 0, bob, "");
        } else {
            VM.expectRevert(abi.encodeWithSelector(AMMPair.AMMPairTransferFailed.selector, address(falseToken), bob, 1));
            falsePair.swap(0, 1, bob, "");
        }
    }

    function testSwapAcceptsSilentTransferToken() public {
        SilentAMMToken silentToken = new SilentAMMToken("Silent Token", "STK", 18);
        MockAMMToken normalToken = new MockAMMToken("Normal Token", "NTK", 18);
        AMMFactory localFactory = new AMMFactory();
        AMMPair silentPair = AMMPair(localFactory.createPair(address(silentToken), address(normalToken)));

        _seedLiquidityDirect(silentPair, silentToken, normalToken, 10_000, 10_000, alice);
        normalToken.mint(address(silentPair), 1_000);

        if (silentPair.token0() == address(silentToken)) {
            silentPair.swap(1, 0, bob, "");
        } else {
            silentPair.swap(0, 1, bob, "");
        }
        assertTrue(silentToken.balanceOf(bob) == 1, "silent transfer output mismatch");
    }

    function testSwapRevertsWhenOutputTokenReturnsMalformedData() public {
        MalformedAMMToken malformedToken = new MalformedAMMToken("Malformed Token", "MTK", 18);
        MockAMMToken normalToken = new MockAMMToken("Normal Token", "NTK", 18);
        AMMFactory localFactory = new AMMFactory();
        AMMPair malformedPair = AMMPair(localFactory.createPair(address(malformedToken), address(normalToken)));

        _seedLiquidityDirect(malformedPair, malformedToken, normalToken, 10_000, 10_000, alice);
        normalToken.mint(address(malformedPair), 1_000);

        if (malformedPair.token0() == address(malformedToken)) {
            VM.expectRevert(
                abi.encodeWithSelector(AMMPair.AMMPairTransferFailed.selector, address(malformedToken), bob, 1)
            );
            malformedPair.swap(1, 0, bob, "");
        } else {
            VM.expectRevert(
                abi.encodeWithSelector(AMMPair.AMMPairTransferFailed.selector, address(malformedToken), bob, 1)
            );
            malformedPair.swap(0, 1, bob, "");
        }
    }

    function testSwapRevertsWhenOutputTransferAttemptsReentrancy() public {
        ReentrantAMMToken reentrantToken = new ReentrantAMMToken("Reentrant Token", "RTK", 18);
        MockAMMToken normalToken = new MockAMMToken("Normal Token", "NTK", 18);
        AMMFactory localFactory = new AMMFactory();
        AMMPair reentrantPair = AMMPair(localFactory.createPair(address(reentrantToken), address(normalToken)));

        _seedLiquidityDirect(reentrantPair, reentrantToken, normalToken, 10_000, 10_000, alice);
        normalToken.mint(address(reentrantPair), 1_000);
        reentrantToken.setReenterSync(address(reentrantPair), true);

        if (reentrantPair.token0() == address(reentrantToken)) {
            VM.expectRevert(
                abi.encodeWithSelector(AMMPair.AMMPairTransferFailed.selector, address(reentrantToken), bob, 1)
            );
            reentrantPair.swap(1, 0, bob, "");
        } else {
            VM.expectRevert(
                abi.encodeWithSelector(AMMPair.AMMPairTransferFailed.selector, address(reentrantToken), bob, 1)
            );
            reentrantPair.swap(0, 1, bob, "");
        }
    }
}
