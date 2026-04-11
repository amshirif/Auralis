// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "../../src/interfaces/IERC165.sol";
import {IERC1271} from "../../src/interfaces/IERC1271.sol";
import {IMultisigWallet} from "../../src/interfaces/IMultisigWallet.sol";
import {MultiSendCallOnly} from "../../src/wallet/MultiSendCallOnly.sol";
import {LibClone} from "../../src/libraries/LibClone.sol";
import {MultisigWallet} from "../../src/wallet/MultisigWallet.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

abstract contract MultisigWalletFixture is TestBase {
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant TRANSACTION_TYPEHASH =
        keccak256("WalletTransaction(address to,uint256 value,bytes32 dataHash,uint256 nonce)");
    bytes32 internal constant BATCH_TYPEHASH = keccak256("WalletBatch(bytes32 transactionsHash,uint256 nonce)");
    bytes32 internal constant NAME_HASH = keccak256("Auralis Multisig Wallet");
    bytes32 internal constant VERSION_HASH = keccak256("1");
    bytes4 internal constant ERC1271_MAGIC_VALUE = 0x1626ba7e;
    bytes4 internal constant ERC1271_INVALID_SIGNATURE = 0xffffffff;
    uint256 internal constant OWNER_KEY_A = 0xA11CE;
    uint256 internal constant OWNER_KEY_B = 0xB0B;
    uint256 internal constant OWNER_KEY_C = 0xCAFE;
    uint256 internal constant OWNER_KEY_D = 0xD00D;
    uint256 internal constant OWNER_KEY_E = 0xE11E;
    uint256 internal constant OWNER_KEY_F = 0xF00D;

    bytes32 internal constant DEFAULT_SALT = keccak256("auralis.multisig.default-salt");

    MultisigWallet internal implementation;
    MultiSendCallOnly internal multiSendCallOnly;
    IMultisigWallet internal wallet;

    address[] internal actorAddresses;
    uint256[] internal actorKeys;
    address internal defaultMultiSend;

    function setUp() public virtual {
        implementation = new MultisigWallet();
        multiSendCallOnly = new MultiSendCallOnly();
        defaultMultiSend = address(multiSendCallOnly);

        actorAddresses = new address[](6);
        actorKeys = new uint256[](6);
        actorKeys[0] = OWNER_KEY_A;
        actorKeys[1] = OWNER_KEY_B;
        actorKeys[2] = OWNER_KEY_C;
        actorKeys[3] = OWNER_KEY_D;
        actorKeys[4] = OWNER_KEY_E;
        actorKeys[5] = OWNER_KEY_F;

        for (uint256 i = 0; i < actorKeys.length; i++) {
            actorAddresses[i] = VM.addr(actorKeys[i]);
        }

        wallet = _deployInitializedWallet(DEFAULT_SALT, _initialOwners(), 2, defaultMultiSend);
    }

    function _initialOwners() internal view returns (address[] memory owners) {
        owners = new address[](3);
        owners[0] = actorAddresses[0];
        owners[1] = actorAddresses[1];
        owners[2] = actorAddresses[2];
    }

    function _deployInitializedWallet(bytes32 salt, address[] memory owners, uint256 threshold_, address multiSend_)
        internal
        returns (IMultisigWallet clone)
    {
        clone = IMultisigWallet(_deployUninitializedClone(salt));
        clone.initialize(owners, threshold_, multiSend_);
    }

    function _deployUninitializedClone(bytes32 salt) internal returns (address clone) {
        clone = LibClone.cloneDeterministic(address(implementation), salt);
    }

    function _assertSupportedInterfaces() internal view {
        assertTrue(IERC165(address(wallet)).supportsInterface(type(IERC165).interfaceId), "missing IERC165");
        assertTrue(
            IERC165(address(wallet)).supportsInterface(type(IMultisigWallet).interfaceId), "missing IMultisigWallet"
        );
        assertTrue(IERC165(address(wallet)).supportsInterface(type(IERC1271).interfaceId), "missing IERC1271");
    }

    function _domainSeparator(address walletAddress) internal view returns (bytes32) {
        return keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, walletAddress));
    }

    function _transactionDigest(address walletAddress, address to, uint256 value, bytes memory data, uint256 nonce_)
        internal
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(abi.encode(TRANSACTION_TYPEHASH, to, value, keccak256(data), nonce_));
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator(walletAddress), structHash));
    }

    function _batchDigest(address walletAddress, bytes memory transactions, uint256 nonce_)
        internal
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(abi.encode(BATCH_TYPEHASH, keccak256(transactions), nonce_));
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator(walletAddress), structHash));
    }

    function _packedSignaturesForTransaction(
        address to,
        uint256 value,
        bytes memory data,
        uint256 nonce_,
        uint256 signerCount
    ) internal returns (bytes memory) {
        return _packedSignaturesForTransactionAtWallet(address(wallet), to, value, data, nonce_, signerCount);
    }

    function _packedSignaturesForTransactionByIndexes(
        address to,
        uint256 value,
        bytes memory data,
        uint256 nonce_,
        uint256[] memory signerIndexes
    ) internal returns (bytes memory) {
        return _packedSignaturesForTransactionByIndexesAtWallet(address(wallet), to, value, data, nonce_, signerIndexes);
    }

    function _packedSignaturesForTransactionAtWallet(
        address walletAddress,
        address to,
        uint256 value,
        bytes memory data,
        uint256 nonce_,
        uint256 signerCount
    ) internal returns (bytes memory) {
        return _packedSignaturesForDigest(_transactionDigest(walletAddress, to, value, data, nonce_), signerCount);
    }

    function _packedSignaturesForTransactionByIndexesAtWallet(
        address walletAddress,
        address to,
        uint256 value,
        bytes memory data,
        uint256 nonce_,
        uint256[] memory signerIndexes
    ) internal returns (bytes memory) {
        return _packedSignaturesForDigestByIndexes(
            _transactionDigest(walletAddress, to, value, data, nonce_), signerIndexes
        );
    }

    function _packedSignaturesForBatch(bytes memory transactions, uint256 nonce_, uint256 signerCount)
        internal
        returns (bytes memory)
    {
        return _packedSignaturesForBatchAtWallet(address(wallet), transactions, nonce_, signerCount);
    }

    function _packedSignaturesForBatchByIndexes(
        bytes memory transactions,
        uint256 nonce_,
        uint256[] memory signerIndexes
    ) internal returns (bytes memory) {
        return _packedSignaturesForBatchByIndexesAtWallet(address(wallet), transactions, nonce_, signerIndexes);
    }

    function _packedSignaturesForBatchAtWallet(
        address walletAddress,
        bytes memory transactions,
        uint256 nonce_,
        uint256 signerCount
    ) internal returns (bytes memory) {
        return _packedSignaturesForDigest(_batchDigest(walletAddress, transactions, nonce_), signerCount);
    }

    function _packedSignaturesForBatchByIndexesAtWallet(
        address walletAddress,
        bytes memory transactions,
        uint256 nonce_,
        uint256[] memory signerIndexes
    ) internal returns (bytes memory) {
        return _packedSignaturesForDigestByIndexes(_batchDigest(walletAddress, transactions, nonce_), signerIndexes);
    }

    function _packedCurrentThresholdSignaturesForTransaction(
        IMultisigWallet wallet_,
        address to,
        uint256 value,
        bytes memory data
    ) internal returns (bytes memory) {
        return _packedCurrentThresholdSignaturesForTransactionAtWallet(address(wallet_), to, value, data);
    }

    function _packedCurrentThresholdSignaturesForTransactionAtWallet(
        address walletAddress,
        address to,
        uint256 value,
        bytes memory data
    ) internal returns (bytes memory) {
        return _packedSignaturesForTransactionByIndexesAtWallet(
            walletAddress,
            to,
            value,
            data,
            IMultisigWallet(walletAddress).nonce(),
            _currentThresholdSignerIndexes(walletAddress)
        );
    }

    function _packedCurrentThresholdSignaturesForBatch(IMultisigWallet wallet_, bytes memory transactions)
        internal
        returns (bytes memory)
    {
        return _packedCurrentThresholdSignaturesForBatchAtWallet(address(wallet_), transactions);
    }

    function _packedCurrentThresholdSignaturesForBatchAtWallet(address walletAddress, bytes memory transactions)
        internal
        returns (bytes memory)
    {
        return _packedSignaturesForBatchByIndexesAtWallet(
            walletAddress,
            transactions,
            IMultisigWallet(walletAddress).nonce(),
            _currentThresholdSignerIndexes(walletAddress)
        );
    }

    function _executeSelfTransaction(IMultisigWallet wallet_, bytes memory data) internal {
        bytes memory signatures = _packedCurrentThresholdSignaturesForTransaction(wallet_, address(wallet_), 0, data);
        wallet_.executeTransaction(address(wallet_), 0, data, signatures);
    }

    function _executeSelfBatch(IMultisigWallet wallet_, bytes memory transactions) internal {
        bytes memory signatures = _packedCurrentThresholdSignaturesForBatch(wallet_, transactions);
        wallet_.executeBatch(transactions, signatures);
    }

    function _packedSignaturesForDigest(bytes32 digest, uint256 signerCount)
        internal
        returns (bytes memory signatures)
    {
        uint256[] memory sortedIndexes = _sortedOwnerIndexes(signerCount);
        return _packedSignaturesForDigestByIndexes(digest, sortedIndexes);
    }

    function _packedSignaturesForDigestByIndexes(bytes32 digest, uint256[] memory signerIndexes)
        internal
        returns (bytes memory signatures)
    {
        uint256[] memory sortedIndexes = _sortedIndexesByAddress(signerIndexes);
        signatures = new bytes(sortedIndexes.length * 65);

        for (uint256 i = 0; i < sortedIndexes.length; i++) {
            (uint8 v, bytes32 r, bytes32 s) = VM.sign(actorKeys[sortedIndexes[i]], digest);
            uint256 offset = 32 + (i * 65);
            assembly {
                mstore(add(signatures, offset), r)
                mstore(add(signatures, add(offset, 0x20)), s)
                mstore8(add(signatures, add(offset, 0x40)), v)
            }
        }
    }

    function _sortedOwnerIndexes(uint256 signerCount) internal view returns (uint256[] memory indexes) {
        indexes = new uint256[](signerCount);
        for (uint256 i = 0; i < signerCount; i++) {
            indexes[i] = i;
        }

        return _sortedIndexesByAddress(indexes);
    }

    function _sortedIndexesByAddress(uint256[] memory indexes) internal view returns (uint256[] memory) {
        uint256 length = indexes.length;

        for (uint256 i = 0; i < length; i++) {
            for (uint256 j = i + 1; j < length; j++) {
                if (actorAddresses[indexes[j]] < actorAddresses[indexes[i]]) {
                    uint256 current = indexes[i];
                    indexes[i] = indexes[j];
                    indexes[j] = current;
                }
            }
        }

        return indexes;
    }

    function _encodeBatchEntry(address to, uint256 value, bytes memory data) internal pure returns (bytes memory) {
        return bytes.concat(bytes20(to), bytes32(value), bytes32(data.length), data);
    }

    function _currentThresholdSignerIndexes(address walletAddress)
        internal
        view
        returns (uint256[] memory signerIndexes)
    {
        address[] memory owners = IMultisigWallet(walletAddress).getOwners();
        uint256[] memory ownerIndexes = new uint256[](owners.length);

        for (uint256 i = 0; i < owners.length; i++) {
            ownerIndexes[i] = _actorIndex(owners[i]);
        }

        ownerIndexes = _sortedIndexesByAddress(ownerIndexes);
        uint256 signerCount = IMultisigWallet(walletAddress).threshold();
        signerIndexes = new uint256[](signerCount);
        for (uint256 i = 0; i < signerCount; i++) {
            signerIndexes[i] = ownerIndexes[i];
        }
    }

    function _actorIndex(address actor) internal view returns (uint256) {
        for (uint256 i = 0; i < actorAddresses.length; i++) {
            if (actorAddresses[i] == actor) {
                return i;
            }
        }

        revert("unknown actor");
    }
}
