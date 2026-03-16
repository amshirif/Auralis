// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title Vm
/// @notice Minimal Foundry cheatcode interface shared by local deployment and smoke scripts.
interface Vm {
    function addr(uint256 privateKey) external returns (address);
    function envUint(string calldata name) external returns (uint256);
    function parseJsonAddress(string calldata json, string calldata key) external pure returns (address);
    function projectRoot() external view returns (string memory);
    function readFile(string calldata path) external view returns (string memory);
    function serializeAddress(string calldata objectKey, string calldata valueKey, address value)
        external
        returns (string memory);
    function serializeString(string calldata objectKey, string calldata valueKey, string calldata value)
        external
        returns (string memory);
    function serializeUint(string calldata objectKey, string calldata valueKey, uint256 value)
        external
        returns (string memory);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
    function writeJson(string calldata json, string calldata path) external;
}
