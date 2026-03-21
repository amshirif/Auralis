// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {IERC20Permit} from "../../src/interfaces/IERC20Permit.sol";
import {IERC20TokenFacet} from "../../src/interfaces/IERC20TokenFacet.sol";
import {ERC20TokenFacet} from "../../src/token/facets/ERC20TokenFacet.sol";
import {DiamondCutFacet} from "../../src/diamond/facets/DiamondCutFacet.sol";
import {LibTokenFacetDeploymentSelectors} from "../../src/token/libraries/LibTokenFacetDeploymentSelectors.sol";
import {DiamondProxyHarness} from "./DiamondTestHarness.sol";
import {TestBase} from "./AccessControlTestHarness.sol";

abstract contract ERC20TokenFacetFixture is TestBase {
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

    ERC20TokenFacet internal facet;
    DiamondCutFacet internal cutFacet;
    DiamondProxyHarness internal diamond;

    function setUp() public virtual {
        admin = VM.addr(ADMIN_PK);
        bob = VM.addr(BOB_PK);
        eve = VM.addr(EVE_PK);
        carol = VM.addr(CAROL_PK);
        dave = VM.addr(DAVE_PK);

        facet = new ERC20TokenFacet();
        cutFacet = new DiamondCutFacet();
        diamond = new DiamondProxyHarness(admin, address(cutFacet));
    }

    function _erc20Init(address target) internal {
        IERC20TokenFacet(target).initializeErc20("Facet Token", "FTKN", 18, admin);
    }

    function _addErc20FacetToDiamond() internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibTokenFacetDeploymentSelectors.erc20HostSelectors()
        });

        VM.prank(admin);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
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
        uint256 ownerKey,
        address target,
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal returns (uint8 v, bytes32 r, bytes32 s) {
        return VM.sign(ownerKey, _permitDigest(target, owner, spender, value, nonce, deadline));
    }

    function _recoverPermitSigner(
        address target,
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address) {
        return ecrecover(_permitDigest(target, owner, spender, value, nonce, deadline), v, r, s);
    }
}
