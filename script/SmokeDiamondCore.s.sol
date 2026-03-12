// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {IERC173} from "../src/interfaces/IERC173.sol";
import {DiamondCoreScriptBase} from "./common/DiamondCoreScriptBase.sol";

/// @title SmokeDiamondCoreScript
/// @notice Anvil-backed smoke flow that validates a deployed local diamond core artifact.
contract SmokeDiamondCoreScript is DiamondCoreScriptBase {
    /// @notice Runs deterministic post-bootstrap smoke checks against the local deployment artifact.
    /// @dev Requires `PRIVATE_KEY` and `NEXT_OWNER_PRIVATE_KEY` to be set in the environment.
    /// @return diamondAddress The validated diamond address.
    function run() external returns (address diamondAddress) {
        uint256 ownerPrivateKey = VM.envUint("PRIVATE_KEY");
        uint256 nextOwnerPrivateKey = VM.envUint("NEXT_OWNER_PRIVATE_KEY");
        address owner = VM.addr(ownerPrivateKey);
        address nextOwner = VM.addr(nextOwnerPrivateKey);
        address cutFacetAddress;
        address loupeFacetAddress;

        require(nextOwner != owner, "smoke next owner matches owner");

        (diamondAddress, cutFacetAddress, loupeFacetAddress) = _loadDeploymentArtifact();

        _validateBootstrap(diamondAddress, owner, cutFacetAddress, loupeFacetAddress);
        _exerciseOwnershipTransfer(diamondAddress, ownerPrivateKey, nextOwner);
        _validatePostTransfer(diamondAddress, nextOwner, cutFacetAddress, loupeFacetAddress);
    }

    function _loadDeploymentArtifact()
        internal
        view
        returns (address diamondAddress, address cutFacet, address loupeFacet)
    {
        string memory json = VM.readFile(deploymentArtifactPath());
        diamondAddress = VM.parseJsonAddress(json, ".diamond");
        cutFacet = VM.parseJsonAddress(json, ".diamondCutFacet");
        loupeFacet = VM.parseJsonAddress(json, ".diamondLoupeFacet");

        require(diamondAddress != address(0), "smoke diamond missing");
        require(cutFacet != address(0), "smoke cut facet missing");
        require(loupeFacet != address(0), "smoke loupe facet missing");
    }

    function _validateBootstrap(
        address diamondAddress,
        address owner,
        address cutFacetAddress,
        address loupeFacetAddress
    ) internal view {
        IERC173 ownership = IERC173(diamondAddress);
        IDiamondLoupe loupe = IDiamondLoupe(diamondAddress);

        require(ownership.owner() == owner, "smoke bootstrap owner mismatch");
        require(
            loupe.facetAddress(DiamondCutFacet.diamondCut.selector) == cutFacetAddress,
            "smoke diamondCut selector mismatch"
        );
        require(
            loupe.facetAddress(DiamondLoupeFacet.owner.selector) == loupeFacetAddress, "smoke owner selector mismatch"
        );

        address[] memory facetAddresses = loupe.facetAddresses();
        require(facetAddresses.length == 2, "smoke facet address count mismatch");
        require(facetAddresses[0] == cutFacetAddress, "smoke cut facet address mismatch");
        require(facetAddresses[1] == loupeFacetAddress, "smoke loupe facet address mismatch");

        bytes4[] memory cutSelectors = loupe.facetFunctionSelectors(cutFacetAddress);
        require(cutSelectors.length == 1, "smoke cut selector count mismatch");
        require(cutSelectors[0] == DiamondCutFacet.diamondCut.selector, "smoke cut selector value mismatch");

        bytes4[] memory loupeSelectors = loupe.facetFunctionSelectors(loupeFacetAddress);
        require(loupeSelectors.length == 6, "smoke loupe selector count mismatch");

        IDiamondLoupe.Facet[] memory snapshot = loupe.facets();
        require(snapshot.length == 2, "smoke facets snapshot count mismatch");
        require(snapshot[0].facetAddress == cutFacetAddress, "smoke snapshot cut facet mismatch");
        require(snapshot[1].facetAddress == loupeFacetAddress, "smoke snapshot loupe facet mismatch");
    }

    function _exerciseOwnershipTransfer(address diamondAddress, uint256 ownerPrivateKey, address nextOwner) internal {
        VM.startBroadcast(ownerPrivateKey);
        IERC173(diamondAddress).transferOwnership(nextOwner);
        VM.stopBroadcast();
    }

    function _validatePostTransfer(
        address diamondAddress,
        address nextOwner,
        address cutFacetAddress,
        address loupeFacetAddress
    ) internal view {
        IERC173 ownership = IERC173(diamondAddress);
        IDiamondLoupe loupe = IDiamondLoupe(diamondAddress);

        require(ownership.owner() == nextOwner, "smoke post-transfer owner mismatch");
        require(
            loupe.facetAddress(DiamondCutFacet.diamondCut.selector) == cutFacetAddress,
            "smoke post-transfer cut selector mismatch"
        );
        require(
            loupe.facetAddress(DiamondLoupeFacet.transferOwnership.selector) == loupeFacetAddress,
            "smoke post-transfer ownership routing mismatch"
        );
    }
}
