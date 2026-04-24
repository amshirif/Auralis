// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title AMMFixedPoint
/// @notice Minimal UQ112x112 fixed-point helpers for V2-style price accumulation.
library AMMFixedPoint {
    uint224 internal constant Q112 = uint224(1) << 112;

    /// @notice Encodes a UQ112x112 fixed-point value.
    /// @param value Raw fixed-point numerator scaled by `2**112`.
    // forge-lint: disable-next-line(pascal-case-struct) -- UQ112x112 is the canonical fixed-point type name.
    struct UQ112x112 {
        uint224 value;
    }

    /// @notice Encodes an integer as a UQ112x112 fixed-point value.
    /// @param value Integer value to encode.
    /// @return Encoded fixed-point value.
    function encode(uint112 value) internal pure returns (UQ112x112 memory) {
        return UQ112x112({value: uint224(value) * Q112});
    }

    /// @notice Divides a UQ112x112 value by an integer denominator.
    /// @param self Encoded fixed-point value.
    /// @param value Integer denominator.
    /// @return Encoded quotient.
    function uqdiv(UQ112x112 memory self, uint112 value) internal pure returns (UQ112x112 memory) {
        return UQ112x112({value: self.value / uint224(value)});
    }
}
