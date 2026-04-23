// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IMultisigWallet
/// @notice Foundation interface for the standalone multisig wallet.
interface IMultisigWallet {
    error MultisigWalletAlreadyInitialized();
    error MultisigWalletNotOperational();
    error MultisigWalletCallerNotSelf();
    error MultisigWalletInvalidThreshold(uint256 threshold, uint256 ownerCount);
    error MultisigWalletZeroOwner();
    error MultisigWalletDuplicateOwner(address owner);
    error MultisigWalletOwnerNotFound(address owner);
    error MultisigWalletReplaceOwnerNoop(address owner);
    error MultisigWalletCannotRemoveLastOwner();
    error MultisigWalletRemovalInvalidatesThreshold(uint256 threshold, uint256 newOwnerCount);
    error MultisigWalletZeroMultiSend();
    error MultisigWalletInvalidSignaturesLength(uint256 providedLength, uint256 requiredLength);
    error MultisigWalletInvalidSigner(address signer);
    error MultisigWalletSignersNotStrictlyOrdered(address previousSigner, address currentSigner);
    error MultisigWalletZeroTarget();

    event WalletInitialized(address[] owners, uint256 threshold, address multiSendCallOnly);
    event TransactionExecuted(bytes32 indexed digest, uint256 indexed nonce, address indexed target, uint256 value);
    event BatchExecuted(bytes32 indexed digest, uint256 indexed nonce);
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event OwnerReplaced(address indexed oldOwner, address indexed newOwner);
    event ThresholdChanged(uint256 threshold);

    function initialize(address[] calldata owners, uint256 threshold_, address multiSendCallOnly_) external;
    function getTransactionHash(address to, uint256 value, bytes calldata data, uint256 nonce_)
        external
        view
        returns (bytes32);
    function getBatchHash(bytes calldata transactions, uint256 nonce_) external view returns (bytes32);
    function executeTransaction(address to, uint256 value, bytes calldata data, bytes calldata signatures) external;
    function executeBatch(bytes calldata transactions, bytes calldata signatures) external;
    function addOwner(address owner) external;
    function removeOwner(address owner) external;
    function replaceOwner(address oldOwner, address newOwner) external;
    function changeThreshold(uint256 newThreshold) external;
    function isValidSignature(bytes32 digest, bytes calldata signatures) external view returns (bytes4);
    function nonce() external view returns (uint256);
    function threshold() external view returns (uint256);
    function ownerCount() external view returns (uint256);
    function multiSendCallOnly() external view returns (address);
    function isOwner(address account) external view returns (bool);
    function getOwners() external view returns (address[] memory);
}
