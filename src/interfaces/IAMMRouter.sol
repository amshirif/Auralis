// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IAMMRouter
/// @notice User-facing router and quoting surface for the standalone AMM subsystem.
interface IAMMRouter {
    /// @notice Returns the AMM factory used for pair lookup and deployment.
    /// @return Factory address.
    function factory() external view returns (address);

    /// @notice Returns the wrapped native token used by native-asset routes.
    /// @return Wrapped native token address.
    function wrappedNative() external view returns (address);

    /// @notice Quotes the counter-asset amount for an equivalent-value add-liquidity leg.
    /// @param amountA Input amount for reserve A.
    /// @param reserveA Reserve backing amount A.
    /// @param reserveB Reserve backing amount B.
    /// @return amountB Quoted amount for reserve B.
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);

    /// @notice Quotes swap output for an exact input amount and reserves.
    /// @param amountIn Exact input amount.
    /// @param reserveIn Input-side reserve.
    /// @param reserveOut Output-side reserve.
    /// @return amountOut Output amount after AMM fee.
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256);

    /// @notice Quotes swap input required for an exact output amount and reserves.
    /// @param amountOut Exact output amount.
    /// @param reserveIn Input-side reserve.
    /// @param reserveOut Output-side reserve.
    /// @return amountIn Required input amount including AMM fee.
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256);

    /// @notice Quotes output amounts through a multi-hop path for an exact input amount.
    /// @param amountIn Exact input amount for the first hop.
    /// @param path Ordered token path.
    /// @return amounts Per-hop amounts, ending with final output.
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);

    /// @notice Quotes input amounts through a multi-hop path for an exact output amount.
    /// @param amountOut Exact output amount for the final hop.
    /// @param path Ordered token path.
    /// @return amounts Per-hop amounts, beginning with required input.
    function getAmountsIn(uint256 amountOut, address[] calldata path) external view returns (uint256[] memory amounts);

    /// @notice Adds ERC-20/ERC-20 liquidity to a pair, deploying the pair if needed.
    /// @param tokenA First token address.
    /// @param tokenB Second token address.
    /// @param amountADesired Desired tokenA amount.
    /// @param amountBDesired Desired tokenB amount.
    /// @param amountAMin Minimum tokenA amount accepted.
    /// @param amountBMin Minimum tokenB amount accepted.
    /// @param to Recipient of LP tokens.
    /// @param deadline Latest timestamp at which the call may execute.
    /// @return amountA TokenA amount deposited.
    /// @return amountB TokenB amount deposited.
    /// @return liquidity LP tokens minted.
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /// @notice Adds ERC-20/native liquidity, wrapping the native leg before minting LP tokens.
    /// @param token ERC-20 token paired with wrapped native.
    /// @param amountTokenDesired Desired ERC-20 amount.
    /// @param amountTokenMin Minimum ERC-20 amount accepted.
    /// @param amountNativeMin Minimum native amount accepted.
    /// @param to Recipient of LP tokens.
    /// @param deadline Latest timestamp at which the call may execute.
    /// @return amountToken ERC-20 amount deposited.
    /// @return amountNative Native amount wrapped and deposited.
    /// @return liquidity LP tokens minted.
    function addLiquidityNative(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountNativeMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountNative, uint256 liquidity);

    /// @notice Removes ERC-20/ERC-20 liquidity from a pair.
    /// @param tokenA First token address.
    /// @param tokenB Second token address.
    /// @param liquidity LP token amount to burn.
    /// @param amountAMin Minimum tokenA amount accepted.
    /// @param amountBMin Minimum tokenB amount accepted.
    /// @param to Recipient of withdrawn tokens.
    /// @param deadline Latest timestamp at which the call may execute.
    /// @return amountA TokenA amount withdrawn.
    /// @return amountB TokenB amount withdrawn.
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    /// @notice Removes ERC-20/native liquidity, unwrapping the native leg before transfer.
    /// @param token ERC-20 token paired with wrapped native.
    /// @param liquidity LP token amount to burn.
    /// @param amountTokenMin Minimum ERC-20 amount accepted.
    /// @param amountNativeMin Minimum native amount accepted.
    /// @param to Recipient of withdrawn assets.
    /// @param deadline Latest timestamp at which the call may execute.
    /// @return amountToken ERC-20 amount withdrawn.
    /// @return amountNative Native amount withdrawn.
    function removeLiquidityNative(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNativeMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountNative);

    /// @notice Removes ERC-20/ERC-20 liquidity after approving LP tokens by permit.
    /// @param tokenA First token address.
    /// @param tokenB Second token address.
    /// @param liquidity LP token amount to burn.
    /// @param amountAMin Minimum tokenA amount accepted.
    /// @param amountBMin Minimum tokenB amount accepted.
    /// @param to Recipient of withdrawn tokens.
    /// @param deadline Latest timestamp at which the call may execute and permit must be valid.
    /// @param approveMax Whether the permit approved uint256 max instead of `liquidity`.
    /// @param v Permit recovery id.
    /// @param r Permit signature r value.
    /// @param s Permit signature s value.
    /// @return amountA TokenA amount withdrawn.
    /// @return amountB TokenB amount withdrawn.
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
    ) external returns (uint256 amountA, uint256 amountB);

    /// @notice Removes ERC-20/native liquidity after approving LP tokens by permit.
    /// @param token ERC-20 token paired with wrapped native.
    /// @param liquidity LP token amount to burn.
    /// @param amountTokenMin Minimum ERC-20 amount accepted.
    /// @param amountNativeMin Minimum native amount accepted.
    /// @param to Recipient of withdrawn assets.
    /// @param deadline Latest timestamp at which the call may execute and permit must be valid.
    /// @param approveMax Whether the permit approved uint256 max instead of `liquidity`.
    /// @param v Permit recovery id.
    /// @param r Permit signature r value.
    /// @param s Permit signature s value.
    /// @return amountToken ERC-20 amount withdrawn.
    /// @return amountNative Native amount withdrawn.
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
    ) external returns (uint256 amountToken, uint256 amountNative);

    /// @notice Swaps an exact ERC-20 input amount for at least `amountOutMin` output through `path`.
    /// @param amountIn Exact input token amount.
    /// @param amountOutMin Minimum final output amount accepted.
    /// @param path Ordered token path.
    /// @param to Recipient of final output tokens.
    /// @param deadline Latest timestamp at which the call may execute.
    /// @return amounts Per-hop swap amounts.
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swaps up to `amountInMax` ERC-20 input for an exact ERC-20 output amount.
    /// @param amountOut Exact final output amount.
    /// @param amountInMax Maximum input amount accepted.
    /// @param path Ordered token path.
    /// @param to Recipient of final output tokens.
    /// @param deadline Latest timestamp at which the call may execute.
    /// @return amounts Per-hop swap amounts.
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swaps exact native input for at least `amountOutMin` output through `path`.
    /// @param amountOutMin Minimum final output amount accepted.
    /// @param path Ordered token path beginning with wrapped native.
    /// @param to Recipient of final output tokens.
    /// @param deadline Latest timestamp at which the call may execute.
    /// @return amounts Per-hop swap amounts.
    function swapExactNativeForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts);

    /// @notice Swaps up to `amountInMax` ERC-20 input for an exact native output amount.
    /// @param amountOut Exact native output amount.
    /// @param amountInMax Maximum input token amount accepted.
    /// @param path Ordered token path ending with wrapped native.
    /// @param to Recipient of unwrapped native output.
    /// @param deadline Latest timestamp at which the call may execute.
    /// @return amounts Per-hop swap amounts.
    function swapTokensForExactNative(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swaps an exact ERC-20 input amount for at least `amountOutMin` native output.
    /// @param amountIn Exact input token amount.
    /// @param amountOutMin Minimum native output amount accepted.
    /// @param path Ordered token path ending with wrapped native.
    /// @param to Recipient of unwrapped native output.
    /// @param deadline Latest timestamp at which the call may execute.
    /// @return amounts Per-hop swap amounts.
    function swapExactTokensForNative(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swaps native input for an exact output token amount, refunding unused native input.
    /// @param amountOut Exact final output amount.
    /// @param path Ordered token path beginning with wrapped native.
    /// @param to Recipient of output tokens.
    /// @param deadline Latest timestamp at which the call may execute.
    /// @return amounts Per-hop swap amounts.
    function swapNativeForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts);
}
