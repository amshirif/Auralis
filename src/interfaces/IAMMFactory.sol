// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IAMMFactory
/// @notice Factory and registry surface for deterministic AMM pair deployment.
interface IAMMFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 pairIndex);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function getPair(address tokenA, address tokenB) external view returns (address);
    function allPairs(uint256 index) external view returns (address);
    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);
    function setFeeTo(address feeTo_) external;
    function setFeeToSetter(address feeToSetter_) external;
}
