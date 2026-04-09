// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "../interfaces/IERC165.sol";
import {IMultisigWallet} from "../interfaces/IMultisigWallet.sol";

/// @title MultisigWallet
/// @notice Standalone multisig wallet foundation with initializer-based owner/threshold state.
contract MultisigWallet is IERC165, IMultisigWallet {
    bool internal _initialized;
    uint256 internal _nonce;
    uint256 internal _threshold;
    address internal _multiSendCallOnly;
    address[] internal _owners;
    mapping(address owner => uint256 indexPlusOne) internal _ownerIndexPlusOne;

    constructor() {
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
        _setOwners(owners, threshold_);
        _multiSendCallOnly = multiSendCallOnly_;

        emit WalletInitialized(_owners, _threshold, _multiSendCallOnly);
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IMultisigWallet).interfaceId;
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
}
