// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IMultisigWalletFactory
/// @notice Deterministic clone deployment surface for standalone multisig wallets.
interface IMultisigWalletFactory {
    /// @notice Reverts when the factory is constructed with a zero implementation.
    error MultisigWalletFactoryZeroImplementation();

    /// @notice Emitted when a wallet clone is deployed and initialized.
    /// @param wallet Deployed wallet clone.
    /// @param implementation Wallet implementation used by the clone.
    /// @param salt CREATE2 salt used for deployment.
    event WalletDeployed(address indexed wallet, address indexed implementation, bytes32 indexed salt);

    /// @notice Returns the master wallet implementation cloned by this factory.
    /// @return Implementation address.
    function implementation() external view returns (address);

    /// @notice Deploys and initializes a deterministic wallet clone.
    /// @param salt CREATE2 salt.
    /// @param owners Initial owner set.
    /// @param threshold_ Initial signature threshold.
    /// @param multiSendCallOnly_ Batch execution helper address.
    /// @return wallet Deployed wallet address.
    function deployWallet(bytes32 salt, address[] calldata owners, uint256 threshold_, address multiSendCallOnly_)
        external
        returns (address wallet);

    /// @notice Predicts the wallet clone address for `salt`.
    /// @param salt CREATE2 salt.
    /// @return predicted Predicted wallet address.
    function predictWalletAddress(bytes32 salt) external view returns (address predicted);
}
