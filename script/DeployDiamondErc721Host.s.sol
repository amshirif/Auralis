// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IERC721} from "../src/interfaces/IERC721.sol";
import {IERC721Metadata} from "../src/interfaces/IERC721Metadata.sol";
import {IERC721TokenFacet} from "../src/interfaces/IERC721TokenFacet.sol";
import {ERC721TokenFacet} from "../src/token/facets/ERC721TokenFacet.sol";
import {LibTokenFacetDeploymentSelectors} from "../src/token/libraries/LibTokenFacetDeploymentSelectors.sol";
import {DiamondTokenHostScriptBase} from "./common/DiamondTokenHostScriptBase.sol";

/// @title DeployDiamondErc721HostScript
/// @notice Reference local deployment flow for an ERC721-hosted diamond.
contract DeployDiamondErc721HostScript is DiamondTokenHostScriptBase {
    string internal constant TOKEN_OBJECT = "diamondErc721Host";
    string internal constant TOKEN_OUTPUT_RELATIVE_PATH = "/deployments/diamond-erc721.local.json";

    /// @notice Deploys and initializes a reference ERC721-hosted diamond.
    /// @dev Requires `PRIVATE_KEY` to be set in the environment.
    function run() external returns (address diamondAddress, address tokenFacetAddress) {
        uint256 deployerPrivateKey = VM.envUint("PRIVATE_KEY");
        address owner = VM.addr(deployerPrivateKey);
        address cutFacetAddress;
        address loupeFacetAddress;

        VM.startBroadcast(deployerPrivateKey);

        (diamondAddress, cutFacetAddress, loupeFacetAddress) = _deployDiamondCore(owner);
        ERC721TokenFacet tokenFacet = new ERC721TokenFacet();
        tokenFacetAddress = address(tokenFacet);

        IDiamondCut.FacetCut[] memory tokenCut = new IDiamondCut.FacetCut[](1);
        tokenCut[0] = IDiamondCut.FacetCut({
            facetAddress: tokenFacetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibTokenFacetDeploymentSelectors.erc721HostSelectors()
        });
        IDiamondCut(diamondAddress).diamondCut(tokenCut, address(0), "");
        IERC721TokenFacet(diamondAddress).initializeErc721("Facet NFT", "FNFT", "ipfs://facet/", owner);

        VM.stopBroadcast();

        _validateErc721Host(diamondAddress, owner, cutFacetAddress, loupeFacetAddress, tokenFacetAddress);
        _writeTokenDeploymentArtifact(
            TOKEN_OBJECT,
            TOKEN_OUTPUT_RELATIVE_PATH,
            "erc721",
            owner,
            diamondAddress,
            cutFacetAddress,
            loupeFacetAddress,
            tokenFacetAddress
        );
    }

    function _validateErc721Host(
        address diamondAddress,
        address owner,
        address cutFacetAddress,
        address loupeFacetAddress,
        address tokenFacetAddress
    ) internal view {
        _validateDiamondCore(diamondAddress, owner, cutFacetAddress, loupeFacetAddress);

        IDiamondLoupe loupe = IDiamondLoupe(diamondAddress);
        IERC721TokenFacet token = IERC721TokenFacet(diamondAddress);
        address[] memory facetAddresses = loupe.facetAddresses();
        bytes4[] memory tokenSelectors = loupe.facetFunctionSelectors(tokenFacetAddress);

        require(facetAddresses.length == 3, "erc721 host facet count mismatch");
        require(_containsAddress(facetAddresses, cutFacetAddress), "erc721 host missing cut facet");
        require(_containsAddress(facetAddresses, loupeFacetAddress), "erc721 host missing loupe facet");
        require(_containsAddress(facetAddresses, tokenFacetAddress), "erc721 host missing token facet");
        require(
            tokenSelectors.length == LibTokenFacetDeploymentSelectors.erc721HostSelectors().length,
            "erc721 host selector count mismatch"
        );
        require(token.isErc721Initialized(), "erc721 host not initialized");
        require(keccak256(bytes(token.name())) == keccak256(bytes("Facet NFT")), "erc721 host name mismatch");
        require(keccak256(bytes(token.symbol())) == keccak256(bytes("FNFT")), "erc721 host symbol mismatch");
        require(token.totalSupply() == 0, "erc721 host initial supply mismatch");
        require(token.hasRole(token.DEFAULT_ADMIN_ROLE(), owner), "erc721 host default admin missing");
        require(token.hasRole(token.TOKEN_ADMIN_ROLE(), owner), "erc721 host token admin missing");
        require(token.hasRole(token.ERC721_MINTER_ROLE(), owner), "erc721 host minter missing");
        require(token.hasRole(token.ERC721_BURNER_ROLE(), owner), "erc721 host burner missing");
        require(token.hasRole(token.ERC721_METADATA_ROLE(), owner), "erc721 host metadata missing");
        require(token.hasRole(token.PAUSER_ROLE(), owner), "erc721 host pauser missing");
        require(token.supportsInterface(type(IERC165).interfaceId), "erc721 host missing erc165");
        require(token.supportsInterface(type(IERC721).interfaceId), "erc721 host missing erc721");
        require(token.supportsInterface(type(IERC721Metadata).interfaceId), "erc721 host missing metadata");
        require(token.supportsInterface(type(IERC721TokenFacet).interfaceId), "erc721 host missing facet interface");

        _requireSelectorOwner(loupe, DiamondCutFacet.diamondCut.selector, cutFacetAddress, "erc721 host cut owner");
        _requireSelectorOwner(loupe, DiamondLoupeFacet.facets.selector, loupeFacetAddress, "erc721 host loupe owner");
        _requireSelectorOwner(
            loupe, IERC721TokenFacet.initializeErc721.selector, tokenFacetAddress, "erc721 host init owner"
        );
        _requireSelectorOwner(loupe, IERC721Metadata.name.selector, tokenFacetAddress, "erc721 host name owner");
        _requireSelectorOwner(
            loupe, IERC721TokenFacet.ERC721_METADATA_ROLE.selector, tokenFacetAddress, "erc721 host metadata owner"
        );
        _requireSelectorOwner(loupe, IERC721.ownerOf.selector, tokenFacetAddress, "erc721 host ownerOf owner");
        _requireSelectorOwner(loupe, IERC165.supportsInterface.selector, tokenFacetAddress, "erc721 host erc165 owner");
    }

    function _requireSelectorOwner(IDiamondLoupe loupe, bytes4 selector, address expected, string memory message)
        internal
        view
    {
        require(loupe.facetAddress(selector) == expected, message);
    }
}
