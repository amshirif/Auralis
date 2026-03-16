// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {IERC173} from "../src/interfaces/IERC173.sol";
import {DiamondCoreScriptBase} from "./common/DiamondCoreScriptBase.sol";
import {
    DiamondUpgradeCollisionFacet,
    DiamondUpgradeFailureFacet,
    DiamondUpgradeFacetV1,
    DiamondUpgradeFacetV2,
    DiamondUpgradeInitMock,
    DiamondUpgradeStateFacet
} from "./helpers/DiamondUpgradeRehearsalFixtures.sol";

/// @title RehearseDiamondUpgradeScript
/// @notice Rehearses a realistic local diamond upgrade and validates the post-cut state.
contract RehearseDiamondUpgradeScript is DiamondCoreScriptBase {
    string internal constant REHEARSAL_OBJECT = "diamondCoreUpgradeRehearsal";
    string internal constant REHEARSAL_OUTPUT_RELATIVE_PATH = "/deployments/diamond-core.upgrade-rehearsal.local.json";

    /// @notice Runs a local upgrade rehearsal against the deployed diamond core artifact.
    /// @dev Requires `PRIVATE_KEY` to point at the current diamond owner.
    /// @return diamondAddress The upgraded diamond address.
    function run() external returns (address diamondAddress) {
        uint256 ownerPrivateKey = VM.envUint("PRIVATE_KEY");
        address owner = VM.addr(ownerPrivateKey);
        DeploymentArtifact memory deployment = loadDeploymentArtifact();

        diamondAddress = deployment.diamond;

        _validateBaseDeployment(diamondAddress, owner, deployment.diamondCutFacet, deployment.diamondLoupeFacet);

        VM.startBroadcast(ownerPrivateKey);

        DiamondUpgradeFacetV1 baselineFacet = new DiamondUpgradeFacetV1();
        DiamondUpgradeFacetV2 upgradeFacet = new DiamondUpgradeFacetV2();
        DiamondUpgradeStateFacet stateFacet = new DiamondUpgradeStateFacet();
        DiamondUpgradeInitMock initMock = new DiamondUpgradeInitMock();
        DiamondUpgradeCollisionFacet collisionFacet = new DiamondUpgradeCollisionFacet();
        DiamondUpgradeFailureFacet failureFacet = new DiamondUpgradeFailureFacet();

        IDiamondCut(address(diamondAddress)).diamondCut(_baselineCut(address(baselineFacet)), address(0), "");
        IDiamondCut(address(diamondAddress))
            .diamondCut(
                _upgradeCut(address(upgradeFacet), address(stateFacet)),
                address(initMock),
                abi.encodeCall(DiamondUpgradeInitMock.initializeValue, (42))
            );

        VM.stopBroadcast();

        _validatePostCutChecklist(
            diamondAddress,
            owner,
            deployment.diamondCutFacet,
            deployment.diamondLoupeFacet,
            address(baselineFacet),
            address(upgradeFacet),
            address(stateFacet)
        );

        _writeRehearsalArtifact(
            owner,
            diamondAddress,
            deployment.diamondCutFacet,
            deployment.diamondLoupeFacet,
            address(baselineFacet),
            address(upgradeFacet),
            address(stateFacet),
            address(initMock),
            address(collisionFacet),
            address(failureFacet)
        );
    }

    function _validateBaseDeployment(
        address diamondAddress,
        address owner,
        address cutFacetAddress,
        address loupeFacetAddress
    ) internal view {
        IERC173 ownership = IERC173(diamondAddress);
        IDiamondLoupe loupe = IDiamondLoupe(diamondAddress);

        require(ownership.owner() == owner, "upgrade base owner mismatch");
        require(
            loupe.facetAddress(DiamondCutFacet.diamondCut.selector) == cutFacetAddress,
            "upgrade base cut selector mismatch"
        );
        require(
            loupe.facetAddress(DiamondLoupeFacet.facets.selector) == loupeFacetAddress,
            "upgrade base loupe selector mismatch"
        );
        require(loupe.facetAddresses().length == 2, "upgrade base facet count mismatch");
    }

    function _validatePostCutChecklist(
        address diamondAddress,
        address owner,
        address cutFacetAddress,
        address loupeFacetAddress,
        address baselineFacetAddress,
        address upgradeFacetAddress,
        address stateFacetAddress
    ) internal view {
        IERC173 ownership = IERC173(diamondAddress);
        IDiamondLoupe loupe = IDiamondLoupe(diamondAddress);

        require(ownership.owner() == owner, "upgrade owner continuity mismatch");

        address[] memory facetAddresses = loupe.facetAddresses();
        require(facetAddresses.length == 4, "upgrade post-cut facet count mismatch");
        require(_containsAddress(facetAddresses, cutFacetAddress), "upgrade missing cut facet");
        require(_containsAddress(facetAddresses, loupeFacetAddress), "upgrade missing loupe facet");
        require(_containsAddress(facetAddresses, upgradeFacetAddress), "upgrade missing replacement facet");
        require(_containsAddress(facetAddresses, stateFacetAddress), "upgrade missing state facet");

        bytes4[] memory upgradeSelectors = loupe.facetFunctionSelectors(upgradeFacetAddress);
        require(upgradeSelectors.length == 3, "upgrade replacement selector count mismatch");
        require(_containsSelector(upgradeSelectors, DiamondUpgradeFacetV2.alpha.selector), "upgrade missing alpha");
        require(_containsSelector(upgradeSelectors, DiamondUpgradeFacetV2.epsilon.selector), "upgrade missing epsilon");
        require(_containsSelector(upgradeSelectors, DiamondUpgradeFacetV2.caller.selector), "upgrade missing caller");
        require(
            loupe.facetFunctionSelectors(baselineFacetAddress).length == 0, "upgrade baseline selectors not cleared"
        );

        bytes4[] memory stateSelectors = loupe.facetFunctionSelectors(stateFacetAddress);
        require(stateSelectors.length == 1, "upgrade state selector count mismatch");
        require(stateSelectors[0] == DiamondUpgradeStateFacet.readValue.selector, "upgrade readValue selector mismatch");

        require(
            loupe.facetAddress(DiamondCutFacet.diamondCut.selector) == cutFacetAddress,
            "upgrade cut selector ownership mismatch"
        );
        require(
            loupe.facetAddress(DiamondLoupeFacet.facets.selector) == loupeFacetAddress,
            "upgrade loupe selector ownership mismatch"
        );
        require(
            loupe.facetAddress(DiamondUpgradeFacetV2.alpha.selector) == upgradeFacetAddress,
            "upgrade alpha selector ownership mismatch"
        );
        require(
            loupe.facetAddress(DiamondUpgradeFacetV2.caller.selector) == upgradeFacetAddress,
            "upgrade caller selector ownership mismatch"
        );
        require(
            loupe.facetAddress(DiamondUpgradeFacetV2.epsilon.selector) == upgradeFacetAddress,
            "upgrade epsilon selector ownership mismatch"
        );
        require(
            loupe.facetAddress(DiamondUpgradeStateFacet.readValue.selector) == stateFacetAddress,
            "upgrade readValue selector ownership mismatch"
        );
        require(
            loupe.facetAddress(DiamondUpgradeFacetV1.beta.selector) == address(0),
            "upgrade removed beta selector still routed"
        );

        IDiamondLoupe.Facet[] memory snapshot = loupe.facets();
        require(snapshot.length == 4, "upgrade loupe snapshot count mismatch");

        _assertCallReturnsUint256(
            diamondAddress, abi.encodeCall(DiamondUpgradeFacetV2.alpha, ()), 11, "upgrade alpha call mismatch"
        );
        _assertCallReturnsUint256(
            diamondAddress, abi.encodeCall(DiamondUpgradeFacetV2.epsilon, ()), 5, "upgrade epsilon call mismatch"
        );
        _assertCallReturnsUint256(
            diamondAddress, abi.encodeCall(DiamondUpgradeStateFacet.readValue, ()), 42, "upgrade init value mismatch"
        );
    }

    function _baselineCut(address baselineFacetAddress) internal pure returns (IDiamondCut.FacetCut[] memory cut) {
        cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = DiamondUpgradeFacetV1.alpha.selector;
        selectors[1] = DiamondUpgradeFacetV1.beta.selector;
        selectors[2] = DiamondUpgradeFacetV1.caller.selector;

        cut[0] = IDiamondCut.FacetCut({
            facetAddress: baselineFacetAddress, action: IDiamondCut.FacetCutAction.Add, functionSelectors: selectors
        });
    }

    function _upgradeCut(address upgradeFacetAddress, address stateFacetAddress)
        internal
        pure
        returns (IDiamondCut.FacetCut[] memory cut)
    {
        cut = new IDiamondCut.FacetCut[](4);

        bytes4[] memory replaceSelectors = new bytes4[](2);
        replaceSelectors[0] = DiamondUpgradeFacetV2.alpha.selector;
        replaceSelectors[1] = DiamondUpgradeFacetV2.caller.selector;
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: upgradeFacetAddress,
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: replaceSelectors
        });

        bytes4[] memory removeSelectors = new bytes4[](1);
        removeSelectors[0] = DiamondUpgradeFacetV1.beta.selector;
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(0), action: IDiamondCut.FacetCutAction.Remove, functionSelectors: removeSelectors
        });

        bytes4[] memory addUpgradeSelectors = new bytes4[](1);
        addUpgradeSelectors[0] = DiamondUpgradeFacetV2.epsilon.selector;
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: upgradeFacetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: addUpgradeSelectors
        });

        bytes4[] memory addStateSelectors = new bytes4[](1);
        addStateSelectors[0] = DiamondUpgradeStateFacet.readValue.selector;
        cut[3] = IDiamondCut.FacetCut({
            facetAddress: stateFacetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: addStateSelectors
        });
    }

    function _writeRehearsalArtifact(
        address owner,
        address diamondAddress,
        address cutFacetAddress,
        address loupeFacetAddress,
        address baselineFacetAddress,
        address upgradeFacetAddress,
        address stateFacetAddress,
        address initMockAddress,
        address collisionFacetAddress,
        address failureFacetAddress
    ) internal {
        string memory json = VM.serializeString(REHEARSAL_OBJECT, "network", "local-anvil");
        json = VM.serializeUint(REHEARSAL_OBJECT, "chainId", block.chainid);
        json = VM.serializeAddress(REHEARSAL_OBJECT, "owner", owner);
        json = VM.serializeAddress(REHEARSAL_OBJECT, "diamond", diamondAddress);
        json = VM.serializeAddress(REHEARSAL_OBJECT, "diamondCutFacet", cutFacetAddress);
        json = VM.serializeAddress(REHEARSAL_OBJECT, "diamondLoupeFacet", loupeFacetAddress);
        json = VM.serializeAddress(REHEARSAL_OBJECT, "baselineFacet", baselineFacetAddress);
        json = VM.serializeAddress(REHEARSAL_OBJECT, "upgradeFacet", upgradeFacetAddress);
        json = VM.serializeAddress(REHEARSAL_OBJECT, "stateFacet", stateFacetAddress);
        json = VM.serializeAddress(REHEARSAL_OBJECT, "initMock", initMockAddress);
        json = VM.serializeAddress(REHEARSAL_OBJECT, "collisionFacet", collisionFacetAddress);
        json = VM.serializeAddress(REHEARSAL_OBJECT, "failureFacet", failureFacetAddress);
        VM.writeJson(json, string.concat(VM.projectRoot(), REHEARSAL_OUTPUT_RELATIVE_PATH));
    }

    function _assertCallReturnsUint256(
        address diamondAddress,
        bytes memory callData,
        uint256 expectedValue,
        string memory message
    ) internal view {
        (bool success, bytes memory returndata) = diamondAddress.staticcall(callData);
        require(success, message);
        require(abi.decode(returndata, (uint256)) == expectedValue, message);
    }

    function _containsAddress(address[] memory values, address expected) internal pure returns (bool) {
        uint256 length = values.length;
        for (uint256 i = 0; i < length; i++) {
            if (values[i] == expected) {
                return true;
            }
        }

        return false;
    }

    function _containsSelector(bytes4[] memory values, bytes4 expected) internal pure returns (bool) {
        uint256 length = values.length;
        for (uint256 i = 0; i < length; i++) {
            if (values[i] == expected) {
                return true;
            }
        }

        return false;
    }
}
