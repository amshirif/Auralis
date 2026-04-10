// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IMultisigWallet} from "../interfaces/IMultisigWallet.sol";
import {IMultisigWalletFactory} from "../interfaces/IMultisigWalletFactory.sol";
import {LibClone} from "../libraries/LibClone.sol";

/// @title MultisigWalletFactory
/// @notice Deterministic clone deployment for standalone multisig wallets.
contract MultisigWalletFactory is IMultisigWalletFactory {
    address public immutable implementation;

    constructor(address implementation_) {
        if (implementation_ == address(0)) {
            revert MultisigWalletFactoryZeroImplementation();
        }

        implementation = implementation_;
    }

    function deployWallet(bytes32 salt, address[] calldata owners, uint256 threshold_, address multiSendCallOnly_)
        external
        returns (address wallet)
    {
        wallet = LibClone.cloneDeterministic(implementation, salt);
        IMultisigWallet(wallet).initialize(owners, threshold_, multiSendCallOnly_);

        emit WalletDeployed(wallet, implementation, salt);
    }

    function predictWalletAddress(bytes32 salt) external view returns (address predicted) {
        return LibClone.predictDeterministicAddress(implementation, salt, address(this));
    }
}
