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
import {IERC4626VaultStrategy} from "../src/interfaces/IERC4626VaultStrategy.sol";
import {IERC7535VaultFacet} from "../src/interfaces/IERC7535VaultFacet.sol";
import {IOracleAdapter} from "../src/interfaces/IOracleAdapter.sol";
import {ERC4626VaultControlsFacet} from "../src/vault/facets/ERC4626VaultControlsFacet.sol";
import {ERC4626VaultFacet} from "../src/vault/facets/ERC4626VaultFacet.sol";
import {ERC4626VaultIntegrationFacet} from "../src/vault/facets/ERC4626VaultIntegrationFacet.sol";
import {ERC7535VaultFacet} from "../src/vault/facets/ERC7535VaultFacet.sol";
import {LibVaultAsset} from "../src/vault/libraries/LibVaultAsset.sol";
import {LibVaultFacetSelectors} from "../src/vault/libraries/LibVaultFacetSelectors.sol";
import {DiamondVaultHostScriptBase} from "./common/DiamondVaultHostScriptBase.sol";
import {
    LocalMockOracleFeed,
    LocalNativeHappyPathVaultStrategy,
    LocalOracleAdapterHarness
} from "./mocks/LocalVaultDeploymentMocks.sol";

/// @title DeployDiamondNativeVaultHostScript
/// @notice Reference local deployment flow for the native hosted vault diamond.
contract DeployDiamondNativeVaultHostScript is DiamondVaultHostScriptBase {
    struct NativeVaultHostDeploymentState {
        address diamondAddress;
        address cutFacetAddress;
        address loupeFacetAddress;
        address vaultCoreFacetAddress;
        address vaultNativeFacetAddress;
        address vaultControlsFacetAddress;
        address vaultIntegrationFacetAddress;
        address vaultAssetAddress;
        address oracleFeedAddress;
        address oracleAdapterAddress;
        address strategyAddress;
    }

    string internal constant VAULT_OBJECT = "diamondNativeVaultHost";
    string internal constant VAULT_OUTPUT_RELATIVE_PATH = "/deployments/diamond-native-vault.local.json";
    string internal constant VAULT_NAME = "Native Vault Share";
    string internal constant VAULT_SYMBOL = "nvSHARE";
    uint64 internal constant MAX_STALENESS = 1 hours;
    uint8 internal constant ORACLE_DECIMALS = 8;
    int256 internal constant ORACLE_ANSWER = 100_000_000;

    function run()
        external
        returns (
            address diamondAddress,
            address vaultCoreFacetAddress,
            address vaultNativeFacetAddress,
            address vaultControlsFacetAddress,
            address vaultIntegrationFacetAddress
        )
    {
        uint256 deployerPrivateKey = VM.envUint("PRIVATE_KEY");
        address owner = VM.addr(deployerPrivateKey);
        NativeVaultHostDeploymentState memory state;

        VM.startBroadcast(deployerPrivateKey);

        (state.diamondAddress, state.cutFacetAddress, state.loupeFacetAddress) = _deployDiamondCore(owner);
        state = _deployVaultSupportContracts(state, owner);
        _installVaultHostFacets(state);

        IERC4626VaultFacet(state.diamondAddress)
            .initializeVault(state.vaultAssetAddress, VAULT_NAME, VAULT_SYMBOL, owner);
        IERC4626VaultIntegrationFacet(state.diamondAddress).setOracleAdapter(state.oracleAdapterAddress);
        IERC4626VaultIntegrationFacet(state.diamondAddress).setStrategy(state.strategyAddress);

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
                vaultAsyncDepositFacet: address(0),
                vaultAsyncRedeemFacet: address(0),
                vaultNativeFacet: state.vaultNativeFacetAddress,
                vaultControlsFacet: state.vaultControlsFacetAddress,
                vaultIntegrationFacet: state.vaultIntegrationFacetAddress,
                vaultAsset: state.vaultAssetAddress,
                oracleFeed: state.oracleFeedAddress,
                oracleAdapter: state.oracleAdapterAddress,
                strategy: state.strategyAddress,
                owner: owner,
                chainId: block.chainid,
                strategyDebt: 0,
                liveStrategyAssets: 0,
                strategyEmergencyExit: false,
                assetMode: "native",
                vaultName: VAULT_NAME,
                vaultSymbol: VAULT_SYMBOL
            })
        );

        diamondAddress = state.diamondAddress;
        vaultCoreFacetAddress = state.vaultCoreFacetAddress;
        vaultNativeFacetAddress = state.vaultNativeFacetAddress;
        vaultControlsFacetAddress = state.vaultControlsFacetAddress;
        vaultIntegrationFacetAddress = state.vaultIntegrationFacetAddress;
    }

    function _deployVaultSupportContracts(NativeVaultHostDeploymentState memory state, address owner)
        internal
        returns (NativeVaultHostDeploymentState memory)
    {
        state.vaultCoreFacetAddress = address(new ERC4626VaultFacet());
        state.vaultNativeFacetAddress = address(new ERC7535VaultFacet());
        state.vaultControlsFacetAddress = address(new ERC4626VaultControlsFacet());
        state.vaultIntegrationFacetAddress = address(new ERC4626VaultIntegrationFacet());
        state.vaultAssetAddress = LibVaultAsset.NATIVE_ASSET_SENTINEL;
        state.oracleFeedAddress = address(new LocalMockOracleFeed(ORACLE_DECIMALS, ORACLE_ANSWER, block.timestamp - 1));
        state.oracleAdapterAddress =
            address(new LocalOracleAdapterHarness(owner, state.oracleFeedAddress, MAX_STALENESS));
        state.strategyAddress = address(new LocalNativeHappyPathVaultStrategy(state.diamondAddress));
        return state;
    }

    function _installVaultHostFacets(NativeVaultHostDeploymentState memory state) internal {
        IDiamondCut.FacetCut[] memory vaultCut = new IDiamondCut.FacetCut[](4);
        vaultCut[0] = IDiamondCut.FacetCut({
            facetAddress: state.vaultCoreFacetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultCoreSelectors()
        });
        vaultCut[1] = IDiamondCut.FacetCut({
            facetAddress: state.vaultNativeFacetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultNativeSelectors()
        });
        vaultCut[2] = IDiamondCut.FacetCut({
            facetAddress: state.vaultControlsFacetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultControlsSelectors()
        });
        vaultCut[3] = IDiamondCut.FacetCut({
            facetAddress: state.vaultIntegrationFacetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: LibVaultFacetSelectors.vaultIntegrationSelectors()
        });
        IDiamondCut(state.diamondAddress).diamondCut(vaultCut, address(0), "");
    }

    function _validateVaultHost(NativeVaultHostDeploymentState memory state, address owner) internal view {
        _validateDiamondCore(state.diamondAddress, owner, state.cutFacetAddress, state.loupeFacetAddress);

        IDiamondLoupe loupe = IDiamondLoupe(state.diamondAddress);
        IERC4626VaultFacet vaultCore = IERC4626VaultFacet(state.diamondAddress);
        IERC4626VaultControlsFacet vaultControls = IERC4626VaultControlsFacet(state.diamondAddress);
        IERC4626VaultIntegrationFacet vaultIntegration = IERC4626VaultIntegrationFacet(state.diamondAddress);
        IERC4626VaultStrategy strategy = IERC4626VaultStrategy(state.strategyAddress);
        address[] memory facetAddresses = loupe.facetAddresses();

        require(facetAddresses.length == 6, "native vault host facet count mismatch");
        require(_containsAddress(facetAddresses, state.cutFacetAddress), "native vault host missing cut facet");
        require(_containsAddress(facetAddresses, state.loupeFacetAddress), "native vault host missing loupe facet");
        require(_containsAddress(facetAddresses, state.vaultCoreFacetAddress), "native vault host missing core facet");
        require(
            _containsAddress(facetAddresses, state.vaultNativeFacetAddress), "native vault host missing native facet"
        );
        require(
            _containsAddress(facetAddresses, state.vaultControlsFacetAddress),
            "native vault host missing controls facet"
        );
        require(
            _containsAddress(facetAddresses, state.vaultIntegrationFacetAddress),
            "native vault host missing integration facet"
        );

        require(
            loupe.facetFunctionSelectors(state.vaultCoreFacetAddress).length
                == LibVaultFacetSelectors.vaultCoreSelectors().length,
            "native vault host core selector count mismatch"
        );
        require(
            loupe.facetFunctionSelectors(state.vaultNativeFacetAddress).length
                == LibVaultFacetSelectors.vaultNativeSelectors().length,
            "native vault host native selector count mismatch"
        );
        require(
            loupe.facetFunctionSelectors(state.vaultControlsFacetAddress).length
                == LibVaultFacetSelectors.vaultControlsSelectors().length,
            "native vault host controls selector count mismatch"
        );
        require(
            loupe.facetFunctionSelectors(state.vaultIntegrationFacetAddress).length
                == LibVaultFacetSelectors.vaultIntegrationSelectors().length,
            "native vault host integration selector count mismatch"
        );

        require(vaultCore.isVaultInitialized(), "native vault host not initialized");
        require(vaultCore.asset() == state.vaultAssetAddress, "native vault host asset mismatch");
        require(
            keccak256(bytes(IERC20Metadata(state.diamondAddress).name())) == keccak256(bytes(VAULT_NAME)),
            "native vault name mismatch"
        );
        require(
            keccak256(bytes(IERC20Metadata(state.diamondAddress).symbol())) == keccak256(bytes(VAULT_SYMBOL)),
            "native vault symbol mismatch"
        );
        require(vaultControls.hasRole(vaultControls.DEFAULT_ADMIN_ROLE(), owner), "native vault default admin missing");
        require(vaultControls.hasRole(vaultControls.PAUSER_ROLE(), owner), "native vault pauser missing");
        require(vaultControls.hasRole(vaultControls.VAULT_MANAGER_ROLE(), owner), "native vault manager missing");

        (,, address feeRecipient) = vaultControls.feeConfig();
        require(feeRecipient == owner, "native vault fee recipient mismatch");

        require(vaultIntegration.oracleAdapter() == state.oracleAdapterAddress, "native vault oracle adapter mismatch");
        require(vaultIntegration.strategy() == state.strategyAddress, "native vault strategy mismatch");
        require(vaultIntegration.strategyDebt() == 0, "native vault strategy debt should be zero");
        require(!vaultIntegration.strategyEmergencyExit(), "native vault emergency exit should be inactive");
        require(vaultIntegration.liveStrategyAssets() == 0, "native vault live strategy assets should be zero");
        require(strategy.vault() == state.diamondAddress, "native strategy vault binding mismatch");
        require(strategy.asset() == state.vaultAssetAddress, "native strategy asset binding mismatch");

        IOracleAdapter.OracleQuote memory quotePayload = vaultIntegration.oracleQuote();
        require(quotePayload.value == ORACLE_ANSWER, "native vault quote value mismatch");
        require(quotePayload.decimals == ORACLE_DECIMALS, "native vault quote decimals mismatch");
        require(quotePayload.updatedAt != 0, "native vault quote timestamp missing");

        require(
            IERC165(state.diamondAddress).supportsInterface(type(IERC4626VaultFacet).interfaceId),
            "native vault host missing core interface"
        );
        require(
            IERC165(state.diamondAddress).supportsInterface(type(IERC7535VaultFacet).interfaceId),
            "native vault host missing native interface"
        );
        require(
            IERC165(state.diamondAddress).supportsInterface(type(IERC4626VaultControlsFacet).interfaceId),
            "native vault host missing controls interface"
        );
        require(
            IERC165(state.diamondAddress).supportsInterface(type(IERC4626VaultIntegrationFacet).interfaceId),
            "native vault host missing integration interface"
        );

        _requireSelectorOwner(
            loupe, DiamondCutFacet.diamondCut.selector, state.cutFacetAddress, "native vault cut owner"
        );
        _requireSelectorOwner(
            loupe, DiamondLoupeFacet.facets.selector, state.loupeFacetAddress, "native vault loupe owner"
        );
        _requireSelectorOwner(
            loupe, IERC4626VaultFacet.initializeVault.selector, state.vaultCoreFacetAddress, "native vault init owner"
        );
        _requireSelectorOwner(
            loupe,
            IERC7535VaultFacet.depositNative.selector,
            state.vaultNativeFacetAddress,
            "native vault deposit owner"
        );
        _requireSelectorOwner(
            loupe,
            IERC4626VaultControls.VAULT_MANAGER_ROLE.selector,
            state.vaultControlsFacetAddress,
            "native vault manager owner"
        );
        _requireSelectorOwner(
            loupe,
            IERC4626VaultIntegrationFacet.oracleAdapter.selector,
            state.vaultIntegrationFacetAddress,
            "native vault oracle owner"
        );
        _requireSelectorOwner(
            loupe,
            IERC4626VaultIntegrationFacet.deployToStrategy.selector,
            state.vaultIntegrationFacetAddress,
            "native vault deploy strategy owner"
        );
        _requireSelectorOwner(
            loupe, IERC165.supportsInterface.selector, state.vaultControlsFacetAddress, "native vault erc165 owner"
        );
    }

    function _requireSelectorOwner(IDiamondLoupe loupe, bytes4 selector, address expected, string memory message)
        internal
        view
    {
        require(loupe.facetAddress(selector) == expected, message);
    }
}
