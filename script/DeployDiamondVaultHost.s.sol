// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/facets/DiamondLoupeFacet.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";
import {IERC20Metadata} from "../src/interfaces/IERC20Metadata.sol";
import {IERC4626VaultControls} from "../src/interfaces/IERC4626VaultControls.sol";
import {IERC4626VaultControlsFacet} from "../src/interfaces/IERC4626VaultControlsFacet.sol";
import {IERC4626VaultFacet} from "../src/interfaces/IERC4626VaultFacet.sol";
import {IERC4626VaultIntegrationFacet} from "../src/interfaces/IERC4626VaultIntegrationFacet.sol";
import {IOracleAdapter} from "../src/interfaces/IOracleAdapter.sol";
import {ERC4626VaultControlsFacet} from "../src/vault/facets/ERC4626VaultControlsFacet.sol";
import {ERC4626VaultFacet} from "../src/vault/facets/ERC4626VaultFacet.sol";
import {ERC4626VaultIntegrationFacet} from "../src/vault/facets/ERC4626VaultIntegrationFacet.sol";
import {LibVaultFacetSelectors} from "../src/vault/libraries/LibVaultFacetSelectors.sol";
import {DiamondVaultHostScriptBase} from "./common/DiamondVaultHostScriptBase.sol";
import {
    LocalMintableVaultAsset,
    LocalMockOracleFeed,
    LocalOracleAdapterHarness
} from "./mocks/LocalVaultDeploymentMocks.sol";

