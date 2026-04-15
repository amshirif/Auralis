// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AMMRouter} from "../src/amm/AMMRouter.sol";
import {AMMRouterFixture} from "./helpers/AMMRouterTestHarness.sol";

contract AMMRouterTimeTest is AMMRouterFixture {
    function testAddLiquidityRevertsAfterDeadline() public {
        uint256 deadline = block.timestamp;
        VM.warp(deadline + 1);

        VM.expectRevert(abi.encodeWithSelector(AMMRouter.AMMRouterExpired.selector, deadline, block.timestamp));
        router.addLiquidity(address(token0), address(token1), 1, 1, 0, 0, alice, deadline);
    }

    function testRemoveLiquidityWithPermitRevertsAfterDeadline() public {
        uint256 deadline = block.timestamp;
        VM.warp(deadline + 1);

        VM.expectRevert(abi.encodeWithSelector(AMMRouter.AMMRouterExpired.selector, deadline, block.timestamp));
        router.removeLiquidityWithPermit(
            address(token0), address(token1), 1, 0, 0, alice, deadline, false, 0, bytes32(0), bytes32(0)
        );
    }

    function testSwapExactTokensForTokensRevertsAfterDeadline() public {
        uint256 deadline = block.timestamp;
        VM.warp(deadline + 1);

        VM.expectRevert(abi.encodeWithSelector(AMMRouter.AMMRouterExpired.selector, deadline, block.timestamp));
        router.swapExactTokensForTokens(1, 0, _path(address(token0), address(token1)), alice, deadline);
    }

    function testSwapExactNativeForTokensRevertsAfterDeadline() public {
        uint256 deadline = block.timestamp;
        VM.warp(deadline + 1);

        VM.expectRevert(abi.encodeWithSelector(AMMRouter.AMMRouterExpired.selector, deadline, block.timestamp));
        router.swapExactNativeForTokens{value: 1}(
            0, _path(address(wrappedNativeToken), address(token0)), alice, deadline
        );
    }
}
