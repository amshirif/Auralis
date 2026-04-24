// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AMMPair} from "./AMMPair.sol";
import {IAMMFactory} from "../interfaces/IAMMFactory.sol";

/// @title AMMFactory
/// @notice Deterministic CREATE2 registry for standalone V2-style AMM pairs.
contract AMMFactory is IAMMFactory {
    error AMMFactoryForbidden();
    error AMMFactoryZeroAddress();
    error AMMFactoryZeroFeeToSetter();
    error AMMFactoryIdenticalTokens();
    error AMMFactoryPairExists(address token0, address token1);

    address public override feeTo;
    address public override feeToSetter;
    mapping(address tokenA => mapping(address tokenB => address pair)) public override getPair;
    address[] public override allPairs;

    constructor() {
        feeToSetter = msg.sender;
    }

    function pairCodeHash() public pure override returns (bytes32) {
        // forge-lint: disable-next-line(asm-keccak256) -- CREATE2 code hash is exposed in canonical high-level form.
        return keccak256(type(AMMPair).creationCode);
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        if (getPair[token0][token1] != address(0)) {
            revert AMMFactoryPairExists(token0, token1);
        }

        // forge-lint: disable-next-line(asm-keccak256) -- pair salt mirrors the CREATE2 address formula.
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        pair = address(new AMMPair{salt: salt}());

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
        AMMPair(pair).initialize(token0, token1);
    }

    function setFeeTo(address feeTo_) external override {
        _requireFeeToSetter();
        feeTo = feeTo_;
    }

    function setFeeToSetter(address feeToSetter_) external override {
        _requireFeeToSetter();
        if (feeToSetter_ == address(0)) {
            revert AMMFactoryZeroFeeToSetter();
        }
        feeToSetter = feeToSetter_;
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) {
            revert AMMFactoryIdenticalTokens();
        }
        if (tokenA == address(0) || tokenB == address(0)) {
            revert AMMFactoryZeroAddress();
        }

        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _requireFeeToSetter() internal view {
        if (msg.sender != feeToSetter) {
            revert AMMFactoryForbidden();
        }
    }
}
