// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";
import {ERC4626VaultControlsFacet} from "../../src/vault/facets/ERC4626VaultControlsFacet.sol";
import {ERC4626VaultFacet} from "../../src/vault/facets/ERC4626VaultFacet.sol";
import {ERC4626VaultIntegrationFacet} from "../../src/vault/facets/ERC4626VaultIntegrationFacet.sol";
import {ERC7535VaultFacet} from "../../src/vault/facets/ERC7535VaultFacet.sol";
import {LibVaultFacetSelectors} from "../../src/vault/libraries/LibVaultFacetSelectors.sol";
import {DiamondVaultDeploymentFixture} from "./DiamondVaultDeploymentTestHarness.sol";
import {MutableMockVaultStrategy} from "./ERC4626VaultStrategyTestHarness.sol";

interface IFacetVersionMarker {
    function facetVersion() external view returns (uint256);
}

contract ERC4626VaultFacetReplacement is ERC4626VaultFacet {
    function facetVersion() external pure returns (uint256) {
        return 2;
    }
}

contract ERC4626VaultControlsFacetReplacement is ERC4626VaultControlsFacet {
    function facetVersion() external pure returns (uint256) {
        return 2;
    }
}

contract ERC4626VaultIntegrationFacetReplacement is ERC4626VaultIntegrationFacet {
    function facetVersion() external pure returns (uint256) {
        return 2;
    }
}

contract ERC7535VaultFacetReplacement is ERC7535VaultFacet {
    function facetVersion() external pure returns (uint256) {
        return 2;
    }
}

