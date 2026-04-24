// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title LibClone
/// @notice Minimal proxy deployment helpers for deterministic wallet clones.
library LibClone {
    /// @notice Reverts when CREATE2 clone deployment returns the zero address.
    error CloneCreate2Failed();

    /// @notice Deploys an ERC-1167 minimal proxy clone with CREATE2.
    /// @param implementation Logic contract address copied into the minimal proxy init code.
    /// @param salt CREATE2 salt.
    /// @return instance Deployed clone address.
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        bytes memory initCode = _minimalProxyInitCode(implementation);
        assembly {
            instance := create2(0, add(initCode, 0x20), mload(initCode), salt)
        }

        if (instance == address(0)) {
            revert CloneCreate2Failed();
        }
    }

    /// @notice Predicts the CREATE2 address for a deterministic minimal proxy clone.
    /// @param implementation Logic contract address copied into the minimal proxy init code.
    /// @param salt CREATE2 salt.
    /// @param deployer Address that will deploy the clone.
    /// @return predicted Predicted clone address.
    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        // forge-lint: disable-next-line(asm-keccak256) -- CREATE2 address derivation is kept in canonical high-level form.
        bytes32 bytecodeHash = keccak256(_minimalProxyInitCode(implementation));
        predicted = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, bytecodeHash)))));
    }

    function _minimalProxyInitCode(address implementation) private pure returns (bytes memory) {
        return abi.encodePacked(
            hex"3d602d80600a3d3981f3",
            hex"363d3d373d3d3d363d73",
            bytes20(implementation),
            hex"5af43d82803e903d91602b57fd5bf3"
        );
    }
}
