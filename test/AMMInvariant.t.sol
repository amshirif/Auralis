// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AMMPair} from "../src/amm/AMMPair.sol";
import {MockAMMToken} from "./helpers/AMMPairTestHarness.sol";
import {AMMHardeningFixture} from "./helpers/AMMHardeningTestHarness.sol";

contract AMMInvariantTest is AMMHardeningFixture {
    function targetContracts() external view returns (address[] memory contracts) {
        contracts = new address[](1);
        contracts[0] = address(this);
    }

    function actionAddLiquidity(uint8 actorSeed, uint8 pairSeed, uint96 amountRaw) external {
        (AMMPair trackedPair, MockAMMToken tokenA_, MockAMMToken tokenB_) = _tokenPairFixture(pairSeed);
        address actor = _actor(actorSeed);
        (uint256 reserveA, uint256 reserveB) = _getAlignedReserves(address(tokenA_), address(tokenB_));
        uint256 maxAmountA = tokenA_.balanceOf(actor) / 16;
        uint256 amountA = _boundAmount(amountRaw, maxAmountA);
        if (amountA == 0) {
            return;
        }

        uint256 amountB = reserveA == 0 || reserveB == 0 ? amountA : router.quote(amountA, reserveA, reserveB);
        if (amountB == 0 || amountB > tokenB_.balanceOf(actor)) {
            return;
        }

        VM.prank(actor);
        router.addLiquidity(address(tokenA_), address(tokenB_), amountA, amountB, 0, 0, actor, DEADLINE);
        _recordLiquidityEvent(address(trackedPair));
    }

    function actionAddLiquidityNative(uint8 actorSeed, uint8 pairSeed, uint96 amountRaw) external {
        (AMMPair trackedPair, MockAMMToken token_) = _nativePairFixture(pairSeed);
        address actor = _actor(actorSeed);
        (uint256 reserveToken, uint256 reserveNative) =
            _getAlignedReserves(address(token_), address(wrappedNativeToken));
        uint256 maxAmountToken = token_.balanceOf(actor) / 16;
        uint256 amountToken = _boundAmount(amountRaw, maxAmountToken);
        if (amountToken == 0) {
            return;
        }

        uint256 amountNative = reserveToken == 0 || reserveNative == 0
            ? amountToken
            : router.quote(amountToken, reserveToken, reserveNative);
        if (amountNative == 0 || amountNative > actor.balance) {
            return;
        }

        VM.prank(actor);
        router.addLiquidityNative{value: amountNative}(address(token_), amountToken, 0, 0, actor, DEADLINE);
        _recordLiquidityEvent(address(trackedPair));
    }

    function actionRemoveLiquidity(uint8 actorSeed, uint8 pairSeed, uint96 liquidityRaw) external {
        (AMMPair trackedPair, MockAMMToken tokenA_, MockAMMToken tokenB_) = _tokenPairFixture(pairSeed);
        address actor = _actor(actorSeed);
        uint256 liquidity = _boundAmount(liquidityRaw, trackedPair.balanceOf(actor));
        if (liquidity == 0) {
            return;
        }

        VM.prank(actor);
        router.removeLiquidity(address(tokenA_), address(tokenB_), liquidity, 0, 0, actor, DEADLINE);
        _recordLiquidityEvent(address(trackedPair));
    }

    function actionRemoveLiquidityNative(uint8 actorSeed, uint8 pairSeed, uint96 liquidityRaw) external {
        (AMMPair trackedPair, MockAMMToken token_) = _nativePairFixture(pairSeed);
        address actor = _actor(actorSeed);
        uint256 liquidity = _boundAmount(liquidityRaw, trackedPair.balanceOf(actor));
        if (liquidity == 0) {
            return;
        }

        VM.prank(actor);
        router.removeLiquidityNative(address(token_), liquidity, 0, 0, actor, DEADLINE);
        _recordLiquidityEvent(address(trackedPair));
    }

    function actionSwapExactTokens(uint8 actorSeed, uint8 pathSeed, uint96 amountRaw) external {
        address actor = _actor(actorSeed);
        address[] memory path_ = _tokenSwapPath(pathSeed);
        uint256 amountIn = _boundAmount(amountRaw, MockAMMToken(path_[0]).balanceOf(actor) / 16);
        if (amountIn == 0) {
            return;
        }

        uint256[] memory amountsOut = router.getAmountsOut(amountIn, path_);
        if (amountsOut[amountsOut.length - 1] == 0) {
            return;
        }

        VM.prank(actor);
        router.swapExactTokensForTokens(amountIn, 0, path_, actor, DEADLINE);
    }

    function actionSwapTokensForExactTokens(uint8 actorSeed, uint8 pathSeed, uint96 amountRaw) external {
        address actor = _actor(actorSeed);
        address[] memory path_ = _tokenSwapPath(pathSeed);
        (, uint256 reserveOut) = _getAlignedReserves(path_[path_.length - 2], path_[path_.length - 1]);
        uint256 amountOut = _boundAmount(amountRaw, reserveOut / 16);
        if (amountOut == 0) {
            return;
        }

        uint256[] memory amountsIn = router.getAmountsIn(amountOut, path_);
        if (amountsIn[0] > MockAMMToken(path_[0]).balanceOf(actor)) {
            return;
        }

        VM.prank(actor);
        router.swapTokensForExactTokens(amountOut, amountsIn[0], path_, actor, DEADLINE);
    }

    function actionSwapExactNative(uint8 actorSeed, uint8 pathSeed, uint96 amountRaw) external {
        address actor = _actor(actorSeed);
        address[] memory path_ = _nativeInPath(pathSeed);
        uint256 amountIn = _boundAmount(amountRaw, actor.balance / 16);
        if (amountIn == 0) {
            return;
        }

        uint256[] memory amountsOut = router.getAmountsOut(amountIn, path_);
        if (amountsOut[amountsOut.length - 1] == 0) {
            return;
        }

        VM.prank(actor);
        router.swapExactNativeForTokens{value: amountIn}(0, path_, actor, DEADLINE);
    }

    function actionSwapTokensForExactNative(uint8 actorSeed, uint8 pathSeed, uint96 amountRaw) external {
        address actor = _actor(actorSeed);
        address[] memory path_ = _nativeOutPath(pathSeed);
        (, uint256 reserveOut) = _getAlignedReserves(path_[path_.length - 2], path_[path_.length - 1]);
        uint256 amountOut = _boundAmount(amountRaw, reserveOut / 16);
        if (amountOut == 0) {
            return;
        }

        uint256[] memory amountsIn = router.getAmountsIn(amountOut, path_);
        if (amountsIn[0] > MockAMMToken(path_[0]).balanceOf(actor)) {
            return;
        }

        VM.prank(actor);
        router.swapTokensForExactNative(amountOut, amountsIn[0], path_, actor, DEADLINE);
    }

    function actionDonateToPair(uint8 actorSeed, uint8 pairSeed, uint8 tokenSeed, uint96 amountRaw) external {
        address actor = _actor(actorSeed);
        AMMPair trackedPair = _trackedPair(pairSeed);
        MockAMMToken pairToken =
            tokenSeed % 2 == 0 ? MockAMMToken(trackedPair.token0()) : MockAMMToken(trackedPair.token1());
        uint256 amount = _boundAmount(amountRaw, _donationCapacity(actor, pairToken) / 16);
        if (amount == 0) {
            return;
        }

        if (address(pairToken) == address(wrappedNativeToken) && pairToken.balanceOf(actor) < amount) {
            if (actor.balance < amount) {
                return;
            }
            _seedWrappedToken(actor, amount);
        }

        VM.prank(actor);
        pairToken.transfer(address(trackedPair), amount);
    }

    function actionSkim(uint8 pairSeed, uint8 recipientSeed) external {
        AMMPair trackedPair = _trackedPair(pairSeed);
        trackedPair.skim(_actor(recipientSeed));
    }

    function actionSync(uint8 pairSeed) external {
        _trackedPair(pairSeed).sync();
    }

    function actionToggleFeeTo() external {
        if (factory.feeTo() == address(0)) {
            factory.setFeeTo(carol);
            return;
        }

        factory.setFeeTo(address(0));
    }

    function invariantTrackedAmmStateHolds() public view {
        _assertTrackedAmmState();
    }

    function invariantRouterNeverRetainsFunds() public view {
        _assertRouterZeroBalances();
    }

    function _tokenPairFixture(uint256 seed)
        internal
        view
        returns (AMMPair trackedPair, MockAMMToken tokenA_, MockAMMToken tokenB_)
    {
        uint256 selector = seed % 3;
        if (selector == 0) {
            return (pair01, token0, token1);
        }
        if (selector == 1) {
            return (pair12, token1, token2);
        }
        return (pair02, token0, token2);
    }

    function _nativePairFixture(uint256 seed) internal view returns (AMMPair trackedPair, MockAMMToken token_) {
        if (seed % 2 == 0) {
            return (pair0W, token0);
        }
        return (pair1W, token1);
    }

    function _donationCapacity(address actor, MockAMMToken token_) internal view returns (uint256 amount) {
        if (address(token_) == address(wrappedNativeToken)) {
            amount = token_.balanceOf(actor) + actor.balance;
        } else {
            amount = token_.balanceOf(actor);
        }
    }
}
