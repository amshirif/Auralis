// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IAMMFactory
/// @notice Factory and registry surface for deterministic AMM pair deployment.
interface IAMMFactory {
    /// @notice Emitted when a deterministic pair is deployed for two sorted tokens.
    /// @param token0 Lower-address token in the pair.
    /// @param token1 Higher-address token in the pair.
    /// @param pair Deployed pair address.
    /// @param pairIndex One-based pair count after deployment.
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 pairIndex);

    /// @notice Returns the protocol fee recipient.
    /// @return Fee recipient address, or zero address when protocol fees are disabled.
    function feeTo() external view returns (address);

    /// @notice Returns the account authorized to update fee settings.
    /// @return Address with factory fee-configuration authority.
    function feeToSetter() external view returns (address);

    /// @notice Returns the AMM pair creation-code hash used in CREATE2 address derivation.
    /// @return Hash of the AMMPair creation bytecode.
    function pairCodeHash() external pure returns (bytes32);

    /// @notice Returns the deployed pair for two tokens.
    /// @param tokenA First token address.
    /// @param tokenB Second token address.
    /// @return Pair address, or zero address when no pair exists.
    function getPair(address tokenA, address tokenB) external view returns (address);

    /// @notice Returns a pair by registry index.
    /// @param index Zero-based index into the pair registry.
    /// @return Pair address at the requested index.
    function allPairs(uint256 index) external view returns (address);

    /// @notice Returns the number of pairs deployed by the factory.
    /// @return Total pair count.
    function allPairsLength() external view returns (uint256);

    /// @notice Deploys the deterministic pair for two tokens if it does not already exist.
    /// @param tokenA First token address.
    /// @param tokenB Second token address.
    /// @return pair Deployed pair address.
    function createPair(address tokenA, address tokenB) external returns (address pair);

    /// @notice Updates the protocol fee recipient.
    /// @param feeTo_ New fee recipient, or zero address to disable protocol fees.
    function setFeeTo(address feeTo_) external;

    /// @notice Updates the account authorized to change factory fee settings.
    /// @param feeToSetter_ New fee-setting authority.
    function setFeeToSetter(address feeToSetter_) external;
}
