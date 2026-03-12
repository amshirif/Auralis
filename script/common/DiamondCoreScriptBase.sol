// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Vm} from "./Vm.sol";

/// @title DiamondCoreScriptBase
/// @notice Shared Foundry script helpers for local diamond core deployment and smoke flows.
abstract contract DiamondCoreScriptBase {
    /// @dev Foundry cheatcode address.
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev Deployment artifact root object.
    string internal constant DEPLOYMENT_OBJECT = "diamondCore";
    /// @dev Relative output path for the local diamond core deployment artifact.
    string internal constant OUTPUT_RELATIVE_PATH = "/deployments/diamond-core.local.json";

    /// @notice Returns the absolute path to the local deployment artifact.
    function deploymentArtifactPath() internal view returns (string memory) {
        return string.concat(VM.projectRoot(), OUTPUT_RELATIVE_PATH);
    }
}