abstract contract DiamondVaultHostHardeningFixture is DiamondVaultDeploymentFixture {
    struct AccountingSnapshot {
        uint256 totalAssets;
        uint256 totalSupply;
        uint256 vaultUnderlyingBalance;
        uint256 feeSinkBalance;
        uint256 actorUnderlyingBalanceSum;
        uint256 actorShareBalanceSum;
        uint256 strategyUnderlyingBalance;
        uint256 profitSourceBalance;
        uint256 lossSinkBalance;
        uint256 strategyDebt;
        uint256 liveStrategyAssets;
    }

    struct StrategyStateSnapshot {
        address strategy;
        uint256 strategyDebt;
        uint256 liveStrategyAssets;
        uint256 idleAssets;
        bool emergencyExit;
        uint256 totalManagedAssets;
        uint256 totalAssets;
        uint256 bobMaxWithdraw;
        uint256 bobMaxRedeem;
    }

    uint256 internal constant INITIAL_ASSETS = 1_000_000;
    uint256 internal constant STRATEGY_PROFIT_RESERVE = 1_000_000_000_000;
    uint256 internal constant ACTOR_COUNT = 4;
    uint256 internal constant BOB_DEPOSIT = 200_000;
    uint256 internal constant CAROL_DEPOSIT = 150_000;
    uint256 internal constant SHARE_ALLOWANCE = 25_000;
    uint256 internal constant STRATEGY_DEPLOYED_ASSETS = 225_000;
    uint256 internal constant STRATEGY_PROFIT_ASSETS = 25_000;
    uint256 internal constant BOB_AUTO_PULL_WITHDRAW_ASSETS = 150_000;
    uint256 internal constant CAROL_AUTO_PULL_REDEEM_SHARES = 50_000;

    address internal bob = address(0xB0B);
    address internal carol = address(0xCA11);
    address internal dave = address(0xD0D);
    address internal eve = address(0xE11E);
    address internal feeSink = address(0xFEE);
    address internal profitSource = address(0xBEEF1234);

    address[ACTOR_COUNT] internal actors;

    MutableMockVaultStrategy internal strategyContract;

    ERC4626VaultFacetReplacement internal coreReplacement;
    ERC4626VaultControlsFacetReplacement internal controlsReplacement;
    ERC4626VaultIntegrationFacetReplacement internal integrationReplacement;

    function setUp() public virtual override {
        super.setUp();

        coreReplacement = new ERC4626VaultFacetReplacement();
        controlsReplacement = new ERC4626VaultControlsFacetReplacement();
        integrationReplacement = new ERC4626VaultIntegrationFacetReplacement();

        actors[0] = bob;
        actors[1] = carol;
        actors[2] = dave;
        actors[3] = eve;

        strategyContract = new MutableMockVaultStrategy(address(diamond), address(asset), profitSource);

        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            address actor = actors[i];
            asset.mint(actor, INITIAL_ASSETS);
            VM.prank(actor);
            asset.approve(address(diamond), type(uint256).max);
        }

        asset.mint(profitSource, STRATEGY_PROFIT_RESERVE);
        VM.prank(profitSource);
        asset.approve(address(strategyContract), type(uint256).max);
    }

    function _installAndSeedVaultHost() internal {
        _installVaultHostFacets();
        _initializeVaultHost();
        _wireOracleAdapter();
        _seedCoreState();
        _seedControlsState();
        _seedIntegrationState();
    }

    function _seedCoreState() internal {
        VM.prank(bob);
        coreFacetInterface().deposit(BOB_DEPOSIT, bob);

        VM.prank(carol);
        coreFacetInterface().deposit(CAROL_DEPOSIT, carol);

        VM.prank(bob);
        coreFacetInterface().approve(eve, SHARE_ALLOWANCE);
    }

    function _seedControlsState() internal {
        bytes32 managerRole = controlsFacetInterface().VAULT_MANAGER_ROLE();

        VM.prank(admin);
        controlsFacetInterface().setFeeConfig(100, 50, feeSink);

        VM.prank(admin);
        controlsFacetInterface().setLimitConfig(900_000, 300_000, 300_000, 250_000, 250_000);

        VM.prank(admin);
        controlsFacetInterface().grantRole(managerRole, eve);

        VM.prank(admin);
        controlsFacetInterface()
            .grantRoleWithWindow(managerRole, dave, uint64(currentTime - 100), uint64(currentTime + 1_000));
    }

    function _seedIntegrationState() internal {
        VM.prank(admin);
        integrationFacetInterface().setStrategy(address(strategyContract));

        VM.prank(admin);
        integrationFacetInterface().deployToStrategy(STRATEGY_DEPLOYED_ASSETS);
    }

    function _injectStrategyProfit(uint256 assets) internal {
        strategyContract.injectProfit(assets);
    }

    function _applyStrategyLoss(uint256 lossAssets, uint256 withdrawableAssets) internal {
        strategyContract.applyLoss(lossAssets, withdrawableAssets);
    }

    function _setStrategyWithdrawAllReverts(bool shouldRevert) internal {
        strategyContract.setWithdrawAllReverts(shouldRevert);
    }

    function _replaceCoreFacet(address facetAddress_) internal {
        _replaceFacet(facetAddress_, LibVaultFacetSelectors.vaultAsyncHostCoreSelectors());
    }

    function _replaceControlsFacet(address facetAddress_) internal {
        _replaceFacet(facetAddress_, LibVaultFacetSelectors.vaultControlsSelectors());
    }

    function _replaceIntegrationFacet(address facetAddress_) internal {
        _replaceFacet(facetAddress_, LibVaultFacetSelectors.vaultIntegrationSelectors());
    }

    function _addCoreReplacementMarker(address facetAddress_) internal {
        _addFacet(facetAddress_, _markerSelectors());
    }

    function _addControlsReplacementMarker(address facetAddress_) internal {
        _addFacet(facetAddress_, _markerSelectors());
    }

    function _addIntegrationReplacementMarker(address facetAddress_) internal {
        _addFacet(facetAddress_, _markerSelectors());
    }

    function _removeCoreFacetWithMarker() internal {
        _removeSelectors(_concat(LibVaultFacetSelectors.vaultAsyncHostCoreSelectors(), _markerSelectors()));
    }

    function _removeControlsFacetWithMarker() internal {
        _removeSelectors(_concat(LibVaultFacetSelectors.vaultControlsSelectors(), _markerSelectors()));
    }

    function _removeIntegrationFacetWithMarker() internal {
        _removeSelectors(_concat(LibVaultFacetSelectors.vaultIntegrationSelectors(), _markerSelectors()));
    }

    function _reAddCoreFacetWithMarker(address facetAddress_) internal {
        _addFacet(facetAddress_, _concat(LibVaultFacetSelectors.vaultAsyncHostCoreSelectors(), _markerSelectors()));
    }

    function _reAddControlsFacetWithMarker(address facetAddress_) internal {
        _addFacet(facetAddress_, _concat(LibVaultFacetSelectors.vaultControlsSelectors(), _markerSelectors()));
    }

    function _reAddIntegrationFacetWithMarker(address facetAddress_) internal {
        _addFacet(facetAddress_, _concat(LibVaultFacetSelectors.vaultIntegrationSelectors(), _markerSelectors()));
    }

    function _pauseVault() internal {
        VM.prank(admin);
        controlsFacetInterface().pause();
    }

    function _unpauseVault() internal {
        VM.prank(admin);
        controlsFacetInterface().unpause();
    }

    function _actor(uint8 seed) internal view returns (address) {
        return actors[uint256(seed) % ACTOR_COUNT];
    }

    function _actorExcluding(address excluded, uint8 seed) internal view returns (address actor) {
        actor = _actor(seed);
        if (actor == excluded) {
            actor = _actor(seed + 1);
        }
    }

    function _boundAmount(uint256 raw, uint256 max) internal pure returns (uint256) {
        if (max == 0) {
            return 0;
        }
        return (raw % max) + 1;
    }

    function _min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

    function _sumTrackedShareBalances() internal view returns (uint256 sum) {
        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            sum += coreFacetInterface().balanceOf(actors[i]);
        }
    }

    function _sumTrackedUnderlying() internal view returns (uint256 sum) {
        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            sum += asset.balanceOf(actors[i]);
        }

        sum += asset.balanceOf(address(diamond));
        sum += asset.balanceOf(feeSink);
        sum += asset.balanceOf(address(strategyContract));
        sum += asset.balanceOf(profitSource);
        sum += asset.balanceOf(strategyContract.lossSink());
    }

    function _snapshotAccounting() internal view returns (AccountingSnapshot memory snapshot) {
        snapshot.totalAssets = coreFacetInterface().totalAssets();
        snapshot.totalSupply = coreFacetInterface().totalSupply();
        snapshot.vaultUnderlyingBalance = asset.balanceOf(address(diamond));
        snapshot.feeSinkBalance = asset.balanceOf(feeSink);
        snapshot.strategyUnderlyingBalance = asset.balanceOf(address(strategyContract));
        snapshot.profitSourceBalance = asset.balanceOf(profitSource);
        snapshot.lossSinkBalance = asset.balanceOf(strategyContract.lossSink());
        snapshot.strategyDebt = integrationFacetInterface().strategyDebt();
        snapshot.liveStrategyAssets = integrationFacetInterface().liveStrategyAssets();

        for (uint256 i = 0; i < ACTOR_COUNT; i++) {
            snapshot.actorUnderlyingBalanceSum += asset.balanceOf(actors[i]);
            snapshot.actorShareBalanceSum += coreFacetInterface().balanceOf(actors[i]);
        }
    }

    function _assertAccountingUnchanged(AccountingSnapshot memory snapshot, string memory reason) internal view {
        AccountingSnapshot memory afterSnapshot = _snapshotAccounting();
        assertTrue(afterSnapshot.totalAssets == snapshot.totalAssets, reason);
        assertTrue(afterSnapshot.totalSupply == snapshot.totalSupply, reason);
        assertTrue(afterSnapshot.vaultUnderlyingBalance == snapshot.vaultUnderlyingBalance, reason);
        assertTrue(afterSnapshot.feeSinkBalance == snapshot.feeSinkBalance, reason);
        assertTrue(afterSnapshot.actorUnderlyingBalanceSum == snapshot.actorUnderlyingBalanceSum, reason);
        assertTrue(afterSnapshot.actorShareBalanceSum == snapshot.actorShareBalanceSum, reason);
        assertTrue(afterSnapshot.strategyUnderlyingBalance == snapshot.strategyUnderlyingBalance, reason);
        assertTrue(afterSnapshot.profitSourceBalance == snapshot.profitSourceBalance, reason);
        assertTrue(afterSnapshot.lossSinkBalance == snapshot.lossSinkBalance, reason);
        assertTrue(afterSnapshot.strategyDebt == snapshot.strategyDebt, reason);
        assertTrue(afterSnapshot.liveStrategyAssets == snapshot.liveStrategyAssets, reason);
    }

    function _snapshotStrategyState() internal view returns (StrategyStateSnapshot memory snapshot) {
        snapshot.strategy = integrationFacetInterface().strategy();
        snapshot.strategyDebt = integrationFacetInterface().strategyDebt();
        snapshot.liveStrategyAssets = integrationFacetInterface().liveStrategyAssets();
        snapshot.idleAssets = integrationFacetInterface().idleAssets();
        snapshot.emergencyExit = integrationFacetInterface().strategyEmergencyExit();
        snapshot.totalManagedAssets = coreFacetInterface().totalManagedAssets();
        snapshot.totalAssets = coreFacetInterface().totalAssets();
        snapshot.bobMaxWithdraw = coreFacetInterface().maxWithdraw(bob);
        snapshot.bobMaxRedeem = coreFacetInterface().maxRedeem(bob);
    }

    function _assertStrategyState(StrategyStateSnapshot memory snapshot) internal view {
        assertTrue(integrationFacetInterface().strategy() == snapshot.strategy, "strategy mismatch");
        assertTrue(integrationFacetInterface().strategyDebt() == snapshot.strategyDebt, "strategy debt mismatch");
        assertTrue(
            integrationFacetInterface().liveStrategyAssets() == snapshot.liveStrategyAssets,
            "live strategy assets mismatch"
        );
        assertTrue(integrationFacetInterface().idleAssets() == snapshot.idleAssets, "idle assets mismatch");
        assertTrue(
            integrationFacetInterface().strategyEmergencyExit() == snapshot.emergencyExit, "emergency exit mismatch"
        );
        assertTrue(
            coreFacetInterface().totalManagedAssets() == snapshot.totalManagedAssets, "totalManagedAssets mismatch"
        );
        assertTrue(coreFacetInterface().totalAssets() == snapshot.totalAssets, "totalAssets mismatch");
        assertTrue(coreFacetInterface().maxWithdraw(bob) == snapshot.bobMaxWithdraw, "bob maxWithdraw mismatch");
        assertTrue(coreFacetInterface().maxRedeem(bob) == snapshot.bobMaxRedeem, "bob maxRedeem mismatch");
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
        assertFalse(success, reason);
    }

    function _markerSelectors() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](1);
        selectors[0] = IFacetVersionMarker.facetVersion.selector;
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
}
