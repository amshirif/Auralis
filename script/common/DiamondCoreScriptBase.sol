// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Vm} from "./Vm.sol";

/// @title DiamondCoreScriptBase
/// @notice Shared Foundry script helpers for local diamond core deployment and smoke flows.
abstract contract DiamondCoreScriptBase {
    /// @notice Parsed addresses from the local deployment artifact.
    struct DeploymentArtifact {
        address diamond;
        address diamondCutFacet;
        address diamondLoupeFacet;
    }

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

    /// @notice Loads the local deployment artifact and returns its canonical diamond addresses.
    function loadDeploymentArtifact() internal view returns (DeploymentArtifact memory deployment) {
        // forge-lint: disable-next-line(unsafe-cheatcode) -- local scripts intentionally read deployment artifacts.
        string memory json = VM.readFile(deploymentArtifactPath());

        deployment.diamond = VM.parseJsonAddress(json, ".diamond");
        deployment.diamondCutFacet = VM.parseJsonAddress(json, ".diamondCutFacet");
        deployment.diamondLoupeFacet = VM.parseJsonAddress(json, ".diamondLoupeFacet");

        require(deployment.diamond != address(0), "deployment artifact diamond missing");
        require(deployment.diamondCutFacet != address(0), "deployment artifact cut facet missing");
        require(deployment.diamondLoupeFacet != address(0), "deployment artifact loupe facet missing");
    }
}
