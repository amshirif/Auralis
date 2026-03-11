// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Diamond} from "../src/diamond/Diamond.sol";
import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {IERC173} from "../src/interfaces/IERC173.sol";

interface Vm {
    function addr(uint256 privateKey) external returns (address);
    function envUint(string calldata name) external returns (uint256);
    function projectRoot() external view returns (string memory);
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

/// @title DeployDiamondCoreScript
/// @notice Reference local deployment flow for a bootstrapped diamond core.
contract DeployDiamondCoreScript {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string internal constant DEPLOYMENT_OBJECT = "diamondCore";
    string internal constant OUTPUT_RELATIVE_PATH = "/deployments/diamond-core.local.json";

    /// @notice Deploys `Diamond`, `DiamondCutFacet`, and `DiamondLoupeFacet`, then bootstraps loupe selectors.
    /// @dev Requires `PRIVATE_KEY` to be set in the environment.
    /// @return diamondAddress The deployed diamond proxy.
    /// @return cutFacetAddress The deployed cut facet.
    /// @return loupeFacetAddress The deployed loupe facet.
    function run() external returns (address diamondAddress, address cutFacetAddress, address loupeFacetAddress) {
        uint256 deployerPrivateKey = VM.envUint("PRIVATE_KEY");
        address owner = VM.addr(deployerPrivateKey);

        VM.startBroadcast(deployerPrivateKey);

        DiamondCutFacet cutFacet = new DiamondCutFacet();
        Diamond diamond = new Diamond(owner, address(cutFacet));
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();

        IDiamondCut.FacetCut[] memory initialCut = new IDiamondCut.FacetCut[](1);
        initialCut[0] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _loupeSelectors()
        });
        IDiamondCut(address(diamond)).diamondCut(initialCut, address(0), "");

        VM.stopBroadcast();

        diamondAddress = address(diamond);
        cutFacetAddress = address(cutFacet);
        loupeFacetAddress = address(loupeFacet);

        _validateBootstrap(diamondAddress, owner, cutFacetAddress, loupeFacetAddress);
        _writeDeploymentArtifact(owner, diamondAddress, cutFacetAddress, loupeFacetAddress);
    }

    function _validateBootstrap(
        address diamondAddress,
        address owner,
        address cutFacetAddress,
        address loupeFacetAddress
    ) internal view {
        IERC173 ownership = IERC173(diamondAddress);
        IDiamondLoupe loupe = IDiamondLoupe(diamondAddress);

        require(ownership.owner() == owner, "diamond owner mismatch");
        require(
            loupe.facetAddress(DiamondCutFacet.diamondCut.selector) == cutFacetAddress,
            "diamondCut selector bootstrap mismatch"
        );
        require(
            loupe.facetAddress(DiamondLoupeFacet.facets.selector) == loupeFacetAddress,
            "loupe facets selector bootstrap mismatch"
        );
        require(loupe.facetFunctionSelectors(loupeFacetAddress).length == 6, "loupe selector count mismatch");
        require(loupe.facetAddresses().length == 2, "facet address count mismatch");
    }

    function _writeDeploymentArtifact(
        address owner,
        address diamondAddress,
        address cutFacetAddress,
        address loupeFacetAddress
    ) internal {
        string memory json = VM.serializeString(DEPLOYMENT_OBJECT, "network", "local-anvil");
        json = VM.serializeUint(DEPLOYMENT_OBJECT, "chainId", block.chainid);
        json = VM.serializeAddress(DEPLOYMENT_OBJECT, "owner", owner);
        json = VM.serializeAddress(DEPLOYMENT_OBJECT, "diamond", diamondAddress);
        json = VM.serializeAddress(DEPLOYMENT_OBJECT, "diamondCutFacet", cutFacetAddress);
        json = VM.serializeAddress(DEPLOYMENT_OBJECT, "diamondLoupeFacet", loupeFacetAddress);
        VM.writeJson(json, string.concat(VM.projectRoot(), OUTPUT_RELATIVE_PATH));
    }

    function _loupeSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](6);
        selectors[0] = DiamondLoupeFacet.facets.selector;
        selectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        selectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        selectors[3] = DiamondLoupeFacet.facetAddress.selector;
        selectors[4] = DiamondLoupeFacet.owner.selector;
        selectors[5] = DiamondLoupeFacet.transferOwnership.selector;
    }
}
