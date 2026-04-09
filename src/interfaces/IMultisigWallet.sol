// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IMultisigWallet
/// @notice Foundation interface for the standalone multisig wallet.
interface IMultisigWallet {
    error MultisigWalletAlreadyInitialized();
    error MultisigWalletInvalidThreshold(uint256 threshold, uint256 ownerCount);
    error MultisigWalletZeroOwner();
    error MultisigWalletDuplicateOwner(address owner);
    error MultisigWalletZeroMultiSend();

    event WalletInitialized(address[] owners, uint256 threshold, address multiSendCallOnly);

    function initialize(address[] calldata owners, uint256 threshold, address multiSendCallOnly) external;
    function nonce() external view returns (uint256);
    function threshold() external view returns (uint256);
    function ownerCount() external view returns (uint256);
    function multiSendCallOnly() external view returns (address);
    function isOwner(address account) external view returns (bool);
    function getOwners() external view returns (address[] memory);
}
