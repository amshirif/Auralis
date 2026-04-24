// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IMultisigWallet
/// @notice Foundation interface for the standalone multisig wallet.
interface IMultisigWallet {
    /// @notice Reverts when wallet initialization is attempted more than once.
    error MultisigWalletAlreadyInitialized();
    /// @notice Reverts when execution is attempted before the wallet has a nonzero threshold.
    error MultisigWalletNotOperational();
    /// @notice Reverts when owner-management functions are called outside wallet self-execution.
    error MultisigWalletCallerNotSelf();
    /// @notice Reverts when a threshold is zero or exceeds owner count.
    /// @param threshold Supplied threshold.
    /// @param ownerCount Current or supplied owner count.
    error MultisigWalletInvalidThreshold(uint256 threshold, uint256 ownerCount);
    /// @notice Reverts when an owner address is zero.
    error MultisigWalletZeroOwner();
    /// @notice Reverts when an owner is duplicated.
    /// @param owner Duplicate owner.
    error MultisigWalletDuplicateOwner(address owner);
    /// @notice Reverts when an owner is not in the owner set.
    /// @param owner Missing owner.
    error MultisigWalletOwnerNotFound(address owner);
    /// @notice Reverts when replacing an owner with itself.
    /// @param owner Owner supplied for both old and new owner.
    error MultisigWalletReplaceOwnerNoop(address owner);
    /// @notice Reverts when attempting to remove the only owner.
    error MultisigWalletCannotRemoveLastOwner();
    /// @notice Reverts when owner removal would leave threshold above owner count.
    /// @param threshold Current threshold.
    /// @param newOwnerCount Owner count after removal.
    error MultisigWalletRemovalInvalidatesThreshold(uint256 threshold, uint256 newOwnerCount);
    /// @notice Reverts when the batch execution helper is zero.
    error MultisigWalletZeroMultiSend();
    /// @notice Reverts when the signature payload length does not match threshold.
    /// @param providedLength Provided signature byte length.
    /// @param requiredLength Required signature byte length.
    error MultisigWalletInvalidSignaturesLength(uint256 providedLength, uint256 requiredLength);
    /// @notice Reverts when a recovered signer is not an owner.
    /// @param signer Recovered signer.
    error MultisigWalletInvalidSigner(address signer);
    /// @notice Reverts when signatures are not sorted in strict ascending signer order.
    /// @param previousSigner Previous recovered signer.
    /// @param currentSigner Current recovered signer.
    error MultisigWalletSignersNotStrictlyOrdered(address previousSigner, address currentSigner);
    /// @notice Reverts when single-call execution targets the zero address.
    error MultisigWalletZeroTarget();

    /// @notice Emitted when a wallet clone is initialized.
    /// @param owners Initial owner set.
    /// @param threshold Initial signature threshold.
    /// @param multiSendCallOnly Batch execution helper address.
    event WalletInitialized(address[] owners, uint256 threshold, address multiSendCallOnly);
    /// @notice Emitted after a successful single-call transaction.
    /// @param digest EIP-712 transaction digest.
    /// @param nonce Nonce consumed by the transaction.
    /// @param target Call target.
    /// @param value Native value sent with the call.
    event TransactionExecuted(bytes32 indexed digest, uint256 indexed nonce, address indexed target, uint256 value);
    /// @notice Emitted after a successful batch transaction.
    /// @param digest EIP-712 batch digest.
    /// @param nonce Nonce consumed by the batch.
    event BatchExecuted(bytes32 indexed digest, uint256 indexed nonce);
    /// @notice Emitted when an owner is added by wallet self-execution.
    /// @param owner Added owner.
    event OwnerAdded(address indexed owner);
    /// @notice Emitted when an owner is removed by wallet self-execution.
    /// @param owner Removed owner.
    event OwnerRemoved(address indexed owner);
    /// @notice Emitted when an owner is replaced by wallet self-execution.
    /// @param oldOwner Removed owner.
    /// @param newOwner Added owner.
    event OwnerReplaced(address indexed oldOwner, address indexed newOwner);
    /// @notice Emitted when threshold changes by wallet self-execution.
    /// @param threshold New threshold.
    event ThresholdChanged(uint256 threshold);

    /// @notice Initializes wallet owner set, threshold, and batch helper.
    /// @param owners Initial owner set.
    /// @param threshold_ Initial signature threshold.
    /// @param multiSendCallOnly_ Batch execution helper address.
    function initialize(address[] calldata owners, uint256 threshold_, address multiSendCallOnly_) external;

    /// @notice Returns the EIP-712 digest for a single-call transaction.
    /// @param to Call target.
    /// @param value Native value to send.
    /// @param data Calldata to send.
    /// @param nonce_ Nonce to include in the digest.
    /// @return Transaction digest.
    function getTransactionHash(address to, uint256 value, bytes calldata data, uint256 nonce_)
        external
        view
        returns (bytes32);

    /// @notice Returns the EIP-712 digest for an encoded batch transaction.
    /// @param transactions Encoded batch transactions.
    /// @param nonce_ Nonce to include in the digest.
    /// @return Batch digest.
    function getBatchHash(bytes calldata transactions, uint256 nonce_) external view returns (bytes32);

    /// @notice Executes a signed single-call transaction.
    /// @param to Call target.
    /// @param value Native value to send.
    /// @param data Calldata to send.
    /// @param signatures Concatenated owner signatures in strict ascending signer order.
    function executeTransaction(address to, uint256 value, bytes calldata data, bytes calldata signatures) external;

    /// @notice Executes a signed call-only batch through the configured helper.
    /// @param transactions Encoded batch transactions.
    /// @param signatures Concatenated owner signatures in strict ascending signer order.
    function executeBatch(bytes calldata transactions, bytes calldata signatures) external;

    /// @notice Adds an owner; callable only by the wallet itself.
    /// @param owner Owner to add.
    function addOwner(address owner) external;

    /// @notice Removes an owner; callable only by the wallet itself.
    /// @param owner Owner to remove.
    function removeOwner(address owner) external;

    /// @notice Replaces an owner; callable only by the wallet itself.
    /// @param oldOwner Owner to remove.
    /// @param newOwner Owner to add.
    function replaceOwner(address oldOwner, address newOwner) external;

    /// @notice Updates the signature threshold; callable only by the wallet itself.
    /// @param newThreshold New signature threshold.
    function changeThreshold(uint256 newThreshold) external;

    /// @notice Validates an ERC-1271 signature payload against current owners and threshold.
    /// @param digest Digest being validated.
    /// @param signatures Concatenated owner signatures.
    /// @return ERC-1271 magic value on success, otherwise `0xffffffff`.
    function isValidSignature(bytes32 digest, bytes calldata signatures) external view returns (bytes4);

    /// @notice Returns the next nonce to be consumed by execution.
    /// @return Current wallet nonce.
    function nonce() external view returns (uint256);

    /// @notice Returns the current signature threshold.
    /// @return Current threshold.
    function threshold() external view returns (uint256);

    /// @notice Returns the number of owners.
    /// @return Current owner count.
    function ownerCount() external view returns (uint256);

    /// @notice Returns the configured batch execution helper.
    /// @return MultiSendCallOnly helper address.
    function multiSendCallOnly() external view returns (address);

    /// @notice Returns whether `account` is an owner.
    /// @param account Account to inspect.
    /// @return True when account is an owner.
    function isOwner(address account) external view returns (bool);

    /// @notice Returns the full owner set.
    /// @return Current owners in stored order.
    function getOwners() external view returns (address[] memory);
}
