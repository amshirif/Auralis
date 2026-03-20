// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Diamond} from "../../src/diamond/Diamond.sol";
import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../../src/interfaces/IDiamondLoupe.sol";
import {IERC173} from "../../src/interfaces/IERC173.sol";
import {LibTokenFacetDeploymentSelectors} from "../../src/token/libraries/LibTokenFacetDeploymentSelectors.sol";
import {DiamondCoreScriptBase} from "./DiamondCoreScriptBase.sol";

/// @title DiamondTokenHostScriptBase
/// @notice Shared deployment helpers for reference token-hosted diamonds.
abstract contract DiamondTokenHostScriptBase is DiamondCoreScriptBase {
    /// @notice Parsed addresses from a token host deployment artifact.
    struct TokenHostDeploymentArtifact {
        address diamond;
        address diamondCutFacet;
        address diamondLoupeFacet;
        address tokenFacet;
        address owner;
        uint256 chainId;
        string tokenStandard;
    }

    function _deployDiamondCore(address owner)
        internal
        returns (address diamondAddress, address cutFacetAddress, address loupeFacetAddress)
    {
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        Diamond diamond = new Diamond(owner, address(cutFacet));
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();

        IDiamondCut.FacetCut[] memory initialCut = new IDiamondCut.FacetCut[](1);
        initialCut[0] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibTokenFacetDeploymentSelectors.loupeSelectors()
        });
        IDiamondCut(address(diamond)).diamondCut(initialCut, address(0), "");

        diamondAddress = address(diamond);
        cutFacetAddress = address(cutFacet);
        loupeFacetAddress = address(loupeFacet);
    }

    function _validateDiamondCore(
        address diamondAddress,
        address owner,
        address cutFacetAddress,
        address loupeFacetAddress
    ) internal view {
        IERC173 ownership = IERC173(diamondAddress);
        IDiamondLoupe loupe = IDiamondLoupe(diamondAddress);

        require(ownership.owner() == owner, "token host owner mismatch");
        require(
            loupe.facetAddress(DiamondCutFacet.diamondCut.selector) == cutFacetAddress,
            "token host cut selector mismatch"
        );
        require(
            loupe.facetAddress(DiamondLoupeFacet.facets.selector) == loupeFacetAddress,
            "token host loupe selector mismatch"
        );
    }

    function _writeTokenDeploymentArtifact(
        string memory objectKey,
        string memory outputRelativePath,
        string memory tokenStandard,
        address owner,
        address diamondAddress,
        address cutFacetAddress,
        address loupeFacetAddress,
        address tokenFacetAddress
    ) internal {
        string memory json = VM.serializeString(objectKey, "network", "local-anvil");
        json = VM.serializeUint(objectKey, "chainId", block.chainid);
        json = VM.serializeString(objectKey, "tokenStandard", tokenStandard);
        json = VM.serializeAddress(objectKey, "owner", owner);
        json = VM.serializeAddress(objectKey, "diamond", diamondAddress);
        json = VM.serializeAddress(objectKey, "diamondCutFacet", cutFacetAddress);
        json = VM.serializeAddress(objectKey, "diamondLoupeFacet", loupeFacetAddress);
        json = VM.serializeAddress(objectKey, "tokenFacet", tokenFacetAddress);
        VM.writeJson(json, string.concat(VM.projectRoot(), outputRelativePath));
    }

    function _containsAddress(address[] memory addresses, address expected) internal pure returns (bool) {
        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == expected) {
                return true;
            }
        }

        return false;
    }

    function _containsSelector(bytes4[] memory selectors, bytes4 selector) internal pure returns (bool) {
        for (uint256 i = 0; i < selectors.length; i++) {
            if (selectors[i] == selector) {
                return true;
            }
        }

        return false;
    }
}
