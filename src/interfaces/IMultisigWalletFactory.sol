// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IMultisigWalletFactory
/// @notice Deterministic clone deployment surface for standalone multisig wallets.
interface IMultisigWalletFactory {
    error MultisigWalletFactoryZeroImplementation();

    event WalletDeployed(address indexed wallet, address indexed implementation, bytes32 indexed salt);

    function implementation() external view returns (address);
    function deployWallet(bytes32 salt, address[] calldata owners, uint256 threshold_, address multiSendCallOnly_)
        external
        returns (address wallet);
    function predictWalletAddress(bytes32 salt) external view returns (address predicted);
}
