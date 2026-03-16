// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title DiamondUpgradeFacetV1
/// @notice Baseline facet used by the local upgrade rehearsal flow.
contract DiamondUpgradeFacetV1 {
    function alpha() external pure returns (uint256) {
        return 1;
    }

    function beta() external pure returns (uint256) {
        return 2;
    }

    function caller() external view returns (address) {
        return msg.sender;
    }
}

/// @title DiamondUpgradeFacetV2
/// @notice Replacement facet used by the local upgrade rehearsal flow.
contract DiamondUpgradeFacetV2 {
    function alpha() external pure returns (uint256) {
        return 11;
    }

    function epsilon() external pure returns (uint256) {
        return 5;
    }

    function caller() external view returns (address) {
        return msg.sender;
    }
}

/// @title DiamondUpgradeCollisionFacet
/// @notice Facet that intentionally collides on `alpha()` for failed-cut rehearsal coverage.
contract DiamondUpgradeCollisionFacet {
    function gamma() external pure returns (uint256) {
        return 3;
    }

    function alpha() external pure returns (uint256) {
        return 77;
    }
}

/// @title DiamondUpgradeFailureFacet
/// @notice Facet used to prove init failures do not leave partial routing state.
contract DiamondUpgradeFailureFacet {
    function zeta() external pure returns (uint256) {
        return 6;
    }
}

library LibDiamondUpgradeRehearsalStorage {
    bytes32 internal constant STORAGE_SLOT = keccak256("smart-contracts.script.diamond-upgrade-rehearsal.storage");

    struct Layout {
        uint256 value;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

/// @title DiamondUpgradeStateFacet
/// @notice Read surface for the storage value set during init rehearsal.
contract DiamondUpgradeStateFacet {
    function readValue() external view returns (uint256) {
        return LibDiamondUpgradeRehearsalStorage.layout().value;
    }
}

/// @title DiamondUpgradeInitMock
/// @notice Init delegatecall target for successful and failed upgrade rehearsal paths.
contract DiamondUpgradeInitMock {
    error InitFailure();

    function initializeValue(uint256 value_) external {
        LibDiamondUpgradeRehearsalStorage.layout().value = value_;
    }

    function revertInit() external pure {
        revert InitFailure();
    }
}
