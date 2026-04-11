// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title LibClone
/// @notice Minimal proxy deployment helpers for deterministic wallet clones.
library LibClone {
    error CloneCreate2Failed();

    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        bytes memory initCode = _minimalProxyInitCode(implementation);
        assembly {
            instance := create2(0, add(initCode, 0x20), mload(initCode), salt)
        }

        if (instance == address(0)) {
            revert CloneCreate2Failed();
        }
    }

    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
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
