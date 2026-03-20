// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IERC20Metadata} from "../src/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "../src/interfaces/IERC20Permit.sol";
import {IERC20TokenFacet} from "../src/interfaces/IERC20TokenFacet.sol";
import {ERC20TokenFacet} from "../src/token/facets/ERC20TokenFacet.sol";
import {LibTokenFacetDeploymentSelectors} from "../src/token/libraries/LibTokenFacetDeploymentSelectors.sol";
import {DiamondTokenHostScriptBase} from "./common/DiamondTokenHostScriptBase.sol";

/// @title DeployDiamondErc20HostScript
/// @notice Reference local deployment flow for an ERC20-hosted diamond.
contract DeployDiamondErc20HostScript is DiamondTokenHostScriptBase {
    string internal constant TOKEN_OBJECT = "diamondErc20Host";
    string internal constant TOKEN_OUTPUT_RELATIVE_PATH = "/deployments/diamond-erc20.local.json";

    /// @notice Deploys and initializes a reference ERC20-hosted diamond.
    /// @dev Requires `PRIVATE_KEY` to be set in the environment.
    function run() external returns (address diamondAddress, address tokenFacetAddress) {
        uint256 deployerPrivateKey = VM.envUint("PRIVATE_KEY");
        address owner = VM.addr(deployerPrivateKey);
        address cutFacetAddress;
        address loupeFacetAddress;

        VM.startBroadcast(deployerPrivateKey);

        (diamondAddress, cutFacetAddress, loupeFacetAddress) = _deployDiamondCore(owner);
        ERC20TokenFacet tokenFacet = new ERC20TokenFacet();
        tokenFacetAddress = address(tokenFacet);

        IDiamondCut.FacetCut[] memory tokenCut = new IDiamondCut.FacetCut[](1);
        tokenCut[0] = IDiamondCut.FacetCut({
            facetAddress: tokenFacetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibTokenFacetDeploymentSelectors.erc20HostSelectors()
        });
        IDiamondCut(diamondAddress).diamondCut(tokenCut, address(0), "");
        IERC20TokenFacet(diamondAddress).initializeErc20("Facet Token", "FTKN", 18, owner);

        VM.stopBroadcast();

        _validateErc20Host(diamondAddress, owner, cutFacetAddress, loupeFacetAddress, tokenFacetAddress);
        _writeTokenDeploymentArtifact(
            TOKEN_OBJECT,
            TOKEN_OUTPUT_RELATIVE_PATH,
            "erc20",
            owner,
            diamondAddress,
            cutFacetAddress,
            loupeFacetAddress,
            tokenFacetAddress
        );
    }

    function _validateErc20Host(
        address diamondAddress,
        address owner,
        address cutFacetAddress,
        address loupeFacetAddress,
        address tokenFacetAddress
    ) internal view {
        _validateDiamondCore(diamondAddress, owner, cutFacetAddress, loupeFacetAddress);

        IDiamondLoupe loupe = IDiamondLoupe(diamondAddress);
        IERC20TokenFacet token = IERC20TokenFacet(diamondAddress);
        address[] memory facetAddresses = loupe.facetAddresses();
        bytes4[] memory tokenSelectors = loupe.facetFunctionSelectors(tokenFacetAddress);

        require(facetAddresses.length == 3, "erc20 host facet count mismatch");
        require(_containsAddress(facetAddresses, cutFacetAddress), "erc20 host missing cut facet");
        require(_containsAddress(facetAddresses, loupeFacetAddress), "erc20 host missing loupe facet");
        require(_containsAddress(facetAddresses, tokenFacetAddress), "erc20 host missing token facet");
        require(
            tokenSelectors.length == LibTokenFacetDeploymentSelectors.erc20HostSelectors().length,
            "erc20 host selector count mismatch"
        );
        require(token.isErc20Initialized(), "erc20 host not initialized");
        require(keccak256(bytes(token.name())) == keccak256(bytes("Facet Token")), "erc20 host name mismatch");
        require(keccak256(bytes(token.symbol())) == keccak256(bytes("FTKN")), "erc20 host symbol mismatch");
        require(token.decimals() == 18, "erc20 host decimals mismatch");
        require(token.hasRole(token.DEFAULT_ADMIN_ROLE(), owner), "erc20 host default admin missing");
        require(token.hasRole(token.TOKEN_ADMIN_ROLE(), owner), "erc20 host token admin missing");
        require(token.hasRole(token.ERC20_MINTER_ROLE(), owner), "erc20 host minter missing");
        require(token.hasRole(token.ERC20_BURNER_ROLE(), owner), "erc20 host burner missing");
        require(token.hasRole(token.PAUSER_ROLE(), owner), "erc20 host pauser missing");
        require(token.supportsInterface(type(IERC165).interfaceId), "erc20 host missing erc165");
        require(token.supportsInterface(type(IERC20Permit).interfaceId), "erc20 host missing permit");
        require(token.supportsInterface(type(IERC20TokenFacet).interfaceId), "erc20 host missing facet interface");

        _requireSelectorOwner(loupe, DiamondCutFacet.diamondCut.selector, cutFacetAddress, "erc20 host cut owner");
        _requireSelectorOwner(loupe, DiamondLoupeFacet.facets.selector, loupeFacetAddress, "erc20 host loupe owner");
        _requireSelectorOwner(
            loupe, IERC20TokenFacet.initializeErc20.selector, tokenFacetAddress, "erc20 host init owner"
        );
        _requireSelectorOwner(loupe, IERC20Metadata.name.selector, tokenFacetAddress, "erc20 host name owner");
        _requireSelectorOwner(
            loupe, IERC20TokenFacet.TOKEN_ADMIN_ROLE.selector, tokenFacetAddress, "erc20 host token admin owner"
        );
        _requireSelectorOwner(loupe, IERC20Permit.permit.selector, tokenFacetAddress, "erc20 host permit owner");
        _requireSelectorOwner(loupe, IERC165.supportsInterface.selector, tokenFacetAddress, "erc20 host erc165 owner");
    }

    function _requireSelectorOwner(IDiamondLoupe loupe, bytes4 selector, address expected, string memory message)
        internal
        view
    {
        require(loupe.facetAddress(selector) == expected, message);
    }
}
