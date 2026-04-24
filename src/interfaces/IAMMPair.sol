// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAMMLpToken} from "./IAMMLpToken.sol";

/// @title IAMMPair
/// @notice Constant-product AMM pair surface, including LP token behavior.
interface IAMMPair is IAMMLpToken {
    /// @notice Emitted when liquidity is minted from deposited token balances.
    /// @param sender Account that triggered the mint.
    /// @param amount0 Token0 amount added to reserves.
    /// @param amount1 Token1 amount added to reserves.
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    /// @notice Emitted when liquidity is burned for underlying reserves.
    /// @param sender Account that triggered the burn.
    /// @param amount0 Token0 amount withdrawn.
    /// @param amount1 Token1 amount withdrawn.
    /// @param to Recipient of the withdrawn tokens.
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    /// @notice Emitted after a swap updates pair reserves.
    /// @param sender Account that triggered the swap.
    /// @param amount0In Token0 amount paid in.
    /// @param amount1In Token1 amount paid in.
    /// @param amount0Out Token0 amount paid out.
    /// @param amount1Out Token1 amount paid out.
    /// @param to Recipient of output tokens.
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    /// @notice Emitted when stored reserves are updated.
    /// @param reserve0 New token0 reserve.
    /// @param reserve1 New token1 reserve.
    event Sync(uint112 reserve0, uint112 reserve1);

    /// @notice Returns the factory that deployed and initialized this pair.
    /// @return Factory address.
    function factory() external view returns (address);

    /// @notice Returns the lower-address token in the pair.
    /// @return Token0 address.
    function token0() external view returns (address);

    /// @notice Returns the higher-address token in the pair.
    /// @return Token1 address.
    function token1() external view returns (address);

    /// @notice Returns the permanently locked minimum LP liquidity.
    /// @return Minimum liquidity minted to the dead address on first mint.
    // forge-lint: disable-next-line(mixed-case-function) -- canonical AMM interface getter preserves selector compatibility.
    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    /// @notice Returns current reserves and the timestamp of the last reserve update.
    /// @return reserve0 Stored token0 reserve.
    /// @return reserve1 Stored token1 reserve.
    /// @return blockTimestampLast Timestamp truncated to uint32 at the last update.
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    /// @notice Returns cumulative token0 price for TWAP consumers.
    /// @return Token0 cumulative price value.
    function price0CumulativeLast() external view returns (uint256);

    /// @notice Returns cumulative token1 price for TWAP consumers.
    /// @return Token1 cumulative price value.
    function price1CumulativeLast() external view returns (uint256);

    /// @notice Returns the last reserve product used for protocol fee minting.
    /// @return Last recorded reserve product.
    function kLast() external view returns (uint256);

    /// @notice Initializes pair tokens; callable only once by the factory.
    /// @param token0_ Lower-address token.
    /// @param token1_ Higher-address token.
    function initialize(address token0_, address token1_) external;

    /// @notice Mints LP tokens to `to` from the pair's current token balance surplus.
    /// @param to Recipient of minted LP tokens.
    /// @return liquidity LP tokens minted.
    function mint(address to) external returns (uint256 liquidity);

    /// @notice Burns LP tokens held by the pair and sends underlying tokens to `to`.
    /// @param to Recipient of withdrawn tokens.
    /// @return amount0 Token0 amount withdrawn.
    /// @return amount1 Token1 amount withdrawn.
    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    /// @notice Swaps output tokens to `to` after input tokens have been transferred to the pair.
    /// @param amount0Out Token0 output amount.
    /// @param amount1Out Token1 output amount.
    /// @param to Output recipient.
    /// @param data Unsupported callback data; must be empty in this implementation.
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    /// @notice Transfers token balances above stored reserves to `to`.
    /// @param to Recipient of excess balances.
    function skim(address to) external;

    /// @notice Syncs stored reserves to current token balances.
    function sync() external;
}
