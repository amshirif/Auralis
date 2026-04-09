// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "../../src/interfaces/IERC165.sol";
import {IERC1271} from "../../src/interfaces/IERC1271.sol";
import {IMultisigWallet} from "../../src/interfaces/IMultisigWallet.sol";
import {LibClone} from "../../src/libraries/LibClone.sol";
import {MultisigWallet} from "../../src/wallet/MultisigWallet.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

abstract contract MultisigWalletFixture is TestBase {
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant TRANSACTION_TYPEHASH =
        keccak256("WalletTransaction(address to,uint256 value,bytes32 dataHash,uint256 nonce)");
    bytes32 internal constant NAME_HASH = keccak256("Auralis Multisig Wallet");
    bytes32 internal constant VERSION_HASH = keccak256("1");
    bytes4 internal constant ERC1271_MAGIC_VALUE = 0x1626ba7e;
    bytes4 internal constant ERC1271_INVALID_SIGNATURE = 0xffffffff;
    uint256 internal constant OWNER_KEY_A = 0xA11CE;
    uint256 internal constant OWNER_KEY_B = 0xB0B;
    uint256 internal constant OWNER_KEY_C = 0xCAFE;
    uint256 internal constant OWNER_KEY_D = 0xD00D;

    bytes32 internal constant DEFAULT_SALT = keccak256("auralis.multisig.default-salt");
    address internal constant DEFAULT_MULTI_SEND = address(0xBEEF);

    MultisigWallet internal implementation;
    IMultisigWallet internal wallet;

    address[] internal actorAddresses;
    uint256[] internal actorKeys;

    function setUp() public virtual {
        implementation = new MultisigWallet();

        actorAddresses = new address[](4);
        actorKeys = new uint256[](4);
        actorKeys[0] = OWNER_KEY_A;
        actorKeys[1] = OWNER_KEY_B;
        actorKeys[2] = OWNER_KEY_C;
        actorKeys[3] = OWNER_KEY_D;

        for (uint256 i = 0; i < actorKeys.length; i++) {
            actorAddresses[i] = VM.addr(actorKeys[i]);
        }

        wallet = _deployInitializedWallet(DEFAULT_SALT, _initialOwners(), 2, DEFAULT_MULTI_SEND);
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

    function _packedSignaturesForTransaction(
        address to,
        uint256 value,
        bytes memory data,
        uint256 nonce_,
        uint256 signerCount
    ) internal returns (bytes memory) {
        return _packedSignaturesForDigest(_transactionDigest(address(wallet), to, value, data, nonce_), signerCount);
    }

    function _packedSignaturesForTransactionByIndexes(
        address to,
        uint256 value,
        bytes memory data,
        uint256 nonce_,
        uint256[] memory signerIndexes
    ) internal returns (bytes memory) {
        return _packedSignaturesForDigestByIndexes(
            _transactionDigest(address(wallet), to, value, data, nonce_), signerIndexes
        );
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
}
