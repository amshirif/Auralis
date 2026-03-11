// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IDiamondCut} from "../../interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../../interfaces/IDiamondLoupe.sol";
import {LibDiamondStorage} from "../storage/LibDiamondStorage.sol";

/// @title LibDiamond
/// @notice Shared diamond bookkeeping helpers for ownership, interfaces, and selector routing.
library LibDiamond {
    /// @notice Emitted when ownership changes.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Thrown when a zero owner is provided.
    error DiamondOwnerZeroAddress();
    /// @notice Thrown when `account` is not the current owner.
    error DiamondUnauthorized(address account, address owner);
    /// @notice Thrown when a zero facet address is provided.
    error DiamondFacetAddressZero();
    /// @notice Thrown when an invalid ERC-165 interface id is registered.
    error DiamondInvalidInterfaceId(bytes4 interfaceId);
    /// @notice Thrown when a selector already exists on another facet.
    error DiamondSelectorAlreadyExists(bytes4 selector, address existingFacet);
    /// @notice Thrown when a selector is not currently installed.
    error DiamondSelectorNotFound(bytes4 selector);
    /// @notice Thrown when replacing a selector with the same facet.
    error DiamondReplaceWithSameFacet(bytes4 selector, address facetAddress);
    /// @notice Thrown when a facet cut contains no selectors.
    error DiamondCutEmptySelectors();
    /// @notice Thrown when removing selectors with a nonzero facet address.
    error DiamondCutRemoveFacetAddressNotZero(address facetAddress);
    /// @notice Thrown when a facet or init target has no code.
    error DiamondTargetHasNoCode(address target);
    /// @notice Thrown when init calldata is provided without an init target.
    error DiamondCutInitTargetRequired();
    /// @notice Thrown when an init target is provided without calldata.
    error DiamondCutInitCalldataRequired();
    /// @notice Thrown when the init delegatecall fails.
    error DiamondCutInitFailed(address init, bytes reason);

    /// @notice Returns the current contract owner.
    /// @return owner_ The current contract owner.
    function contractOwner() internal view returns (address owner_) {
        return LibDiamondStorage.layout().contractOwner;
    }

    /// @notice Reverts when `target` has no runtime code.
    /// @param target The facet or init target to validate.
    function enforceHasContractCode(address target) internal view {
        _enforceTargetHasCode(target);
    }

    /// @notice Sets the current contract owner and emits the ERC-173 event.
    /// @param newOwner The new owner account.
    function setContractOwner(address newOwner) internal {
        if (newOwner == address(0)) {
            revert DiamondOwnerZeroAddress();
        }

        LibDiamondStorage.Layout storage diamondStorage = LibDiamondStorage.layout();
        address previousOwner = diamondStorage.contractOwner;
        diamondStorage.contractOwner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }

    /// @notice Reverts unless `msg.sender` is the current owner.
    function enforceIsContractOwner() internal view {
        address owner = contractOwner();
        if (msg.sender != owner) {
            revert DiamondUnauthorized(msg.sender, owner);
        }
    }

    /// @notice Returns whether the diamond supports `interfaceId`.
    /// @param interfaceId The interface identifier to inspect.
    /// @return True if the interface is marked as supported.
    function supportsInterface(bytes4 interfaceId) internal view returns (bool) {
        return LibDiamondStorage.layout().supportedInterfaces[interfaceId];
    }

    /// @notice Sets support for `interfaceId`.
    /// @param interfaceId The interface identifier to update.
    /// @param supported Whether the interface is supported.
    function setSupportedInterface(bytes4 interfaceId, bool supported) internal {
        if (interfaceId == 0xffffffff) {
            revert DiamondInvalidInterfaceId(interfaceId);
        }

        LibDiamondStorage.layout().supportedInterfaces[interfaceId] = supported;
    }

    /// @notice Returns the facet responsible for `selector`.
    /// @param selector The selector to inspect.
    /// @return facetAddress_ The owning facet address, or zero when unset.
    function facetAddress(bytes4 selector) internal view returns (address facetAddress_) {
        return LibDiamondStorage.layout().selectorData[selector].facetAddress;
    }

    /// @notice Returns all active facet addresses.
    /// @return facetAddresses_ Active facet addresses.
    function facetAddresses() internal view returns (address[] memory facetAddresses_) {
        return LibDiamondStorage.layout().facetAddresses;
    }

    /// @notice Returns all selectors owned by `facetAddress_`.
    /// @param facetAddress_ The facet address to inspect.
    /// @return selectors The facet selectors.
    function facetFunctionSelectors(address facetAddress_) internal view returns (bytes4[] memory selectors) {
        return LibDiamondStorage.layout().facetData[facetAddress_].selectors;
    }

    /// @notice Returns all facets and selectors for loupe queries.
    /// @return diamondFacets Active facets and their selectors.
    function facets() internal view returns (IDiamondLoupe.Facet[] memory diamondFacets) {
        LibDiamondStorage.Layout storage diamondStorage = LibDiamondStorage.layout();
        uint256 facetCount = diamondStorage.facetAddresses.length;
        diamondFacets = new IDiamondLoupe.Facet[](facetCount);

        for (uint256 i = 0; i < facetCount; i++) {
            address facetAddress_ = diamondStorage.facetAddresses[i];
            diamondFacets[i] = IDiamondLoupe.Facet({
                facetAddress: facetAddress_, functionSelectors: facetFunctionSelectors(facetAddress_)
            });
        }
    }

    /// @notice Returns true when `selector` is installed.
    /// @param selector The selector to inspect.
    /// @return True if the selector exists.
    function selectorExists(bytes4 selector) internal view returns (bool) {
        return facetAddress(selector) != address(0);
    }

    /// @notice Adds `selector` to `facetAddress_`.
    /// @param facetAddress_ The facet that will own the selector.
    /// @param selector The selector to add.
    function addSelector(address facetAddress_, bytes4 selector) internal {
        if (facetAddress_ == address(0)) {
            revert DiamondFacetAddressZero();
        }

        address existingFacet = facetAddress(selector);
        if (existingFacet != address(0)) {
            revert DiamondSelectorAlreadyExists(selector, existingFacet);
        }

        LibDiamondStorage.Layout storage diamondStorage = LibDiamondStorage.layout();
        _addFacetIfMissing(diamondStorage, facetAddress_);

        uint256 selectorPosition = diamondStorage.facetData[facetAddress_].selectors.length;
        diamondStorage.selectorData[selector] =
            LibDiamondStorage.SelectorData({facetAddress: facetAddress_, selectorPosition: uint96(selectorPosition)});
        diamondStorage.facetData[facetAddress_].selectors.push(selector);
    }

    /// @notice Replaces the current owner of `selector` with `facetAddress_`.
    /// @param facetAddress_ The new facet address.
    /// @param selector The selector to replace.
    function replaceSelector(address facetAddress_, bytes4 selector) internal {
        if (facetAddress_ == address(0)) {
            revert DiamondFacetAddressZero();
        }

        address existingFacet = facetAddress(selector);
        if (existingFacet == address(0)) {
            revert DiamondSelectorNotFound(selector);
        }
        if (existingFacet == facetAddress_) {
            revert DiamondReplaceWithSameFacet(selector, facetAddress_);
        }

        removeSelector(selector);
        addSelector(facetAddress_, selector);
    }

    /// @notice Removes `selector` from its current facet.
    /// @param selector The selector to remove.
    function removeSelector(bytes4 selector) internal {
        LibDiamondStorage.Layout storage diamondStorage = LibDiamondStorage.layout();
        LibDiamondStorage.SelectorData memory selectorData = diamondStorage.selectorData[selector];
        address facetAddress_ = selectorData.facetAddress;
        if (facetAddress_ == address(0)) {
            revert DiamondSelectorNotFound(selector);
        }

        bytes4[] storage selectors = diamondStorage.facetData[facetAddress_].selectors;
        uint256 selectorPosition = selectorData.selectorPosition;
        uint256 lastSelectorPosition = selectors.length - 1;

        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = selectors[lastSelectorPosition];
            selectors[selectorPosition] = lastSelector;
            diamondStorage.selectorData[lastSelector].selectorPosition = uint96(selectorPosition);
        }

        selectors.pop();
        delete diamondStorage.selectorData[selector];

        if (selectors.length == 0) {
            _removeFacetAddress(diamondStorage, facetAddress_);
        }
    }

    /// @notice Applies a full diamond cut and optional init delegatecall.
    /// @param diamondCut_ The selector mutations to apply.
    /// @param init The optional init target for post-cut initialization.
    /// @param initCalldata The optional init calldata.
    function diamondCut(IDiamondCut.FacetCut[] calldata diamondCut_, address init, bytes calldata initCalldata)
        internal
    {
        uint256 cutLength = diamondCut_.length;
        for (uint256 i = 0; i < cutLength; i++) {
            IDiamondCut.FacetCut calldata facetCut = diamondCut_[i];
            bytes4[] calldata selectors = facetCut.functionSelectors;
            uint256 selectorCount = selectors.length;
            if (selectorCount == 0) {
                revert DiamondCutEmptySelectors();
            }

            if (facetCut.action == IDiamondCut.FacetCutAction.Add) {
                _enforceTargetHasCode(facetCut.facetAddress);
                for (uint256 j = 0; j < selectorCount; j++) {
                    addSelector(facetCut.facetAddress, selectors[j]);
                }
                continue;
            }

            if (facetCut.action == IDiamondCut.FacetCutAction.Replace) {
                _enforceTargetHasCode(facetCut.facetAddress);
                for (uint256 j = 0; j < selectorCount; j++) {
                    replaceSelector(facetCut.facetAddress, selectors[j]);
                }
                continue;
            }

            if (facetCut.facetAddress != address(0)) {
                revert DiamondCutRemoveFacetAddressNotZero(facetCut.facetAddress);
            }
            for (uint256 j = 0; j < selectorCount; j++) {
                removeSelector(selectors[j]);
            }
        }

        initializeDiamondCut(init, initCalldata);
    }

    /// @notice Executes the optional init delegatecall after a cut.
    /// @param init The optional init target for post-cut initialization.
    /// @param initCalldata The optional init calldata.
    function initializeDiamondCut(address init, bytes calldata initCalldata) internal {
        if (init == address(0)) {
            if (initCalldata.length != 0) {
                revert DiamondCutInitTargetRequired();
            }
            return;
        }
        if (initCalldata.length == 0) {
            revert DiamondCutInitCalldataRequired();
        }

        _enforceTargetHasCode(init);

        (bool success, bytes memory reason) = init.delegatecall(initCalldata);
        if (!success) {
            revert DiamondCutInitFailed(init, reason);
        }
    }

    /// @dev Reverts when `target` has no runtime code.
    /// @param target The facet or init target to validate.
    function _enforceTargetHasCode(address target) private view {
        if (target.code.length == 0) {
            revert DiamondTargetHasNoCode(target);
        }
    }

    /// @dev Adds `facetAddress_` to the active facet list when missing.
    /// @param diamondStorage The diamond layout.
    /// @param facetAddress_ The facet address to add.
    function _addFacetIfMissing(LibDiamondStorage.Layout storage diamondStorage, address facetAddress_) private {
        if (diamondStorage.facetData[facetAddress_].selectors.length != 0) {
            return;
        }

        diamondStorage.facetData[facetAddress_].facetAddressPosition = diamondStorage.facetAddresses.length;
        diamondStorage.facetAddresses.push(facetAddress_);
    }

    /// @dev Removes `facetAddress_` from the active facet list.
    /// @param diamondStorage The diamond layout.
    /// @param facetAddress_ The facet address to remove.
    function _removeFacetAddress(LibDiamondStorage.Layout storage diamondStorage, address facetAddress_) private {
        uint256 facetAddressPosition = diamondStorage.facetData[facetAddress_].facetAddressPosition;
        uint256 lastFacetAddressPosition = diamondStorage.facetAddresses.length - 1;

        if (facetAddressPosition != lastFacetAddressPosition) {
            address lastFacetAddress = diamondStorage.facetAddresses[lastFacetAddressPosition];
            diamondStorage.facetAddresses[facetAddressPosition] = lastFacetAddress;
            diamondStorage.facetData[lastFacetAddress].facetAddressPosition = facetAddressPosition;
        }

        diamondStorage.facetAddresses.pop();
        delete diamondStorage.facetData[facetAddress_].facetAddressPosition;
    }
}
