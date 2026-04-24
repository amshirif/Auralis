// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title LibECDSA
/// @notice Shared ECDSA signature validation constants.
library LibECDSA {
    /// @notice Lower-half secp256k1 scalar bound used to reject malleable signatures.
    uint256 internal constant SECP256K1N_DIV_2 = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;
}
