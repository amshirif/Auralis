// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {IERC20Metadata} from "../../src/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "../../src/interfaces/IERC20Permit.sol";
import {IERC20TokenFacet} from "../../src/interfaces/IERC20TokenFacet.sol";
import {IERC721TokenBase} from "../../src/interfaces/IERC721TokenBase.sol";
import {IERC721TokenFacet} from "../../src/interfaces/IERC721TokenFacet.sol";
import {ERC20TokenFacet} from "../../src/token/facets/ERC20TokenFacet.sol";
import {ERC721TokenFacet} from "../../src/token/facets/ERC721TokenFacet.sol";
import {LibTokenFacetDeploymentSelectors} from "../../src/token/libraries/LibTokenFacetDeploymentSelectors.sol";
import {DiamondProxyHarness} from "./DiamondTestHarness.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

interface IFacetVersionMarker {
    function facetVersion() external view returns (uint256);
}

contract ERC20TokenFacetReplacement is ERC20TokenFacet {
    function facetVersion() external pure returns (uint256) {
        return 2;
    }
}

contract ERC721TokenFacetReplacement is ERC721TokenFacet {
    function facetVersion() external pure returns (uint256) {
        return 2;
    }
}

abstract contract DiamondTokenHostHardeningFixture is TestBase {
    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    uint256 internal constant ADMIN_PK = uint256(keccak256("erc20-facet-admin"));
    uint256 internal constant BOB_PK = uint256(keccak256("erc20-facet-bob"));
    uint256 internal constant EVE_PK = uint256(keccak256("erc20-facet-eve"));
    uint256 internal constant CAROL_PK = uint256(keccak256("erc20-facet-carol"));
    uint256 internal constant DAVE_PK = uint256(keccak256("erc20-facet-dave"));

    address internal admin;
    address internal bob;
    address internal eve;
    address internal carol;
    address internal dave;

    DiamondCutFacet internal cutFacet;
    DiamondLoupeFacet internal loupeFacet;
    ERC20TokenFacet internal erc20Facet;
    ERC20TokenFacetReplacement internal erc20Replacement;
    ERC721TokenFacet internal erc721Facet;
    ERC721TokenFacetReplacement internal erc721Replacement;
    DiamondProxyHarness internal diamond;

    function setUp() public virtual {
        admin = VM.addr(ADMIN_PK);
        bob = VM.addr(BOB_PK);
        eve = VM.addr(EVE_PK);
        carol = VM.addr(CAROL_PK);
        dave = VM.addr(DAVE_PK);

        cutFacet = new DiamondCutFacet();
        loupeFacet = new DiamondLoupeFacet();
        erc20Facet = new ERC20TokenFacet();
        erc20Replacement = new ERC20TokenFacetReplacement();
        erc721Facet = new ERC721TokenFacet();
        erc721Replacement = new ERC721TokenFacetReplacement();
        diamond = new DiamondProxyHarness(admin, address(cutFacet));

        _installLoupeFacet();
    }

    function _installLoupeFacet() internal {
        _addFacet(address(loupeFacet), LibTokenFacetDeploymentSelectors.loupeSelectors());
    }

    function _installErc20HostFacet(address facetAddress_) internal {
        _addFacet(facetAddress_, LibTokenFacetDeploymentSelectors.erc20HostSelectors());
    }

    function _installErc721HostFacet(address facetAddress_) internal {
        _addFacet(facetAddress_, LibTokenFacetDeploymentSelectors.erc721HostSelectors());
    }

    function _replaceErc20HostFacet(address facetAddress_) internal {
        _replaceFacet(facetAddress_, LibTokenFacetDeploymentSelectors.erc20HostSelectors());
    }

    function _replaceErc721HostFacet(address facetAddress_) internal {
        _replaceFacet(facetAddress_, LibTokenFacetDeploymentSelectors.erc721HostSelectors());
    }

    function _addErc20ReplacementMarker(address facetAddress_) internal {
        _addFacet(facetAddress_, _markerSelectors());
    }

    function _addErc721ReplacementMarker(address facetAddress_) internal {
        _addFacet(facetAddress_, _markerSelectors());
    }

    function _removeErc20HostFacetWithMarker() internal {
        _removeSelectors(_concat(LibTokenFacetDeploymentSelectors.erc20HostSelectors(), _markerSelectors()));
    }

    function _removeErc721HostFacetWithMarker() internal {
        _removeSelectors(_concat(LibTokenFacetDeploymentSelectors.erc721HostSelectors(), _markerSelectors()));
    }

    function _reAddErc20HostFacetWithMarker(address facetAddress_) internal {
        _addFacet(facetAddress_, _concat(LibTokenFacetDeploymentSelectors.erc20HostSelectors(), _markerSelectors()));
    }

    function _reAddErc721HostFacetWithMarker(address facetAddress_) internal {
        _addFacet(facetAddress_, _concat(LibTokenFacetDeploymentSelectors.erc721HostSelectors(), _markerSelectors()));
    }

    function _erc20InitDiamond() internal {
        IERC20TokenFacet(address(diamond)).initializeErc20("Facet Token", "FTKN", 18, admin);
    }

    function _erc721InitDiamond() internal {
        IERC721TokenFacet(address(diamond)).initializeErc721("Facet NFT", "FNFT", "ipfs://facet/", admin);
    }

    function _seedErc20HostState() internal {
        IERC20TokenFacet token = IERC20TokenFacet(address(diamond));
        bytes32 tokenAdminRole = token.TOKEN_ADMIN_ROLE();
        bytes32 approvalScope = token.ERC20_APPROVAL_SCOPE();

        VM.prank(admin);
        token.mint(bob, 100);
        VM.prank(admin);
        token.mint(carol, 50);

        VM.prank(bob);
        token.approve(eve, 25);

        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(address(diamond), bob, dave, 40, token.nonces(bob), deadline);
        token.permit(bob, dave, 40, deadline, v, r, s);

        VM.prank(admin);
        token.grantRole(tokenAdminRole, eve);

        VM.prank(admin);
        token.pauseScope(approvalScope);
    }

    function _seedErc721HostState() internal {
        IERC721TokenFacet token = IERC721TokenFacet(address(diamond));
        bytes32 metadataRole = token.ERC721_METADATA_ROLE();
        bytes32 approvalScope = token.ERC721_APPROVAL_SCOPE();
        bytes32 transferScope = token.ERC721_TRANSFER_SCOPE();

        VM.prank(admin);
        token.mint(bob, 1);
        VM.prank(admin);
        token.mint(carol, 2);

        VM.prank(bob);
        token.approve(eve, 1);
        VM.prank(bob);
        token.setApprovalForAll(dave, true);

        VM.prank(admin);
        token.setTokenURI(1, "ipfs://facet/custom-1");

        VM.prank(admin);
        token.grantRole(metadataRole, eve);

        VM.prank(admin);
        token.pauseScope(approvalScope);
        VM.prank(admin);
        token.pauseScope(transferScope);
    }

    function _permitDigest(
        address target,
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline));
        return keccak256(abi.encodePacked("\x19\x01", IERC20Permit(target).DOMAIN_SEPARATOR(), structHash));
    }

    function _signPermit(
        address target,
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal returns (uint8 v, bytes32 r, bytes32 s) {
        return VM.sign(_privateKeyFor(owner), _permitDigest(target, owner, spender, value, nonce, deadline));
    }

    function _privateKeyFor(address actor) internal view returns (uint256) {
        if (actor == admin) return ADMIN_PK;
        if (actor == bob) return BOB_PK;
        if (actor == eve) return EVE_PK;
        if (actor == carol) return CAROL_PK;
        if (actor == dave) return DAVE_PK;
        revert("unknown actor");
    }

    function _actor(uint8 seed) internal view returns (address) {
        uint256 normalized = uint256(seed) % 5;
        if (normalized == 0) return admin;
        if (normalized == 1) return bob;
        if (normalized == 2) return eve;
        if (normalized == 3) return carol;
        return dave;
    }

    function _actorExcluding(address excluded, uint8 seed) internal view returns (address actor) {
        actor = _actor(seed);
        if (actor == excluded) {
            actor = _actor(seed + 1);
        }
    }

    function _markerSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](1);
        selectors[0] = IFacetVersionMarker.facetVersion.selector;
    }

    function _addFacet(address facetAddress_, bytes4[] memory selectors) internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: facetAddress_, action: IDiamondCut.FacetCutAction.Add, functionSelectors: selectors
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function _replaceFacet(address facetAddress_, bytes4[] memory selectors) internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: facetAddress_, action: IDiamondCut.FacetCutAction.Replace, functionSelectors: selectors
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function _removeSelectors(bytes4[] memory selectors) internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(0), action: IDiamondCut.FacetCutAction.Remove, functionSelectors: selectors
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function _assertMissingSelector(bytes memory callData, string memory reason) internal {
        (bool success,) = address(diamond).call(callData);
        assertTrue(!success, reason);
    }

    function _concat(bytes4[] memory first, bytes4[] memory second) internal pure returns (bytes4[] memory combined) {
        combined = new bytes4[](first.length + second.length);

        uint256 i;
        for (; i < first.length; i++) {
            combined[i] = first[i];
        }

        for (uint256 j = 0; j < second.length; j++) {
            combined[i + j] = second[j];
        }
    }

    function _erc721Exists(uint256 tokenId) internal view returns (bool) {
        try IERC721TokenFacet(address(diamond)).ownerOf(tokenId) returns (address) {
            return true;
        } catch {
            return false;
        }
    }

    function _erc721OwnerOrZero(uint256 tokenId) internal view returns (address owner) {
        try IERC721TokenFacet(address(diamond)).ownerOf(tokenId) returns (address owner_) {
            return owner_;
        } catch {
            return address(0);
        }
    }

    function _erc721ApprovalOrZero(uint256 tokenId) internal view returns (address approved) {
        try IERC721TokenFacet(address(diamond)).getApproved(tokenId) returns (address approved_) {
            return approved_;
        } catch {
            return address(0);
        }
    }

    function _expectNonexistentToken(uint256 tokenId) internal {
        VM.expectRevert(abi.encodeWithSelector(IERC721TokenBase.ERC721TokenNonexistentToken.selector, tokenId));
        IERC721TokenFacet(address(diamond)).ownerOf(tokenId);
    }
}
