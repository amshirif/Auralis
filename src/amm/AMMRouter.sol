// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAMMFactory} from "../interfaces/IAMMFactory.sol";
import {IAMMPair} from "../interfaces/IAMMPair.sol";
import {IAMMRouter} from "../interfaces/IAMMRouter.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IWrappedNative} from "../interfaces/IWrappedNative.sol";

/// @title AMMRouter
/// @notice User-facing router and quoting surface for the standalone AMM subsystem.
contract AMMRouter is IAMMRouter {
    uint256 internal constant FEE_DENOMINATOR = 1000;
    uint256 internal constant FEE_NUMERATOR = 997;

    /// @notice Reverts when a required address is zero.
    error AMMRouterZeroAddress();
    /// @notice Reverts when a deadline has expired.
    /// @param deadline Supplied deadline.
    /// @param currentTimestamp Current block timestamp.
    error AMMRouterExpired(uint256 deadline, uint256 currentTimestamp);
    /// @notice Reverts when a swap path has fewer than two tokens.
    error AMMRouterInvalidPath();
    /// @notice Reverts when a native route does not begin or end with the wrapped native token as required.
    error AMMRouterInvalidWrappedNativePath();
    /// @notice Reverts when a native liquidity route uses the wrapped native token as the explicit token leg.
    /// @param token Invalid explicit token.
    error AMMRouterInvalidWrappedNativeToken(address token);
    /// @notice Reverts when both token inputs are identical.
    error AMMRouterIdenticalTokens();
    /// @notice Reverts when a token input is the zero address.
    error AMMRouterZeroTokenAddress();
    /// @notice Reverts when native value is sent by an account other than the wrapped native token.
    /// @param sender Native sender.
    error AMMRouterInvalidNativeSender(address sender);
    /// @notice Reverts when a required pair is unavailable.
    /// @param tokenA First token in the pair.
    /// @param tokenB Second token in the pair.
    error AMMRouterPairUnavailable(address tokenA, address tokenB);
    /// @notice Reverts when a quoted amount is zero.
    error AMMRouterInsufficientAmount();
    /// @notice Reverts when pair reserves cannot satisfy the quote.
    error AMMRouterInsufficientLiquidity();
    /// @notice Reverts when the tokenA leg of an add-liquidity quote is below the caller minimum.
    /// @param amountA Quoted tokenA amount.
    /// @param minimumAmountA Minimum tokenA amount required.
    error AMMRouterInsufficientAAmount(uint256 amountA, uint256 minimumAmountA);
    /// @notice Reverts when the tokenB leg of an add-liquidity quote is below the caller minimum.
    /// @param amountB Quoted tokenB amount.
    /// @param minimumAmountB Minimum tokenB amount required.
    error AMMRouterInsufficientBAmount(uint256 amountB, uint256 minimumAmountB);
    /// @notice Reverts when final swap output is below the caller minimum.
    /// @param amountOut Quoted output amount.
    /// @param minimumAmountOut Minimum output required.
    error AMMRouterInsufficientOutputAmount(uint256 amountOut, uint256 minimumAmountOut);
    /// @notice Reverts when required input exceeds the caller maximum.
    /// @param amountIn Required input amount.
    /// @param maximumAmountIn Maximum input allowed.
    error AMMRouterExcessiveInputAmount(uint256 amountIn, uint256 maximumAmountIn);
    /// @notice Reverts when an ERC-20 transfer fails.
    /// @param token Token being transferred.
    /// @param to Transfer recipient.
    /// @param value Transfer amount.
    error AMMRouterTransferFailed(address token, address to, uint256 value);
    /// @notice Reverts when an ERC-20 transferFrom fails.
    /// @param token Token being transferred.
    /// @param from Transfer source.
    /// @param to Transfer recipient.
    /// @param value Transfer amount.
    error AMMRouterTransferFromFailed(address token, address from, address to, uint256 value);
    /// @notice Reverts when wrapping native value fails.
    /// @param value Native value that failed to wrap.
    error AMMRouterWrapFailed(uint256 value);
    /// @notice Reverts when unwrapping wrapped native value fails.
    /// @param value Wrapped native value that failed to unwrap.
    error AMMRouterUnwrapFailed(uint256 value);
    /// @notice Reverts when sending native value fails.
    /// @param to Native recipient.
    /// @param value Native value.
    error AMMRouterNativeTransferFailed(address to, uint256 value);

    // forge-lint: disable-next-line(screaming-snake-case-immutable) -- public immutable preserves the IAMMRouter getter name.
    address public immutable override factory;
    // forge-lint: disable-next-line(screaming-snake-case-immutable) -- public immutable preserves the IAMMRouter getter name.
    address public immutable override wrappedNative;

    /// @notice Reverts after the caller-supplied deadline has expired.
    /// @param deadline Latest acceptable block timestamp for the operation.
    modifier ensure(uint256 deadline) {
        _ensure(deadline);
        _;
    }

    function _ensure(uint256 deadline) internal view {
        if (block.timestamp > deadline) {
            revert AMMRouterExpired(deadline, block.timestamp);
        }
    }

    /// @notice Initializes router dependencies.
    /// @param factory_ AMM factory address.
    /// @param wrappedNative_ Wrapped native token address.
    constructor(address factory_, address wrappedNative_) {
        if (factory_ == address(0) || wrappedNative_ == address(0)) {
            revert AMMRouterZeroAddress();
        }

        factory = factory_;
        wrappedNative = wrappedNative_;
    }

    /// @notice Accepts native assets only from the configured wrapped native token during unwraps.
    receive() external payable {
        if (msg.sender != wrappedNative) {
            revert AMMRouterInvalidNativeSender(msg.sender);
        }
    }

    /// @inheritdoc IAMMRouter
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure override returns (uint256 amountB) {
        if (amountA == 0) {
            revert AMMRouterInsufficientAmount();
        }
        if (reserveA == 0 || reserveB == 0) {
            revert AMMRouterInsufficientLiquidity();
        }

        amountB = (amountA * reserveB) / reserveA;
    }

    /// @inheritdoc IAMMRouter
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        override
        returns (uint256 amountOut)
    {
        if (amountIn == 0) {
            revert AMMRouterInsufficientAmount();
        }
        if (reserveIn == 0 || reserveOut == 0) {
            revert AMMRouterInsufficientLiquidity();
        }

        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        amountOut = (amountInWithFee * reserveOut) / ((reserveIn * FEE_DENOMINATOR) + amountInWithFee);
    }

    /// @inheritdoc IAMMRouter
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        override
        returns (uint256 amountIn)
    {
        if (amountOut == 0) {
            revert AMMRouterInsufficientAmount();
        }
        if (reserveIn == 0 || reserveOut == 0 || amountOut >= reserveOut) {
            revert AMMRouterInsufficientLiquidity();
        }

        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * FEE_NUMERATOR;
        amountIn = (numerator / denominator) + 1;
    }

    /// @inheritdoc IAMMRouter
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        public
        view
        override
        returns (uint256[] memory amounts)
    {
        _validatePath(path);

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i = 0; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = _getReserves(path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    /// @inheritdoc IAMMRouter
    function getAmountsIn(uint256 amountOut, address[] calldata path)
        public
        view
        override
        returns (uint256[] memory amounts)
    {
        _validatePath(path);

        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;

        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) = _getReserves(path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }

    /// @inheritdoc IAMMRouter
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (address pair, uint256 addAmountA, uint256 addAmountB) =
            _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);

        _safeTransferFrom(tokenA, msg.sender, pair, addAmountA);
        _safeTransferFrom(tokenB, msg.sender, pair, addAmountB);

        liquidity = IAMMPair(pair).mint(to);
        return (addAmountA, addAmountB, liquidity);
    }

    /// @inheritdoc IAMMRouter
    /// @dev The ERC-20 leg cannot be the configured wrapped native token; use the non-native liquidity path instead.
    function addLiquidityNative(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountNativeMin,
        address to,
        uint256 deadline
    )
        external
        payable
        override
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountNative, uint256 liquidity)
    {
        if (token == wrappedNative) {
            revert AMMRouterInvalidWrappedNativeToken(token);
        }

        (address pair, uint256 addAmountToken, uint256 addAmountNative) =
            _addLiquidity(token, wrappedNative, amountTokenDesired, msg.value, amountTokenMin, amountNativeMin);

        _safeTransferFrom(token, msg.sender, pair, addAmountToken);
        _wrapNative(addAmountNative);
        _safeTransfer(wrappedNative, pair, addAmountNative);

        liquidity = IAMMPair(pair).mint(to);

        uint256 refund = msg.value - addAmountNative;
        if (refund != 0) {
            _safeTransferNative(msg.sender, refund);
        }

        return (addAmountToken, addAmountNative, liquidity);
    }

    /// @inheritdoc IAMMRouter
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        return _removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to);
    }

    /// @inheritdoc IAMMRouter
    /// @dev The ERC-20 leg cannot be the configured wrapped native token; use the non-native liquidity path instead.
    function removeLiquidityNative(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNativeMin,
        address to,
        uint256 deadline
    ) public override ensure(deadline) returns (uint256 amountToken, uint256 amountNative) {
        if (token == wrappedNative) {
            revert AMMRouterInvalidWrappedNativeToken(token);
        }

        (amountToken, amountNative) =
            _removeLiquidity(token, wrappedNative, liquidity, amountTokenMin, amountNativeMin, address(this));

        _safeTransfer(token, to, amountToken);
        _unwrapNative(amountNative);
        _safeTransferNative(to, amountNative);
    }

    /// @inheritdoc IAMMRouter
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        _permitLiquidity(tokenA, tokenB, liquidity, deadline, approveMax, v, r, s);
        return removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    /// @inheritdoc IAMMRouter
    function removeLiquidityNativeWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNativeMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override ensure(deadline) returns (uint256 amountToken, uint256 amountNative) {
        _permitLiquidity(token, wrappedNative, liquidity, deadline, approveMax, v, r, s);
        return removeLiquidityNative(token, liquidity, amountTokenMin, amountNativeMin, to, deadline);
    }

    /// @inheritdoc IAMMRouter
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = getAmountsOut(amountIn, path);
        uint256 finalAmountOut = amounts[amounts.length - 1];
        if (finalAmountOut < amountOutMin) {
            revert AMMRouterInsufficientOutputAmount(finalAmountOut, amountOutMin);
        }

        _safeTransferFrom(path[0], msg.sender, _pairFor(path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    /// @inheritdoc IAMMRouter
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = getAmountsIn(amountOut, path);
        uint256 requiredAmountIn = amounts[0];
        if (requiredAmountIn > amountInMax) {
            revert AMMRouterExcessiveInputAmount(requiredAmountIn, amountInMax);
        }

        _safeTransferFrom(path[0], msg.sender, _pairFor(path[0], path[1]), requiredAmountIn);
        _swap(amounts, path, to);
    }

    /// @inheritdoc IAMMRouter
    function swapExactNativeForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        _validateNativeInPath(path);

        amounts = getAmountsOut(msg.value, path);
        uint256 finalAmountOut = amounts[amounts.length - 1];
        if (finalAmountOut < amountOutMin) {
            revert AMMRouterInsufficientOutputAmount(finalAmountOut, amountOutMin);
        }

        _wrapNative(amounts[0]);
        _safeTransfer(wrappedNative, _pairFor(path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    /// @inheritdoc IAMMRouter
    function swapTokensForExactNative(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256[] memory amounts) {
        _validateNativeOutPath(path);

        amounts = getAmountsIn(amountOut, path);
        uint256 requiredAmountIn = amounts[0];
        if (requiredAmountIn > amountInMax) {
            revert AMMRouterExcessiveInputAmount(requiredAmountIn, amountInMax);
        }

        _safeTransferFrom(path[0], msg.sender, _pairFor(path[0], path[1]), requiredAmountIn);
        _swap(amounts, path, address(this));

        _unwrapNative(amounts[amounts.length - 1]);
        _safeTransferNative(to, amounts[amounts.length - 1]);
    }

    /// @inheritdoc IAMMRouter
    function swapExactTokensForNative(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256[] memory amounts) {
        _validateNativeOutPath(path);

        amounts = getAmountsOut(amountIn, path);
        uint256 finalAmountOut = amounts[amounts.length - 1];
        if (finalAmountOut < amountOutMin) {
            revert AMMRouterInsufficientOutputAmount(finalAmountOut, amountOutMin);
        }

        _safeTransferFrom(path[0], msg.sender, _pairFor(path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));

        _unwrapNative(finalAmountOut);
        _safeTransferNative(to, finalAmountOut);
    }

    /// @inheritdoc IAMMRouter
    function swapNativeForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external
        payable
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        _validateNativeInPath(path);

        amounts = getAmountsIn(amountOut, path);
        uint256 requiredNativeAmount = amounts[0];
        if (requiredNativeAmount > msg.value) {
            revert AMMRouterExcessiveInputAmount(requiredNativeAmount, msg.value);
        }

        _wrapNative(requiredNativeAmount);
        _safeTransfer(wrappedNative, _pairFor(path[0], path[1]), requiredNativeAmount);
        _swap(amounts, path, to);

        uint256 refund = msg.value - requiredNativeAmount;
        if (refund != 0) {
            _safeTransferNative(msg.sender, refund);
        }
    }

    function _validatePath(address[] calldata path) internal pure {
        if (path.length < 2) {
            revert AMMRouterInvalidPath();
        }
    }

    function _validateNativeInPath(address[] calldata path) internal view {
        _validatePath(path);
        if (path[0] != wrappedNative) {
            revert AMMRouterInvalidWrappedNativePath();
        }
    }

    function _validateNativeOutPath(address[] calldata path) internal view {
        _validatePath(path);
        if (path[path.length - 1] != wrappedNative) {
            revert AMMRouterInvalidWrappedNativePath();
        }
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (address pair, uint256 amountA, uint256 amountB) {
        pair = IAMMFactory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            pair = IAMMFactory(factory).createPair(tokenA, tokenB);
        }

        (uint256 reserveA, uint256 reserveB) = _getReserves(tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            uint256 amountBOptimal = quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                amountA = quote(amountBDesired, reserveB, reserveA);
                amountB = amountBDesired;
            }
        }

        if (amountA < amountAMin) {
            revert AMMRouterInsufficientAAmount(amountA, amountAMin);
        }
        if (amountB < amountBMin) {
            revert AMMRouterInsufficientBAmount(amountB, amountBMin);
        }
    }

    function _removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) internal returns (uint256 amountA, uint256 amountB) {
        address pair = _pairFor(tokenA, tokenB);
        _safeTransferFrom(pair, msg.sender, pair, liquidity);

        (uint256 amount0, uint256 amount1) = IAMMPair(pair).burn(to);
        (address sortedToken0,) = _sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == sortedToken0 ? (amount0, amount1) : (amount1, amount0);

        if (amountA < amountAMin) {
            revert AMMRouterInsufficientAAmount(amountA, amountAMin);
        }
        if (amountB < amountBMin) {
            revert AMMRouterInsufficientBAmount(amountB, amountBMin);
        }
    }

    function _swap(uint256[] memory amounts, address[] calldata path, address to) internal {
        for (uint256 i = 0; i < path.length - 1; i++) {
            address input = path[i];
            address output = path[i + 1];
            address pair = _pairFor(input, output);
            (address token0,) = _sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address recipient = i < path.length - 2 ? _pairFor(output, path[i + 2]) : to;
            IAMMPair(pair).swap(amount0Out, amount1Out, recipient, "");
        }
    }

    function _getReserves(address tokenA, address tokenB) internal view returns (uint256 reserveA, uint256 reserveB) {
        address pair = _pairFor(tokenA, tokenB);
        (uint112 reserve0, uint112 reserve1,) = IAMMPair(pair).getReserves();
        (address sortedToken0,) = _sortTokens(tokenA, tokenB);
        return tokenA == sortedToken0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function _pairFor(address tokenA, address tokenB) internal view returns (address pair) {
        _sortTokens(tokenA, tokenB);
        pair = IAMMFactory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            revert AMMRouterPairUnavailable(tokenA, tokenB);
        }
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) {
            revert AMMRouterIdenticalTokens();
        }
        if (tokenA == address(0) || tokenB == address(0)) {
            revert AMMRouterZeroTokenAddress();
        }

        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _permitLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 allowanceValue = approveMax ? type(uint256).max : liquidity;
        IAMMPair(_pairFor(tokenA, tokenB)).permit(msg.sender, address(this), allowanceValue, deadline, v, r, s);
    }

    function _wrapNative(uint256 value) internal {
        if (value == 0) {
            return;
        }

        (bool success,) = wrappedNative.call{value: value}(abi.encodeWithSelector(IWrappedNative.deposit.selector));
        if (!success) {
            revert AMMRouterWrapFailed(value);
        }
    }

    function _unwrapNative(uint256 value) internal {
        if (value == 0) {
            return;
        }

        (bool success,) = wrappedNative.call(abi.encodeCall(IWrappedNative.withdraw, (value)));
        if (!success) {
            revert AMMRouterUnwrapFailed(value);
        }
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        if (value == 0) {
            return;
        }

        (bool success, bytes memory data) = token.call(abi.encodeCall(IERC20.transfer, (to, value)));
        bool validReturn = data.length == 0 || (data.length == 32 && abi.decode(data, (bool)));
        if (!success || !validReturn) {
            revert AMMRouterTransferFailed(token, to, value);
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        if (value == 0) {
            return;
        }

        (bool success, bytes memory data) = token.call(abi.encodeCall(IERC20.transferFrom, (from, to, value)));
        bool validReturn = data.length == 0 || (data.length == 32 && abi.decode(data, (bool)));
        if (!success || !validReturn) {
            revert AMMRouterTransferFromFailed(token, from, to, value);
        }
    }

    function _safeTransferNative(address to, uint256 value) internal {
        if (value == 0) {
            return;
        }

        (bool success,) = payable(to).call{value: value}("");
        if (!success) {
            revert AMMRouterNativeTransferFailed(to, value);
        }
    }
}
