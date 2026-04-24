// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AMMFactory} from "../src/amm/AMMFactory.sol";
import {AMMPair} from "../src/amm/AMMPair.sol";
import {AMMRouter} from "../src/amm/AMMRouter.sol";
import {AMMHardeningFixture} from "./helpers/AMMHardeningTestHarness.sol";
import {
    FalseReturningAMMToken,
    MalformedAMMToken,
    MockAMMToken,
    ReentrantAMMToken,
    SilentAMMToken
} from "./helpers/AMMPairTestHarness.sol";

contract AMMHardeningTest is AMMHardeningFixture {
    function testFeeOnMintsProtocolLpOnlyWhenLiquidityMoves() public {
        AMMFactory localFactory = new AMMFactory();
        localFactory.setFeeTo(carol);

        MockAMMToken localToken0 = new MockAMMToken("Local Token 0", "LT0", 18);
        MockAMMToken localToken1 = new MockAMMToken("Local Token 1", "LT1", 18);
        AMMPair localPair = AMMPair(localFactory.createPair(address(localToken0), address(localToken1)));

        _seedLiquidityDirect(localPair, localToken0, localToken1, 1_000_000, 1_000_000, alice);
        assertTrue(localPair.kLast() == 1_000_000 * 1_000_000, "initial fee-on kLast mismatch");

        localToken0.mint(address(localPair), 100_000);
        uint256 amount1Out = _getAmountOut(100_000, 1_000_000, 1_000_000);
        if (localPair.token0() == address(localToken0)) {
            localPair.swap(0, amount1Out, bob, "");
        } else {
            localPair.swap(amount1Out, 0, bob, "");
        }

        (uint112 reserve0AfterSwap, uint112 reserve1AfterSwap,) = localPair.getReserves();
        uint256 protocolLpBefore = localPair.balanceOf(carol);
        (uint256 reserveLocal0, uint256 reserveLocal1) = localPair.token0() == address(localToken0)
            ? (reserve0AfterSwap, reserve1AfterSwap)
            : (reserve1AfterSwap, reserve0AfterSwap);
        uint256 amount0Desired = 11_000;
        uint256 amount1Desired = (amount0Desired * reserveLocal1) / reserveLocal0;

        localToken0.mint(address(localPair), amount0Desired);
        localToken1.mint(address(localPair), amount1Desired);
        localPair.mint(bob);

        assertTrue(localPair.balanceOf(carol) > protocolLpBefore, "protocol fee lp should mint on later liquidity");
        (uint112 reserve0AfterMint, uint112 reserve1AfterMint,) = localPair.getReserves();
        assertTrue(
            localPair.kLast() == uint256(reserve0AfterMint) * uint256(reserve1AfterMint),
            "fee-on kLast should refresh on liquidity event"
        );
    }

    function testFeeOffClearsKLastOnlyOnNextLiquidityEvent() public {
        factory.setFeeTo(carol);

        VM.prank(bob);
        router.addLiquidity(address(token0), address(token1), 20_000, 20_000, 0, 0, bob, DEADLINE);
        _recordLiquidityEvent(address(pair01));

        uint256 kLastBeforeDisable = pair01.kLast();
        assertTrue(kLastBeforeDisable != 0, "kLast should be set while fee switch is on");

        factory.setFeeTo(address(0));

        address[] memory path_ = _path(address(token0), address(token1));
        uint256 expectedAmountOut = router.getAmountsOut(10_000, path_)[1];
        VM.prank(carol);
        router.swapExactTokensForTokens(10_000, expectedAmountOut, path_, carol, DEADLINE);

        assertTrue(pair01.kLast() == kLastBeforeDisable, "swap should not clear kLast after fee disable");

        (uint256 reserve0Before, uint256 reserve1Before) = _getAlignedReserves(address(token0), address(token1));
        uint256 amount1Desired = router.quote(15_000, reserve0Before, reserve1Before);
        VM.prank(bob);
        router.addLiquidity(address(token0), address(token1), 15_000, amount1Desired, 0, 0, bob, DEADLINE);

        _recordLiquidityEvent(address(pair01));
        assertTrue(pair01.kLast() == 0, "liquidity event should clear kLast after fee disable");
        _assertTrackedAmmState();
    }

    function testDonationSkimAndSyncPreserveReserveSemantics() public {
        (uint112 reserve0Before, uint112 reserve1Before,) = pair01.getReserves();

        token0.mint(address(pair01), 5_000);
        token1.mint(address(pair01), 7_000);
        pair01.skim(dave);

        (uint112 reserve0AfterSkim, uint112 reserve1AfterSkim,) = pair01.getReserves();
        assertTrue(reserve0AfterSkim == reserve0Before, "skim should leave reserve0 unchanged");
        assertTrue(reserve1AfterSkim == reserve1Before, "skim should leave reserve1 unchanged");

        token0.mint(address(pair01), 3_000);
        token1.mint(address(pair01), 4_000);
        pair01.sync();

        (uint112 reserve0AfterSync, uint112 reserve1AfterSync,) = pair01.getReserves();
        assertTrue(reserve0AfterSync == reserve0Before + 3_000, "sync should advance reserve0 to balance");
        assertTrue(reserve1AfterSync == reserve1Before + 4_000, "sync should advance reserve1 to balance");
        _assertTrackedAmmState();
    }

    function testMultiActorTokenAndNativeSequenceKeepsTrackedStateCoherent() public {
        VM.prank(bob);
        router.addLiquidityNative{value: 20_000}(address(token0), 20_000, 0, 0, bob, DEADLINE);
        _recordLiquidityEvent(address(pair0W));

        VM.prank(carol);
        router.swapExactTokensForTokens(
            12_000, 0, _path(address(token2), address(token1), address(token0)), carol, DEADLINE
        );

        VM.prank(dave);
        router.swapExactNativeForTokens{value: 15_000}(
            0, _path(address(wrappedNativeToken), address(token1), address(token2)), dave, DEADLINE
        );

        uint256 liquidityToBurn = pair1W.balanceOf(alice) / 4;
        VM.prank(alice);
        router.removeLiquidityNative(address(token1), liquidityToBurn, 0, 0, alice, DEADLINE);
        _recordLiquidityEvent(address(pair1W));

        _assertTrackedAmmState();
    }

    function testRouterTransferFailureLeavesCreatedPairEmpty() public {
        FalseReturningAMMToken falseToken = _deployFalseReturningToken();
        MockAMMToken normalToken = new MockAMMToken("Normal Token", "NTK", 18);
        falseToken.mint(bob, 10_000);
        normalToken.mint(bob, 10_000);

        VM.startPrank(bob);
        falseToken.approve(address(router), type(uint256).max);
        normalToken.approve(address(router), type(uint256).max);
        try router.addLiquidity(address(falseToken), address(normalToken), 10_000, 10_000, 0, 0, bob, DEADLINE) {
            revert("expected addLiquidity revert");
        } catch (bytes memory revertData) {
            // casting to bytes4 is safe because revert selectors are defined by the first four bytes.
            // forge-lint: disable-next-line(unsafe-typecast)
            bytes4 selector = bytes4(revertData);
            assertTrue(selector == AMMRouter.AMMRouterTransferFromFailed.selector, "unexpected router revert");
        }
        VM.stopPrank();

        address pairAddress = factory.getPair(address(falseToken), address(normalToken));
        assertTrue(pairAddress == address(0), "failed transfer should revert pair creation too");
    }

    function testMalformedAndReentrantOutputFailuresDoNotCorruptPairs() public {
        MalformedAMMToken malformedToken = new MalformedAMMToken("Malformed Token", "MTK", 18);
        MockAMMToken normalToken = new MockAMMToken("Normal Token", "NTK", 18);
        AMMPair malformedPair = _deployPair(address(malformedToken), address(normalToken));
        _seedLiquidityDirect(malformedPair, malformedToken, normalToken, 20_000, 20_000, alice);

        normalToken.mint(address(malformedPair), 1_000);
        (uint112 malformedReserve0, uint112 malformedReserve1,) = malformedPair.getReserves();

        if (malformedPair.token0() == address(malformedToken)) {
            VM.expectRevert(
                abi.encodeWithSelector(AMMPair.AMMPairTransferFailed.selector, address(malformedToken), bob, 949)
            );
            malformedPair.swap(949, 0, bob, "");
        } else {
            VM.expectRevert(
                abi.encodeWithSelector(AMMPair.AMMPairTransferFailed.selector, address(malformedToken), bob, 949)
            );
            malformedPair.swap(0, 949, bob, "");
        }

        (uint112 malformedReserve0After, uint112 malformedReserve1After,) = malformedPair.getReserves();
        assertTrue(malformedReserve0After == malformedReserve0, "malformed revert should preserve reserve0");
        assertTrue(malformedReserve1After == malformedReserve1, "malformed revert should preserve reserve1");

        ReentrantAMMToken reentrantToken = new ReentrantAMMToken("Reentrant Token", "RTK", 18);
        MockAMMToken secondNormalToken = new MockAMMToken("Second Normal Token", "SNT", 18);
        AMMPair reentrantPair = _deployPair(address(reentrantToken), address(secondNormalToken));
        _seedLiquidityDirect(reentrantPair, reentrantToken, secondNormalToken, 20_000, 20_000, alice);
        reentrantToken.setReenterSync(address(reentrantPair), true);

        secondNormalToken.mint(address(reentrantPair), 1_000);
        (uint112 reentrantReserve0, uint112 reentrantReserve1,) = reentrantPair.getReserves();

        if (reentrantPair.token0() == address(reentrantToken)) {
            VM.expectRevert(
                abi.encodeWithSelector(AMMPair.AMMPairTransferFailed.selector, address(reentrantToken), bob, 949)
            );
            reentrantPair.swap(949, 0, bob, "");
        } else {
            VM.expectRevert(
                abi.encodeWithSelector(AMMPair.AMMPairTransferFailed.selector, address(reentrantToken), bob, 949)
            );
            reentrantPair.swap(0, 949, bob, "");
        }

        (uint112 reentrantReserve0After, uint112 reentrantReserve1After,) = reentrantPair.getReserves();
        assertTrue(reentrantReserve0After == reentrantReserve0, "reentrant revert should preserve reserve0");
        assertTrue(reentrantReserve1After == reentrantReserve1, "reentrant revert should preserve reserve1");

        reentrantToken.setReenterSync(address(reentrantPair), false);
        reentrantPair.sync();
    }

    function testSilentOutputTokenCanSustainRepeatedSwaps() public {
        SilentAMMToken silentToken = new SilentAMMToken("Silent Token", "STK", 18);
        MockAMMToken normalToken = new MockAMMToken("Normal Token", "NTK", 18);
        AMMPair silentPair = _deployPair(address(silentToken), address(normalToken));
        _seedLiquidityDirect(silentPair, silentToken, normalToken, 30_000, 30_000, alice);

        normalToken.mint(address(silentPair), 1_000);
        if (silentPair.token0() == address(silentToken)) {
            silentPair.swap(964, 0, bob, "");
        } else {
            silentPair.swap(0, 964, bob, "");
        }

        normalToken.mint(address(silentPair), 500);
        if (silentPair.token0() == address(silentToken)) {
            silentPair.swap(447, 0, carol, "");
        } else {
            silentPair.swap(0, 447, carol, "");
        }

        (uint112 reserve0_, uint112 reserve1_,) = silentPair.getReserves();
        assertTrue(
            reserve0_ <= MockAMMToken(silentPair.token0()).balanceOf(address(silentPair)),
            "silent reserve0 should not exceed balance"
        );
        assertTrue(
            reserve1_ <= MockAMMToken(silentPair.token1()).balanceOf(address(silentPair)),
            "silent reserve1 should not exceed balance"
        );
    }
}
