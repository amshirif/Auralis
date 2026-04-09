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
    error MultisigWalletInvalidSignaturesLength(uint256 providedLength, uint256 requiredLength);
    error MultisigWalletInvalidSigner(address signer);
    error MultisigWalletSignersNotStrictlyOrdered(address previousSigner, address currentSigner);
    error MultisigWalletZeroTarget();

    event WalletInitialized(address[] owners, uint256 threshold, address multiSendCallOnly);
    event TransactionExecuted(bytes32 indexed digest, uint256 indexed nonce, address indexed target, uint256 value);

    function initialize(address[] calldata owners, uint256 threshold_, address multiSendCallOnly_) external;
    function getTransactionHash(address to, uint256 value, bytes calldata data, uint256 nonce_)
        external
        view
        returns (bytes32);
    function executeTransaction(address to, uint256 value, bytes calldata data, bytes calldata signatures) external;
    function isValidSignature(bytes32 digest, bytes calldata signatures) external view returns (bytes4);
    function nonce() external view returns (uint256);
    function threshold() external view returns (uint256);
    function ownerCount() external view returns (uint256);
    function multiSendCallOnly() external view returns (address);
    function isOwner(address account) external view returns (bool);
    function getOwners() external view returns (address[] memory);
}
