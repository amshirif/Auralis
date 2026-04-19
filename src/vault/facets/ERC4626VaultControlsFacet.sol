// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../../interfaces/IAccessControl.sol";
import {IAccessControlTime} from "../../interfaces/IAccessControlTime.sol";
import {IERC165} from "../../interfaces/IERC165.sol";
import {IERC7540Deposit} from "../../interfaces/IERC7540Deposit.sol";
import {IERC7540Operators} from "../../interfaces/IERC7540Operators.sol";
import {IERC7540Redeem} from "../../interfaces/IERC7540Redeem.sol";
import {IERC7535VaultFacet} from "../../interfaces/IERC7535VaultFacet.sol";
import {IERC4626VaultControls} from "../../interfaces/IERC4626VaultControls.sol";
import {IERC4626VaultControlsFacet} from "../../interfaces/IERC4626VaultControlsFacet.sol";
import {IERC4626VaultFacet} from "../../interfaces/IERC4626VaultFacet.sol";
import {IERC4626VaultIntegrationFacet} from "../../interfaces/IERC4626VaultIntegrationFacet.sol";
import {IPausable} from "../../interfaces/IPausable.sol";
import {IReentrancyGuard} from "../../interfaces/IReentrancyGuard.sol";
import {LibDiamond} from "../../diamond/libraries/LibDiamond.sol";
import {ERC4626VaultControlSurface} from "../ERC4626VaultControlLogic.sol";
import {VaultFacetControl} from "../VaultFacetControl.sol";

/// @title ERC4626VaultControlsFacet
/// @notice Hosted control-plane facet for vault fee, limit, and governance operations.
contract ERC4626VaultControlsFacet is ERC4626VaultControlSurface {
    /// @notice Returns true if this contract implements `interfaceId`.
    /// @param interfaceId The interface identifier.
    /// @return True if the interface is supported.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(VaultFacetControl, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC4626VaultControls).interfaceId
            || interfaceId == type(IERC4626VaultControlsFacet).interfaceId
            || (interfaceId == type(IERC4626VaultFacet).interfaceId
                && LibDiamond.selectorExists(IERC4626VaultFacet.initializeVault.selector))
            || (interfaceId == type(IERC7540Operators).interfaceId
                && LibDiamond.selectorExists(IERC7540Operators.setOperator.selector))
            || (interfaceId == type(IERC7540Deposit).interfaceId
                && LibDiamond.selectorExists(IERC7540Deposit.requestDeposit.selector))
            || (interfaceId == type(IERC7540Redeem).interfaceId
                && LibDiamond.selectorExists(IERC7540Redeem.requestRedeem.selector))
            || (interfaceId == type(IERC7535VaultFacet).interfaceId
                && LibDiamond.selectorExists(IERC7535VaultFacet.depositNative.selector))
            || (interfaceId == type(IERC4626VaultIntegrationFacet).interfaceId
                && LibDiamond.selectorExists(IERC4626VaultIntegrationFacet.oracleAdapter.selector))
            || interfaceId == type(IAccessControl).interfaceId || interfaceId == type(IAccessControlTime).interfaceId
            || interfaceId == type(IPausable).interfaceId || interfaceId == type(IReentrancyGuard).interfaceId
            || VaultFacetControl.supportsInterface(interfaceId);
    }
}
