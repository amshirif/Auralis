// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "../interfaces/IERC165.sol";
import {IERC1271} from "../interfaces/IERC1271.sol";
import {IMultisigWallet} from "../interfaces/IMultisigWallet.sol";

/// @title MultisigWallet
/// @notice Standalone multisig wallet foundation with initializer-based owner/threshold state.
contract MultisigWallet is IERC165, IERC1271, IMultisigWallet {
    bytes4 internal constant ERC1271_MAGIC_VALUE = 0x1626ba7e;
    bytes4 internal constant ERC1271_INVALID_SIGNATURE = 0xffffffff;
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant TRANSACTION_TYPEHASH =
        keccak256("WalletTransaction(address to,uint256 value,bytes32 dataHash,uint256 nonce)");
    bytes32 internal constant NAME_HASH = keccak256("Auralis Multisig Wallet");
    bytes32 internal constant VERSION_HASH = keccak256("1");
    uint256 internal constant SECP256K1N_DIV_2 = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    bool internal _initialized;
    uint256 internal _nonce;
    uint256 internal _threshold;
    address internal _multiSendCallOnly;
    address[] internal _owners;
    mapping(address owner => uint256 indexPlusOne) internal _ownerIndexPlusOne;

    constructor() {
        _nonce = 0;
        _initialized = true;
    }

    function initialize(address[] calldata owners, uint256 threshold_, address multiSendCallOnly_) external {
        if (_initialized) {
            revert MultisigWalletAlreadyInitialized();
        }
        if (multiSendCallOnly_ == address(0)) {
            revert MultisigWalletZeroMultiSend();
        }

        _initialized = true;
        _nonce = 0;
        _setOwners(owners, threshold_);
        _multiSendCallOnly = multiSendCallOnly_;

        emit WalletInitialized(_owners, _threshold, _multiSendCallOnly);
    }

    receive() external payable {}

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC1271).interfaceId
            || interfaceId == type(IMultisigWallet).interfaceId;
    }

    function getTransactionHash(address to, uint256 value, bytes calldata data, uint256 nonce_)
        external
        view
        returns (bytes32)
    {
        return _getTransactionHash(to, value, data, nonce_);
    }

    function executeTransaction(address to, uint256 value, bytes calldata data, bytes calldata signatures) external {
        uint256 currentNonce = _nonce;
        bytes32 digest = _getTransactionHash(to, value, data, currentNonce);

        _validateSignatures(digest, signatures);
        _nonce = currentNonce + 1;

        (bool success, bytes memory returndata) = to.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(returndata, 0x20), mload(returndata))
            }
        }

        emit TransactionExecuted(digest, currentNonce, to, value);
    }

    function isValidSignature(bytes32 digest, bytes calldata signatures)
        external
        view
        override(IERC1271, IMultisigWallet)
        returns (bytes4)
    {
        if (_hasValidSignatures(digest, signatures)) {
            return ERC1271_MAGIC_VALUE;
        }
        return ERC1271_INVALID_SIGNATURE;
    }

    function nonce() external view returns (uint256) {
        return _nonce;
    }

    function threshold() external view returns (uint256) {
        return _threshold;
    }

    function ownerCount() external view returns (uint256) {
        return _owners.length;
    }

    function multiSendCallOnly() external view returns (address) {
        return _multiSendCallOnly;
    }

    function isOwner(address account) external view returns (bool) {
        return _ownerIndexPlusOne[account] != 0;
    }

    function getOwners() external view returns (address[] memory) {
        return _owners;
    }

    function _setOwners(address[] calldata owners, uint256 threshold_) internal {
        uint256 ownerCount_ = owners.length;
        _requireValidThreshold(threshold_, ownerCount_);

        for (uint256 i = 0; i < ownerCount_; i++) {
            address owner = owners[i];
            if (owner == address(0)) {
                revert MultisigWalletZeroOwner();
            }
            if (_ownerIndexPlusOne[owner] != 0) {
                revert MultisigWalletDuplicateOwner(owner);
            }

            _ownerIndexPlusOne[owner] = i + 1;
            _owners.push(owner);
        }

        _threshold = threshold_;
    }

    function _requireValidThreshold(uint256 threshold_, uint256 ownerCount_) internal pure {
        if (threshold_ == 0 || threshold_ > ownerCount_) {
            revert MultisigWalletInvalidThreshold(threshold_, ownerCount_);
        }
    }

    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, address(this)));
    }

    function _getTransactionHash(address to, uint256 value, bytes calldata data, uint256 nonce_)
        internal
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(abi.encode(TRANSACTION_TYPEHASH, to, value, keccak256(data), nonce_));
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
    }

    function _hasValidSignatures(bytes32 digest, bytes calldata signatures) internal view returns (bool) {
        uint256 signatureCount = _threshold;
        if (signatures.length != signatureCount * 65) {
            return false;
        }

        address previousSigner;
        for (uint256 i = 0; i < signatureCount; i++) {
            (bytes32 r, bytes32 s, uint8 v) = _signatureAt(signatures, i);
            address signer = _recoverSigner(digest, v, r, s);
            if (_ownerIndexPlusOne[signer] == 0 || signer <= previousSigner) {
                return false;
            }
            previousSigner = signer;
        }

        return true;
    }

    function _validateSignatures(bytes32 digest, bytes calldata signatures) internal view {
        uint256 requiredLength = _threshold * 65;
        if (signatures.length != requiredLength) {
            revert MultisigWalletInvalidSignaturesLength(signatures.length, requiredLength);
        }

        address previousSigner;
        for (uint256 i = 0; i < _threshold; i++) {
            (bytes32 r, bytes32 s, uint8 v) = _signatureAt(signatures, i);
            address signer = _recoverSigner(digest, v, r, s);

            if (_ownerIndexPlusOne[signer] == 0) {
                revert MultisigWalletInvalidSigner(signer);
            }
            if (signer <= previousSigner) {
                revert MultisigWalletSignersNotStrictlyOrdered(previousSigner, signer);
            }

            previousSigner = signer;
        }
    }

    function _signatureAt(bytes calldata signatures, uint256 index)
        internal
        pure
        returns (bytes32 r, bytes32 s, uint8 v)
    {
        assembly {
            let offset := add(signatures.offset, mul(index, 65))
            r := calldataload(offset)
            s := calldataload(add(offset, 0x20))
            v := byte(0, calldataload(add(offset, 0x40)))
        }
    }

    function _recoverSigner(bytes32 digest, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        if (v != 27 && v != 28) {
            return address(0);
        }
        if (uint256(s) > SECP256K1N_DIV_2) {
            return address(0);
        }
        return ecrecover(digest, v, r, s);
    }
}
