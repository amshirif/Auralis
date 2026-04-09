// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC165} from "../../src/interfaces/IERC165.sol";
import {IMultisigWallet} from "../../src/interfaces/IMultisigWallet.sol";
import {LibClone} from "../../src/libraries/LibClone.sol";
import {MultisigWallet} from "../../src/wallet/MultisigWallet.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

abstract contract MultisigWalletFixture is TestBase {
    uint256 internal constant OWNER_KEY_A = 0xA11CE;
    uint256 internal constant OWNER_KEY_B = 0xB0B;
    uint256 internal constant OWNER_KEY_C = 0xCAFE;
    uint256 internal constant OWNER_KEY_D = 0xD00D;

    bytes32 internal constant DEFAULT_SALT = keccak256("auralis.multisig.default-salt");
    address internal constant DEFAULT_MULTI_SEND = address(0xBEEF);

    MultisigWallet internal implementation;
    IMultisigWallet internal wallet;

    address[] internal actorAddresses;

    function setUp() public virtual {
        implementation = new MultisigWallet();

        actorAddresses = new address[](4);
        uint256[4] memory keys = [OWNER_KEY_A, OWNER_KEY_B, OWNER_KEY_C, OWNER_KEY_D];
        for (uint256 i = 0; i < keys.length; i++) {
            actorAddresses[i] = VM.addr(keys[i]);
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
    }
}
