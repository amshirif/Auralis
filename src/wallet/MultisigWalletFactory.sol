// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IMultisigWallet} from "../interfaces/IMultisigWallet.sol";
import {IMultisigWalletFactory} from "../interfaces/IMultisigWalletFactory.sol";
import {LibClone} from "../libraries/LibClone.sol";

/// @title MultisigWalletFactory
/// @notice Deterministic clone deployment for standalone multisig wallets.
contract MultisigWalletFactory is IMultisigWalletFactory {
    // forge-lint: disable-next-line(screaming-snake-case-immutable) -- public immutable preserves the factory getter selector.
    address public immutable implementation;

    /// @notice Initializes the factory with the multisig implementation to clone.
    /// @param implementation_ Master wallet implementation address.
    constructor(address implementation_) {
        if (implementation_ == address(0)) {
            revert MultisigWalletFactoryZeroImplementation();
        }

        implementation = implementation_;
    }

    /// @inheritdoc IMultisigWalletFactory
    function deployWallet(bytes32 salt, address[] calldata owners, uint256 threshold_, address multiSendCallOnly_)
        external
        returns (address wallet)
    {
        wallet = LibClone.cloneDeterministic(implementation, salt);
        IMultisigWallet(wallet).initialize(owners, threshold_, multiSendCallOnly_);

        emit WalletDeployed(wallet, implementation, salt);
    }

    /// @inheritdoc IMultisigWalletFactory
    function predictWalletAddress(bytes32 salt) external view returns (address predicted) {
        return LibClone.predictDeterministicAddress(implementation, salt, address(this));
    }
}