/// @title DeployDiamondVaultHostScript
/// @notice Reference local deployment flow for the hosted vault diamond.
contract DeployDiamondVaultHostScript is DiamondVaultHostScriptBase {
    struct VaultHostDeploymentState {
        address diamondAddress;
        address cutFacetAddress;
        address loupeFacetAddress;
        address vaultCoreFacetAddress;
        address vaultControlsFacetAddress;
        address vaultIntegrationFacetAddress;
        address vaultAssetAddress;
        address oracleFeedAddress;
        address oracleAdapterAddress;
    }

    string internal constant VAULT_OBJECT = "diamondVaultHost";
    string internal constant VAULT_OUTPUT_RELATIVE_PATH = "/deployments/diamond-vault.local.json";
    string internal constant VAULT_NAME = "Vault Share";
    string internal constant VAULT_SYMBOL = "vSHARE";
    uint64 internal constant MAX_STALENESS = 1 hours;
    uint8 internal constant ORACLE_DECIMALS = 8;
    int256 internal constant ORACLE_ANSWER = 100_000_000;

    function run()
        external
        returns (
            address diamondAddress,
            address vaultCoreFacetAddress,
            address vaultControlsFacetAddress,
            address vaultIntegrationFacetAddress
        )
    {
        uint256 deployerPrivateKey = VM.envUint("PRIVATE_KEY");
        address owner = VM.addr(deployerPrivateKey);
        VaultHostDeploymentState memory state;

        VM.startBroadcast(deployerPrivateKey);

        (state.diamondAddress, state.cutFacetAddress, state.loupeFacetAddress) = _deployDiamondCore(owner);
        state = _deployVaultSupportContracts(state, owner);
        _installVaultHostFacets(state);

        IERC4626VaultFacet(state.diamondAddress)
            .initializeVault(state.vaultAssetAddress, VAULT_NAME, VAULT_SYMBOL, owner);
        IERC4626VaultIntegrationFacet(state.diamondAddress).setOracleAdapter(state.oracleAdapterAddress);

        VM.stopBroadcast();

        _validateVaultHost(state, owner);
        _writeVaultDeploymentArtifact(
            VAULT_OBJECT,
            VAULT_OUTPUT_RELATIVE_PATH,
            VaultHostDeploymentArtifact({
                diamond: state.diamondAddress,
                diamondCutFacet: state.cutFacetAddress,
                diamondLoupeFacet: state.loupeFacetAddress,
                vaultCoreFacet: state.vaultCoreFacetAddress,
                vaultControlsFacet: state.vaultControlsFacetAddress,
                vaultIntegrationFacet: state.vaultIntegrationFacetAddress,
                vaultAsset: state.vaultAssetAddress,
                oracleFeed: state.oracleFeedAddress,
                oracleAdapter: state.oracleAdapterAddress,
                strategy: address(0),
                owner: owner,
                chainId: block.chainid,
                vaultName: VAULT_NAME,
                vaultSymbol: VAULT_SYMBOL
            })
        );

        diamondAddress = state.diamondAddress;
        vaultCoreFacetAddress = state.vaultCoreFacetAddress;
        vaultControlsFacetAddress = state.vaultControlsFacetAddress;
        vaultIntegrationFacetAddress = state.vaultIntegrationFacetAddress;
    }

    function _deployVaultSupportContracts(VaultHostDeploymentState memory state, address owner)
        internal
        returns (VaultHostDeploymentState memory)
    {
        state.vaultCoreFacetAddress = address(new ERC4626VaultFacet());
        state.vaultControlsFacetAddress = address(new ERC4626VaultControlsFacet());
        state.vaultIntegrationFacetAddress = address(new ERC4626VaultIntegrationFacet());
        state.vaultAssetAddress = address(new LocalMintableVaultAsset("Mock USD", "mUSD", 6));
        state.oracleFeedAddress = address(new LocalMockOracleFeed(ORACLE_DECIMALS, ORACLE_ANSWER, block.timestamp - 1));
        state.oracleAdapterAddress =
            address(new LocalOracleAdapterHarness(owner, state.oracleFeedAddress, MAX_STALENESS));
        return state;
    }

    function _installVaultHostFacets(VaultHostDeploymentState memory state) internal {
        IDiamondCut.FacetCut[] memory vaultCut = new IDiamondCut.FacetCut[](3);
        vaultCut[0] = IDiamondCut.FacetCut({
            facetAddress: state.vaultCoreFacetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultCoreSelectors()
        });
        vaultCut[1] = IDiamondCut.FacetCut({
            facetAddress: state.vaultControlsFacetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultControlsSelectors()
        });
        vaultCut[2] = IDiamondCut.FacetCut({
            facetAddress: state.vaultIntegrationFacetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultIntegrationSelectors()
        });
        IDiamondCut(state.diamondAddress).diamondCut(vaultCut, address(0), "");
    }

    function _validateVaultHost(VaultHostDeploymentState memory state, address owner) internal view {
        _validateDiamondCore(state.diamondAddress, owner, state.cutFacetAddress, state.loupeFacetAddress);

        IDiamondLoupe loupe = IDiamondLoupe(state.diamondAddress);
        IERC4626VaultFacet vaultCore = IERC4626VaultFacet(state.diamondAddress);
        IERC4626VaultControlsFacet vaultControls = IERC4626VaultControlsFacet(state.diamondAddress);
        IERC4626VaultIntegrationFacet vaultIntegration = IERC4626VaultIntegrationFacet(state.diamondAddress);
        address[] memory facetAddresses = loupe.facetAddresses();

        require(facetAddresses.length == 5, "vault host facet count mismatch");
        require(_containsAddress(facetAddresses, state.cutFacetAddress), "vault host missing cut facet");
        require(_containsAddress(facetAddresses, state.loupeFacetAddress), "vault host missing loupe facet");
        require(_containsAddress(facetAddresses, state.vaultCoreFacetAddress), "vault host missing core facet");
        require(_containsAddress(facetAddresses, state.vaultControlsFacetAddress), "vault host missing controls facet");
        require(
            _containsAddress(facetAddresses, state.vaultIntegrationFacetAddress), "vault host missing integration facet"
        );

        require(
            loupe.facetFunctionSelectors(state.vaultCoreFacetAddress).length
                == LibVaultFacetSelectors.vaultCoreSelectors().length,
            "vault host core selector count mismatch"
        );
        require(
            loupe.facetFunctionSelectors(state.vaultControlsFacetAddress).length
                == LibVaultFacetSelectors.vaultControlsSelectors().length,
            "vault host controls selector count mismatch"
        );
        require(
            loupe.facetFunctionSelectors(state.vaultIntegrationFacetAddress).length
                == LibVaultFacetSelectors.vaultIntegrationSelectors().length,
            "vault host integration selector count mismatch"
        );

        require(vaultCore.isVaultInitialized(), "vault host not initialized");
        require(vaultCore.asset() == state.vaultAssetAddress, "vault host asset mismatch");
        require(
            keccak256(bytes(IERC20Metadata(state.diamondAddress).name())) == keccak256(bytes(VAULT_NAME)),
            "vault name mismatch"
        );
        require(
            keccak256(bytes(IERC20Metadata(state.diamondAddress).symbol())) == keccak256(bytes(VAULT_SYMBOL)),
            "vault symbol mismatch"
        );
        require(vaultControls.hasRole(vaultControls.DEFAULT_ADMIN_ROLE(), owner), "vault default admin missing");
        require(vaultControls.hasRole(vaultControls.PAUSER_ROLE(), owner), "vault pauser missing");
        require(vaultControls.hasRole(vaultControls.VAULT_MANAGER_ROLE(), owner), "vault manager missing");

        (,, address feeRecipient) = vaultControls.feeConfig();
        require(feeRecipient == owner, "vault fee recipient mismatch");

        require(vaultIntegration.oracleAdapter() == state.oracleAdapterAddress, "vault oracle adapter mismatch");
        require(vaultIntegration.strategy() == address(0), "vault strategy should be unset");
        require(vaultIntegration.strategyReportedAssets() == 0, "vault reported assets should be zero");

        IOracleAdapter.OracleQuote memory quotePayload = vaultIntegration.oracleQuote();
        require(quotePayload.value == ORACLE_ANSWER, "vault quote value mismatch");
        require(quotePayload.decimals == ORACLE_DECIMALS, "vault quote decimals mismatch");
        require(quotePayload.updatedAt != 0, "vault quote timestamp missing");

        require(
            IERC165(state.diamondAddress).supportsInterface(type(IERC4626VaultFacet).interfaceId),
            "vault host missing core interface"
        );
        require(
            IERC165(state.diamondAddress).supportsInterface(type(IERC4626VaultControlsFacet).interfaceId),
            "vault host missing controls interface"
        );
        require(
            IERC165(state.diamondAddress).supportsInterface(type(IERC4626VaultIntegrationFacet).interfaceId),
            "vault host missing integration interface"
        );

        _requireSelectorOwner(loupe, DiamondCutFacet.diamondCut.selector, state.cutFacetAddress, "vault cut owner");
        _requireSelectorOwner(loupe, DiamondLoupeFacet.facets.selector, state.loupeFacetAddress, "vault loupe owner");
        _requireSelectorOwner(
            loupe, IERC4626VaultFacet.initializeVault.selector, state.vaultCoreFacetAddress, "vault init owner"
        );
        _requireSelectorOwner(
            loupe,
            IERC4626VaultControls.VAULT_MANAGER_ROLE.selector,
            state.vaultControlsFacetAddress,
            "vault manager owner"
        );
        _requireSelectorOwner(
            loupe,
            IERC4626VaultIntegrationFacet.oracleAdapter.selector,
            state.vaultIntegrationFacetAddress,
            "vault oracle owner"
        );
        _requireSelectorOwner(
            loupe, IERC165.supportsInterface.selector, state.vaultControlsFacetAddress, "vault erc165 owner"
        );
    }

    function _requireSelectorOwner(IDiamondLoupe loupe, bytes4 selector, address expected, string memory message)
        internal
        view
    {
        require(loupe.facetAddress(selector) == expected, message);
    }
}
