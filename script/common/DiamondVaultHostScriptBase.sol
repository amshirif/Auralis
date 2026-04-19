// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Diamond} from "../../src/diamond/Diamond.sol";
import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../../src/interfaces/IDiamondLoupe.sol";
import {IERC173} from "../../src/interfaces/IERC173.sol";
import {DiamondCoreScriptBase} from "./DiamondCoreScriptBase.sol";

/// @title DiamondVaultHostScriptBase
/// @notice Shared deployment helpers for the reference hosted vault diamond.
abstract contract DiamondVaultHostScriptBase is DiamondCoreScriptBase {
    /// @notice Parsed addresses from a hosted vault deployment artifact.
    struct VaultHostDeploymentArtifact {
        address diamond;
        address diamondCutFacet;
        address diamondLoupeFacet;
        address vaultCoreFacet;
        address vaultAsyncDepositFacet;
        address vaultNativeFacet;
        address vaultControlsFacet;
        address vaultIntegrationFacet;
        address vaultAsset;
        address oracleFeed;
        address oracleAdapter;
        address strategy;
        address owner;
        uint256 chainId;
        uint256 strategyDebt;
        uint256 liveStrategyAssets;
        bool strategyEmergencyExit;
        string assetMode;
        string vaultName;
        string vaultSymbol;
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
            functionSelectors: _loupeSelectors()
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

        require(ownership.owner() == owner, "vault host owner mismatch");
        require(
            loupe.facetAddress(DiamondCutFacet.diamondCut.selector) == cutFacetAddress,
            "vault host cut selector mismatch"
        );
        require(
            loupe.facetAddress(DiamondLoupeFacet.facets.selector) == loupeFacetAddress,
            "vault host loupe selector mismatch"
        );
    }

    function _writeVaultDeploymentArtifact(
        string memory objectKey,
        string memory outputRelativePath,
        VaultHostDeploymentArtifact memory artifact
    ) internal {
        string memory json = VM.serializeString(objectKey, "network", "local-anvil");
        json = VM.serializeUint(objectKey, "chainId", block.chainid);
        json = VM.serializeAddress(objectKey, "owner", artifact.owner);
        json = VM.serializeAddress(objectKey, "diamond", artifact.diamond);
        json = VM.serializeAddress(objectKey, "diamondCutFacet", artifact.diamondCutFacet);
        json = VM.serializeAddress(objectKey, "diamondLoupeFacet", artifact.diamondLoupeFacet);
        json = VM.serializeAddress(objectKey, "vaultCoreFacet", artifact.vaultCoreFacet);
        json = VM.serializeAddress(objectKey, "vaultAsyncDepositFacet", artifact.vaultAsyncDepositFacet);
        json = VM.serializeAddress(objectKey, "vaultNativeFacet", artifact.vaultNativeFacet);
        json = VM.serializeAddress(objectKey, "vaultControlsFacet", artifact.vaultControlsFacet);
        json = VM.serializeAddress(objectKey, "vaultIntegrationFacet", artifact.vaultIntegrationFacet);
        json = VM.serializeAddress(objectKey, "vaultAsset", artifact.vaultAsset);
        json = VM.serializeAddress(objectKey, "oracleFeed", artifact.oracleFeed);
        json = VM.serializeAddress(objectKey, "oracleAdapter", artifact.oracleAdapter);
        json = VM.serializeAddress(objectKey, "strategy", artifact.strategy);
        json = VM.serializeUint(objectKey, "strategyDebt", artifact.strategyDebt);
        json = VM.serializeUint(objectKey, "liveStrategyAssets", artifact.liveStrategyAssets);
        json = VM.serializeBool(objectKey, "strategyEmergencyExit", artifact.strategyEmergencyExit);
        json = VM.serializeString(objectKey, "assetMode", artifact.assetMode);
        json = VM.serializeString(objectKey, "vaultName", artifact.vaultName);
        json = VM.serializeString(objectKey, "vaultSymbol", artifact.vaultSymbol);
        VM.writeJson(json, string.concat(VM.projectRoot(), outputRelativePath));
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

    function _containsAddress(address[] memory addresses, address expected) internal pure returns (bool) {
        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == expected) {
                return true;
            }
        }

        return false;
    }
}
