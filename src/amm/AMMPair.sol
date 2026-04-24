// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AMMFixedPoint} from "./libraries/AMMFixedPoint.sol";
import {AMMLpToken} from "./AMMLpToken.sol";
import {AMMMath} from "./libraries/AMMMath.sol";
import {IAMMFactory} from "../interfaces/IAMMFactory.sol";
import {IAMMPair} from "../interfaces/IAMMPair.sol";
import {IERC20} from "../interfaces/IERC20.sol";

/// @title AMMPair
/// @notice Constant-product pair core for the standalone V2-style AMM track.
contract AMMPair is AMMLpToken, IAMMPair {
    uint256 internal constant FEE_DENOMINATOR = 1000;
    uint256 internal constant FEE_UNITS = 3;
    address internal constant MINIMUM_LIQUIDITY_SINK = 0x000000000000000000000000000000000000dEaD;

    error AMMPairForbidden();
    error AMMPairAlreadyInitialized();
    error AMMPairZeroTokenAddress();
    error AMMPairIdenticalTokens();
    error AMMPairLocked();
    error AMMPairInvalidRecipient(address to);
    error AMMPairInsufficientLiquidityMinted();
    error AMMPairInsufficientLiquidityBurned();
    error AMMPairInsufficientLiquidity();
    error AMMPairInsufficientInputAmount();
    error AMMPairInsufficientOutputAmount();
    error AMMPairReserveOverflow();
    error AMMPairUnsupportedSwapData();
    error AMMPairTransferFailed(address token, address to, uint256 value);
    error AMMPairKInvariant();

    // forge-lint: disable-next-line(screaming-snake-case-immutable) -- public immutable preserves the IAMMPair getter name.
    address public immutable override factory;

    address public override token0;
    address public override token1;
    uint256 public override price0CumulativeLast;
    uint256 public override price1CumulativeLast;
    uint256 public override kLast;

    uint112 internal _reserve0;
    uint112 internal _reserve1;
    uint32 internal _blockTimestampLast;
    uint256 internal _unlocked = 1;

    constructor() {
        factory = msg.sender;
    }

    modifier lock() {
        _lockBefore();
        _;
        _lockAfter();
    }

    function _lockBefore() internal {
        if (_unlocked != 1) {
            revert AMMPairLocked();
        }

        _unlocked = 0;
    }

    function _lockAfter() internal {
        _unlocked = 1;
    }

    // forge-lint: disable-next-line(mixed-case-function)
    function MINIMUM_LIQUIDITY() public pure override returns (uint256) {
        return 1000;
    }

    function getReserves()
        external
        view
        override
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)
    {
        return (_reserve0, _reserve1, _blockTimestampLast);
    }

    function initialize(address token0_, address token1_) external override {
        if (msg.sender != factory) {
            revert AMMPairForbidden();
        }
        if (_ammLpInitialized) {
            revert AMMPairAlreadyInitialized();
        }
        if (token0_ == address(0) || token1_ == address(0)) {
            revert AMMPairZeroTokenAddress();
        }
        if (token0_ == token1_) {
            revert AMMPairIdenticalTokens();
        }

        _initializeAmmLpToken();
        token0 = token0_;
        token1 = token1_;
    }

    function mint(address to) external override lock returns (uint256 liquidity) {
        uint112 reserve0_ = _reserve0;
        uint112 reserve1_ = _reserve1;
        (uint256 balance0, uint256 balance1) = _currentBalances();

        uint256 amount0 = balance0 - reserve0_;
        uint256 amount1 = balance1 - reserve1_;

        bool feeOn = _mintFee(reserve0_, reserve1_);
        uint256 totalSupply_ = totalSupply();

        if (totalSupply_ == 0) {
            uint256 rootK = AMMMath.sqrt(amount0 * amount1);
            uint256 minimumLiquidity = MINIMUM_LIQUIDITY();
            if (rootK <= minimumLiquidity) {
                revert AMMPairInsufficientLiquidityMinted();
            }

            unchecked {
                liquidity = rootK - minimumLiquidity;
            }
            _mintLp(MINIMUM_LIQUIDITY_SINK, minimumLiquidity);
        } else {
            liquidity = AMMMath.min((amount0 * totalSupply_) / reserve0_, (amount1 * totalSupply_) / reserve1_);
        }

        if (liquidity == 0) {
            revert AMMPairInsufficientLiquidityMinted();
        }

        _mintLp(to, liquidity);
        _update(balance0, balance1, reserve0_, reserve1_);
        if (feeOn) {
            kLast = uint256(_reserve0) * uint256(_reserve1);
        }

        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to) external override lock returns (uint256 amount0, uint256 amount1) {
        uint112 reserve0_ = _reserve0;
        uint112 reserve1_ = _reserve1;
        address token0_ = token0;
        address token1_ = token1;
        (uint256 balance0, uint256 balance1) = _currentBalances();
        uint256 liquidity = balanceOf(address(this));

        bool feeOn = _mintFee(reserve0_, reserve1_);
        uint256 totalSupply_ = totalSupply();

        amount0 = (liquidity * balance0) / totalSupply_;
        amount1 = (liquidity * balance1) / totalSupply_;
        if (amount0 == 0 || amount1 == 0) {
            revert AMMPairInsufficientLiquidityBurned();
        }

        uint256 nextBalance0 = balance0 - amount0;
        uint256 nextBalance1 = balance1 - amount1;

        _burnLp(address(this), liquidity);
        _update(nextBalance0, nextBalance1, reserve0_, reserve1_);
        if (feeOn) {
            kLast = uint256(_reserve0) * uint256(_reserve1);
        }

        _safeTransfer(token0_, to, amount0);
        _safeTransfer(token1_, to, amount1);

        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external override lock {
        if (amount0Out == 0 && amount1Out == 0) {
            revert AMMPairInsufficientOutputAmount();
        }
        if (to == address(0) || to == token0 || to == token1) {
            revert AMMPairInvalidRecipient(to);
        }
        if (data.length != 0) {
            revert AMMPairUnsupportedSwapData();
        }

        uint256 amount0In;
        uint256 amount1In;
        {
            uint112 reserve0_ = _reserve0;
            uint112 reserve1_ = _reserve1;
            if (amount0Out >= reserve0_ || amount1Out >= reserve1_) {
                revert AMMPairInsufficientLiquidity();
            }

            (uint256 balance0Before, uint256 balance1Before) = _currentBalances();
            uint256 balance0 = balance0Before - amount0Out;
            uint256 balance1 = balance1Before - amount1Out;
            amount0In = balance0Before > reserve0_ ? balance0Before - reserve0_ : 0;
            amount1In = balance1Before > reserve1_ ? balance1Before - reserve1_ : 0;

            if (amount0In == 0 && amount1In == 0) {
                revert AMMPairInsufficientInputAmount();
            }

            uint256 balance0Adjusted = (balance0 * FEE_DENOMINATOR) - (amount0In * FEE_UNITS);
            uint256 balance1Adjusted = (balance1 * FEE_DENOMINATOR) - (amount1In * FEE_UNITS);
            uint256 reserveProduct = uint256(reserve0_) * uint256(reserve1_) * (FEE_DENOMINATOR ** 2);
            if ((balance0Adjusted * balance1Adjusted) < reserveProduct) {
                revert AMMPairKInvariant();
            }

            _update(balance0, balance1, reserve0_, reserve1_);
        }

        if (amount0Out != 0) {
            _safeTransfer(token0, to, amount0Out);
        }
        if (amount1Out != 0) {
            _safeTransfer(token1, to, amount1Out);
        }
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function skim(address to) external override lock {
        _safeTransfer(token0, to, IERC20(token0).balanceOf(address(this)) - _reserve0);
        _safeTransfer(token1, to, IERC20(token1).balanceOf(address(this)) - _reserve1);
    }

    function sync() external override lock {
        (uint256 balance0, uint256 balance1) = _currentBalances();
        _update(balance0, balance1, _reserve0, _reserve1);
    }

    function _currentBalances() internal view returns (uint256 balance0, uint256 balance1) {
        return (IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
    }

    function _mintFee(uint112 reserve0_, uint112 reserve1_) internal returns (bool feeOn) {
        address feeTo = IAMMFactory(factory).feeTo();
        feeOn = feeTo != address(0);

        uint256 kLast_ = kLast;
        if (feeOn) {
            if (kLast_ != 0) {
                uint256 rootK = AMMMath.sqrt(uint256(reserve0_) * uint256(reserve1_));
                uint256 rootKLast = AMMMath.sqrt(kLast_);

                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply() * (rootK - rootKLast);
                    uint256 denominator = (rootK * 5) + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity != 0) {
                        _mintLp(feeTo, liquidity);
                    }
                }
            }
        } else if (kLast_ != 0) {
            kLast = 0;
        }
    }

    function _update(uint256 balance0, uint256 balance1, uint112 reserve0_, uint112 reserve1_) internal {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) {
            revert AMMPairReserveOverflow();
        }

        uint32 blockTimestamp = uint32(block.timestamp);
        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - _blockTimestampLast;
        }

        if (timeElapsed > 0 && reserve0_ != 0 && reserve1_ != 0) {
            price0CumulativeLast += uint256(AMMFixedPoint.uqdiv(AMMFixedPoint.encode(reserve1_), reserve0_).value)
            * timeElapsed;
            price1CumulativeLast += uint256(AMMFixedPoint.uqdiv(AMMFixedPoint.encode(reserve0_), reserve1_).value)
            * timeElapsed;
        }

        // forge-lint: disable-next-line(unsafe-typecast)
        _reserve0 = uint112(balance0);
        // forge-lint: disable-next-line(unsafe-typecast)
        _reserve1 = uint112(balance1);
        _blockTimestampLast = blockTimestamp;

        emit Sync(_reserve0, _reserve1);
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        if (value == 0) {
            return;
        }

        (bool success, bytes memory returndata) =
            token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));

        bool validReturn = returndata.length == 0 || (returndata.length == 32 && abi.decode(returndata, (bool)));
        if (!success || !validReturn) {
            revert AMMPairTransferFailed(token, to, value);
        }
    }
}
