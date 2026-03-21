// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAccessControl} from "../src/interfaces/IAccessControl.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IERC20Metadata} from "../src/interfaces/IERC20Metadata.sol";
import {IERC721} from "../src/interfaces/IERC721.sol";
import {IERC721Metadata} from "../src/interfaces/IERC721Metadata.sol";
import {IERC20TokenFacet} from "../src/interfaces/IERC20TokenFacet.sol";
import {IERC721TokenFacet} from "../src/interfaces/IERC721TokenFacet.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {
    DiamondTokenHostHardeningFixture,
    IFacetVersionMarker
} from "./helpers/DiamondTokenHostHardeningTestHarness.sol";

contract DiamondTokenHostHardeningTest is DiamondTokenHostHardeningFixture {
    function testErc20HostReplaceRemoveAndReAddPreservesState() public {
        _installErc20HostFacet(address(erc20Facet));
        _erc20InitDiamond();
        _seedErc20HostState();

        bytes32 tokenAdminRole = IERC20TokenFacet(address(diamond)).TOKEN_ADMIN_ROLE();
        bytes32 approvalScope = IERC20TokenFacet(address(diamond)).ERC20_APPROVAL_SCOPE();

        _replaceErc20HostFacet(address(erc20Replacement));
        _addErc20ReplacementMarker(address(erc20Replacement));

        IDiamondLoupe loupe = IDiamondLoupe(address(diamond));
        assertTrue(loupe.facetAddresses().length == 3, "erc20 replace facet count mismatch");
        assertTrue(
            loupe.facetFunctionSelectors(address(erc20Replacement)).length == 31,
            "erc20 replacement selector count mismatch"
        );
        assertTrue(loupe.facetFunctionSelectors(address(erc20Facet)).length == 0, "erc20 old facet should be empty");
        assertTrue(IFacetVersionMarker(address(diamond)).facetVersion() == 2, "erc20 marker routing mismatch");

        _assertErc20State(address(erc20Replacement));

        _removeErc20HostFacetWithMarker();

        assertTrue(loupe.facetAddresses().length == 2, "erc20 removal should leave core facets only");
        _assertMissingSelector(abi.encodeCall(IERC20Metadata.name, ()), "erc20 name should be missing after removal");
        _assertMissingSelector(
            abi.encodeCall(IAccessControl.hasRole, (tokenAdminRole, eve)),
            "erc20 hasRole should be missing after removal"
        );
        _assertMissingSelector(
            abi.encodeCall(IPausable.scopePaused, (approvalScope)), "erc20 scopePaused should be missing after removal"
        );
        _assertMissingSelector(
            abi.encodeWithSelector(IFacetVersionMarker.facetVersion.selector),
            "erc20 marker should be missing after removal"
        );

        _reAddErc20HostFacetWithMarker(address(erc20Replacement));

        assertTrue(loupe.facetAddresses().length == 3, "erc20 re-add facet count mismatch");
        assertTrue(IFacetVersionMarker(address(diamond)).facetVersion() == 2, "erc20 marker should survive re-add");
        _assertErc20State(address(erc20Replacement));
    }

    function testErc721HostReplaceRemoveAndReAddPreservesState() public {
        _installErc721HostFacet(address(erc721Facet));
        _erc721InitDiamond();
        _seedErc721HostState();

        bytes32 metadataRole = IERC721TokenFacet(address(diamond)).ERC721_METADATA_ROLE();
        bytes32 approvalScope = IERC721TokenFacet(address(diamond)).ERC721_APPROVAL_SCOPE();

        _replaceErc721HostFacet(address(erc721Replacement));
        _addErc721ReplacementMarker(address(erc721Replacement));

        IDiamondLoupe loupe = IDiamondLoupe(address(diamond));
        assertTrue(loupe.facetAddresses().length == 3, "erc721 replace facet count mismatch");
        assertTrue(
            loupe.facetFunctionSelectors(address(erc721Replacement)).length == 36,
            "erc721 replacement selector count mismatch"
        );
        assertTrue(loupe.facetFunctionSelectors(address(erc721Facet)).length == 0, "erc721 old facet should be empty");
        assertTrue(IFacetVersionMarker(address(diamond)).facetVersion() == 2, "erc721 marker routing mismatch");

        _assertErc721State(address(erc721Replacement));

        _removeErc721HostFacetWithMarker();

        assertTrue(loupe.facetAddresses().length == 2, "erc721 removal should leave core facets only");
        _assertMissingSelector(abi.encodeCall(IERC721Metadata.name, ()), "erc721 name should be missing after removal");
        _assertMissingSelector(abi.encodeCall(IERC721.ownerOf, (1)), "erc721 ownerOf should be missing after removal");
        _assertMissingSelector(
            abi.encodeCall(IAccessControl.hasRole, (metadataRole, eve)),
            "erc721 hasRole should be missing after removal"
        );
        _assertMissingSelector(
            abi.encodeCall(IPausable.scopePaused, (approvalScope)), "erc721 scopePaused should be missing after removal"
        );
        _assertMissingSelector(
            abi.encodeWithSelector(IFacetVersionMarker.facetVersion.selector),
            "erc721 marker should be missing after removal"
        );

        _reAddErc721HostFacetWithMarker(address(erc721Replacement));

        assertTrue(loupe.facetAddresses().length == 3, "erc721 re-add facet count mismatch");
        assertTrue(IFacetVersionMarker(address(diamond)).facetVersion() == 2, "erc721 marker should survive re-add");
        _assertErc721State(address(erc721Replacement));
    }

    function _assertErc20State(address expectedFacetOwner) internal view {
        IERC20TokenFacet token = IERC20TokenFacet(address(diamond));
        IDiamondLoupe loupe = IDiamondLoupe(address(diamond));

        assertTrue(keccak256(bytes(token.name())) == keccak256(bytes("Facet Token")), "erc20 name mismatch");
        assertTrue(keccak256(bytes(token.symbol())) == keccak256(bytes("FTKN")), "erc20 symbol mismatch");
        assertTrue(token.decimals() == 18, "erc20 decimals mismatch");
        assertTrue(token.totalSupply() == 150, "erc20 total supply mismatch");
        assertTrue(token.balanceOf(bob) == 100, "erc20 bob balance mismatch");
        assertTrue(token.balanceOf(carol) == 50, "erc20 carol balance mismatch");
        assertTrue(token.allowance(bob, eve) == 25, "erc20 approval allowance mismatch");
        assertTrue(token.allowance(bob, dave) == 40, "erc20 permit allowance mismatch");
        assertTrue(token.nonces(bob) == 1, "erc20 nonce mismatch");
        assertTrue(token.hasRole(token.TOKEN_ADMIN_ROLE(), eve), "erc20 role state mismatch");
        assertTrue(token.scopePaused(token.ERC20_APPROVAL_SCOPE()), "erc20 approval scope pause mismatch");
        assertTrue(!token.scopePaused(token.ERC20_TRANSFER_SCOPE()), "erc20 transfer scope should remain live");
        assertTrue(token.supportsInterface(type(IERC20TokenFacet).interfaceId), "erc20 interface support mismatch");
        assertTrue(
            loupe.facetAddress(IERC20Metadata.name.selector) == expectedFacetOwner, "erc20 name selector owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IERC165.supportsInterface.selector) == expectedFacetOwner,
            "erc20 supportsInterface owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IAccessControl.hasRole.selector) == expectedFacetOwner, "erc20 hasRole owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IPausable.pauseScope.selector) == expectedFacetOwner, "erc20 pauseScope owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IERC20TokenFacet.TOKEN_ADMIN_ROLE.selector) == expectedFacetOwner,
            "erc20 token admin selector owner mismatch"
        );
    }

    function _assertErc721State(address expectedFacetOwner) internal view {
        IERC721TokenFacet token = IERC721TokenFacet(address(diamond));
        IDiamondLoupe loupe = IDiamondLoupe(address(diamond));

        assertTrue(keccak256(bytes(token.name())) == keccak256(bytes("Facet NFT")), "erc721 name mismatch");
        assertTrue(keccak256(bytes(token.symbol())) == keccak256(bytes("FNFT")), "erc721 symbol mismatch");
        assertTrue(token.totalSupply() == 2, "erc721 total supply mismatch");
        assertTrue(token.ownerOf(1) == bob, "erc721 token 1 owner mismatch");
        assertTrue(token.ownerOf(2) == carol, "erc721 token 2 owner mismatch");
        assertTrue(token.balanceOf(bob) == 1, "erc721 bob balance mismatch");
        assertTrue(token.balanceOf(carol) == 1, "erc721 carol balance mismatch");
        assertTrue(token.getApproved(1) == eve, "erc721 approval mismatch");
        assertTrue(token.isApprovedForAll(bob, dave), "erc721 operator approval mismatch");
        assertTrue(
            keccak256(bytes(token.tokenURI(1))) == keccak256(bytes("ipfs://facet/custom-1")),
            "erc721 explicit uri mismatch"
        );
        assertTrue(
            keccak256(bytes(token.tokenURI(2))) == keccak256(bytes("ipfs://facet/2")), "erc721 base uri mismatch"
        );
        assertTrue(token.hasRole(token.ERC721_METADATA_ROLE(), eve), "erc721 metadata role mismatch");
        assertTrue(token.scopePaused(token.ERC721_APPROVAL_SCOPE()), "erc721 approval scope pause mismatch");
        assertTrue(token.scopePaused(token.ERC721_TRANSFER_SCOPE()), "erc721 transfer scope pause mismatch");
        assertTrue(token.supportsInterface(type(IERC721TokenFacet).interfaceId), "erc721 interface support mismatch");
        assertTrue(
            loupe.facetAddress(IERC721Metadata.name.selector) == expectedFacetOwner,
            "erc721 name selector owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IERC165.supportsInterface.selector) == expectedFacetOwner,
            "erc721 supportsInterface owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IAccessControl.hasRole.selector) == expectedFacetOwner, "erc721 hasRole owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IPausable.pauseScope.selector) == expectedFacetOwner, "erc721 pauseScope owner mismatch"
        );
        assertTrue(
            loupe.facetAddress(IERC721TokenFacet.ERC721_METADATA_ROLE.selector) == expectedFacetOwner,
            "erc721 metadata selector owner mismatch"
        );
    }
}
