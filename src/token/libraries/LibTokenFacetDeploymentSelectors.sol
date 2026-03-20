// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../../interfaces/IAccessControl.sol";
import {IERC165} from "../../interfaces/IERC165.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {IERC20Metadata} from "../../interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "../../interfaces/IERC20Permit.sol";
import {IERC20TokenBase} from "../../interfaces/IERC20TokenBase.sol";
import {IERC20TokenFacet} from "../../interfaces/IERC20TokenFacet.sol";
import {IERC721} from "../../interfaces/IERC721.sol";
import {IERC721Metadata} from "../../interfaces/IERC721Metadata.sol";
import {IERC721TokenBase} from "../../interfaces/IERC721TokenBase.sol";
import {IERC721TokenFacet} from "../../interfaces/IERC721TokenFacet.sol";
import {IPausable} from "../../interfaces/IPausable.sol";
import {DiamondLoupeFacet} from "../../diamond/facets/DiamondLoupeFacet.sol";
import {DiamondCutFacet} from "../../diamond/facets/DiamondCutFacet.sol";

/// @title LibTokenFacetDeploymentSelectors
/// @notice Canonical selector sets for reference token-hosted diamond deployments.
library LibTokenFacetDeploymentSelectors {
    /// @notice Returns the selector set used to install the loupe facet.
    /// @return selectors Loupe + ownership selectors.
    function loupeSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](6);
        selectors[0] = DiamondLoupeFacet.facets.selector;
        selectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        selectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        selectors[3] = DiamondLoupeFacet.facetAddress.selector;
        selectors[4] = DiamondLoupeFacet.owner.selector;
        selectors[5] = DiamondLoupeFacet.transferOwnership.selector;
    }

    /// @notice Returns the selector set used to install the ERC20 host facet.
    /// @return selectors ERC20 + shared control selectors.
    function erc20HostSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](30);
        selectors[0] = IERC20TokenFacet.initializeErc20.selector;
        selectors[1] = IERC20Metadata.name.selector;
        selectors[2] = IERC20Metadata.symbol.selector;
        selectors[3] = IERC20Metadata.decimals.selector;
        selectors[4] = IERC20.totalSupply.selector;
        selectors[5] = IERC20.balanceOf.selector;
        selectors[6] = IERC20.allowance.selector;
        selectors[7] = IERC20.transfer.selector;
        selectors[8] = IERC20.approve.selector;
        selectors[9] = IERC20.transferFrom.selector;
        selectors[10] = IERC20TokenFacet.mint.selector;
        selectors[11] = IERC20TokenFacet.burn.selector;
        selectors[12] = IERC20TokenBase.isErc20Initialized.selector;
        selectors[13] = IAccessControl.DEFAULT_ADMIN_ROLE.selector;
        selectors[14] = IPausable.PAUSER_ROLE.selector;
        selectors[15] = IERC20TokenFacet.TOKEN_ADMIN_ROLE.selector;
        selectors[16] = IERC20TokenFacet.ERC20_MINTER_ROLE.selector;
        selectors[17] = IERC20TokenFacet.ERC20_BURNER_ROLE.selector;
        selectors[18] = IERC20TokenFacet.ERC20_TRANSFER_SCOPE.selector;
        selectors[19] = IERC20TokenFacet.ERC20_APPROVAL_SCOPE.selector;
        selectors[20] = IAccessControl.hasRole.selector;
        selectors[21] = IAccessControl.getRoleAdmin.selector;
        selectors[22] = IAccessControl.grantRole.selector;
        selectors[23] = IPausable.pauseScope.selector;
        selectors[24] = IPausable.unpauseScope.selector;
        selectors[25] = IPausable.scopePaused.selector;
        selectors[26] = IERC20Permit.permit.selector;
        selectors[27] = IERC20Permit.nonces.selector;
        selectors[28] = IERC20Permit.DOMAIN_SEPARATOR.selector;
        selectors[29] = IERC165.supportsInterface.selector;
    }

    /// @notice Returns the selector set used to install the ERC721 host facet.
    /// @return selectors ERC721 + shared control selectors.
    function erc721HostSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](35);
        selectors[0] = IERC721TokenFacet.initializeErc721.selector;
        selectors[1] = IERC721.balanceOf.selector;
        selectors[2] = IERC721.ownerOf.selector;
        selectors[3] = IERC721.approve.selector;
        selectors[4] = IERC721.getApproved.selector;
        selectors[5] = IERC721.setApprovalForAll.selector;
        selectors[6] = IERC721.isApprovedForAll.selector;
        selectors[7] = IERC721.transferFrom.selector;
        selectors[8] = bytes4(keccak256("safeTransferFrom(address,address,uint256)"));
        selectors[9] = bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"));
        selectors[10] = IERC721Metadata.tokenURI.selector;
        selectors[11] = IERC721Metadata.name.selector;
        selectors[12] = IERC721Metadata.symbol.selector;
        selectors[13] = IERC721TokenFacet.totalSupply.selector;
        selectors[14] = IERC721TokenBase.isErc721Initialized.selector;
        selectors[15] = IERC721TokenFacet.mint.selector;
        selectors[16] = IERC721TokenFacet.safeMint.selector;
        selectors[17] = IERC721TokenFacet.burn.selector;
        selectors[18] = IERC721TokenFacet.setBaseURI.selector;
        selectors[19] = IERC721TokenFacet.setTokenURI.selector;
        selectors[20] = IAccessControl.DEFAULT_ADMIN_ROLE.selector;
        selectors[21] = IPausable.PAUSER_ROLE.selector;
        selectors[22] = IERC721TokenFacet.TOKEN_ADMIN_ROLE.selector;
        selectors[23] = IERC721TokenFacet.ERC721_MINTER_ROLE.selector;
        selectors[24] = IERC721TokenFacet.ERC721_BURNER_ROLE.selector;
        selectors[25] = IERC721TokenFacet.ERC721_METADATA_ROLE.selector;
        selectors[26] = IERC721TokenFacet.ERC721_TRANSFER_SCOPE.selector;
        selectors[27] = IERC721TokenFacet.ERC721_APPROVAL_SCOPE.selector;
        selectors[28] = IAccessControl.hasRole.selector;
        selectors[29] = IAccessControl.getRoleAdmin.selector;
        selectors[30] = IAccessControl.grantRole.selector;
        selectors[31] = IPausable.pauseScope.selector;
        selectors[32] = IPausable.unpauseScope.selector;
        selectors[33] = IPausable.scopePaused.selector;
        selectors[34] = IERC165.supportsInterface.selector;
    }
}
