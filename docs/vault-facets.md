# Diamond Vault Facets

This document is the canonical guide for the hosted vault model implemented in
Auralis.

It covers the supported diamond-hosted vault deployment:

- one diamond
- one `ERC4626VaultFacet`
- one `ERC4626VaultControlsFacet`
- one `ERC4626VaultIntegrationFacet`
- one active strategy per vault

For the standalone ERC-4626 module behavior and math reference, see
`docs/erc4626-vault.md`.

## Supported Host Model

The hosted vault diamond preserves a split between user-facing vault flows,
control-plane selectors, and integration/config selectors.

### Core Facet

`ERC4626VaultFacet` owns the ERC-4626/share-token selector group:

- vault initialization
- share metadata and share-token flows
- `deposit`, `mint`, `withdraw`, `redeem`
- conversion, preview, and `max*` helpers
- `asset()` and `totalManagedAssets()`

The core facet also owns runtime liquidity sourcing for user withdrawals and
redemptions. When idle vault liquidity is insufficient, it will pull
immediately withdrawable assets from the configured strategy before finishing
`withdraw` or `redeem`.

### Controls Facet

`ERC4626VaultControlsFacet` owns the control-plane selector group:

- fee config and limit config
- access control and time-window role selectors
- global and scoped pause selectors
- reentrancy introspection
- `supportsInterface(bytes4)`

### Integration Facet

`ERC4626VaultIntegrationFacet` owns the integration/config selector group:

- oracle adapter reference
- strategy reference and emergency-exit state
- strategy lifecycle methods
- `idleAssets()`
- `liveStrategyAssets()`
- `strategyDebt()`
- `oracleQuote()`

The integration facet is the manager-facing strategy surface. It does not own
vault initialization and it does not own user ERC-4626 entrypoints.

## Initialization And Deployment Model

The hosted vault uses one initializer on the core facet only.

Initialization sequence:

1. Install loupe selectors.
2. Install the core, controls, and integration selector groups.
3. Call
   `initializeVault(address vaultAsset, string vaultName, string vaultSymbol, address admin)`
   through the diamond.
4. Call `setOracleAdapter(address newAdapter)` through the integration facet.
5. Call `setStrategy(address newStrategy)` through the integration facet.

Initialization behavior:

- `initializeVault(...)` initializes vault storage and shared control storage.
- `DEFAULT_ADMIN_ROLE`, `PAUSER_ROLE`, and `VAULT_MANAGER_ROLE` are granted to
  `admin`.
- `feeRecipient` defaults to `admin` at initialization.
- `ERC4626VaultControlsFacet` has no independent initializer.
- `ERC4626VaultIntegrationFacet` has no independent initializer.
- a second call to `initializeVault(...)` reverts.

The local reference deployment in `script/DeployDiamondVaultHost.s.sol` wires a
vault-bound, asset-bound strategy by default. It leaves the vault in a ready
state with:

- `strategy()` configured
- `strategyDebt() == 0`
- `liveStrategyAssets() == 0`
- `strategyEmergencyExit() == false`

No funds are deployed to strategy during deployment.

## Role Model And Pause Behavior

Hosted vault facets reuse the shared control plane.

### Roles

- `DEFAULT_ADMIN_ROLE`
- `PAUSER_ROLE`
- `VAULT_MANAGER_ROLE`

`VAULT_MANAGER_ROLE` is used for:

- `setFeeConfig(...)`
- `setLimitConfig(...)`
- `setOracleAdapter(...)`
- `setStrategy(...)`
- `deployToStrategy(...)`
- `withdrawFromStrategy(...)`
- `syncStrategyAssets()`
- `emergencyExitStrategy()`

### Pause Behavior

The hosted vault currently uses a global pause model for vault entrypoints.

Global pause blocks:

- `deposit`
- `mint`
- `withdraw`
- `redeem`

Global pause does not block share-token flows:

- `approve`
- `transfer`
- `transferFrom`

Scoped pause selectors still route through the controls facet, but the hosted
vault does not currently use per-scope pause behavior for ERC-4626 entrypoints.

## Strategy Model

The hosted vault strategy model is intentionally narrow:

- one active strategy per vault
- single-asset only
- strategy instance is vault-bound and asset-bound
- no allocator or multi-strategy routing
- no async withdrawal queue
- no automatic harvest or keeper loop

A strategy must satisfy `IERC4626VaultStrategy` and report:

- `vault() == address(diamond)`
- `asset() == asset()`

`setStrategy(...)` validates those bindings and requires `strategyDebt() == 0`
before a strategy can be cleared or replaced.

### Lifecycle Surface

Manager lifecycle methods live on the integration facet:

- `setStrategy(address)`
- `deployToStrategy(uint256)`
- `withdrawFromStrategy(uint256)`
- `syncStrategyAssets()`
- `emergencyExitStrategy()`

Behavior:

- `deployToStrategy(...)` moves idle assets from the vault into strategy and
  increases `strategyDebt()` by the deployed amount.
- `withdrawFromStrategy(...)` pulls assets back from strategy, may return less
  than requested, and realizes any gain or loss into book value.
- `syncStrategyAssets()` realizes mark-to-market strategy profit or loss into
  book value without moving idle assets.
- `emergencyExitStrategy()` sets the sticky emergency-exit flag before trying a
  full unwind.

Emergency exit is one-way for the current strategy instance:

- once emergency exit is active, new deploys are blocked
- if unwind succeeds, debt is reconciled down to the remaining live strategy
  assets
- if unwind reverts, emergency exit stays active and the call does not revert
- to resume deploying, the manager must get debt to zero and then clear or
  replace the strategy

## Accounting Model

The hosted vault separates book accounting from live pricing.

Book accounting:

- `totalManagedAssets()` is the vault's stored book value
- `strategyDebt()` is the book debt allocated to the configured strategy
- `idleAssets()` is the underlying currently held by the vault

Live pricing:

- `liveStrategyAssets()` is the strategy's current mark-to-market value
- hosted `totalAssets()` is priced as:
  `idleAssets() + liveStrategyAssets()`

Operationally:

- after deploys, book value stays constant and debt increases
- after manager pulls, syncs, or emergency exit, realized profit or loss is
  written into `totalManagedAssets()` and `strategyDebt()` is updated to the
  post-operation live strategy assets
- when no strategy is configured or debt is zero, hosted pricing collapses back
  to idle vault assets

This means the hosted vault uses live strategy pricing for ERC-4626 conversions
while still keeping explicit book accounting for deployed debt.

## User-Facing Withdraw And Redeem Semantics

`withdraw(assets)` and `redeem(shares)` remain core-facet entrypoints, but they
are strategy-aware.

### `withdraw(assets)`

- exact-assets semantics are preserved
- if idle vault assets are insufficient, the core facet automatically pulls
  immediately withdrawable strategy liquidity
- if the requested assets still cannot be sourced after realizing any loss, the
  call reverts

### `redeem(shares)`

- exact-shares semantics are preserved
- the vault burns the requested shares and returns the current post-loss asset
  value of those shares
- if strategy liquidity must be sourced first, the vault pulls it before final
  asset calculation and transfer

### `max*` Helpers

- `maxDeposit()` and `maxMint()` remain strategy-aware through live `totalAssets()`
  pricing and limit shaping
- `maxWithdraw()` and `maxRedeem()` are bounded by immediate liquidity, not by
  total mark-to-market assets alone
- `maxWithdraw()` and `maxRedeem()` are zero when `totalAssets() == 0`, even if
  residual dust shares still exist after a full loss event

## Selector Ownership Model

For the supported hosted vault deployment:

- `diamondCut` is owned by `DiamondCutFacet`
- loupe and ownership-introspection selectors are owned by `DiamondLoupeFacet`
- core selectors are owned by `ERC4626VaultFacet`
- controls selectors and `supportsInterface(bytes4)` are owned by
  `ERC4626VaultControlsFacet`
- integration selectors are owned by `ERC4626VaultIntegrationFacet`

One important implication:

- support for `IERC4626VaultFacet` and `IERC4626VaultIntegrationFacet` is
  reported through the controls facet
- those interface IDs are only reported when the corresponding core or
  integration selectors are installed

## Storage And Upgrade Assumptions

Hosted vault state lives in the diamond, not in facet bytecode.

Supported replace/remove/re-add flows assume:

- replacement facets preserve the same storage layout
- selectors are restored before the corresponding surface is expected to route
- no re-initialization is performed during upgrades

Current hardening coverage explicitly validates persistence for:

- vault metadata and ERC-4626/share-token state
- fee config, limit config, roles, role windows, and pause state
- oracle adapter, strategy address, strategy debt, live strategy assets, and
  emergency-exit state

## Deployment References

Reference local deployment flow:

- `script/DeployDiamondVaultHost.s.sol`

Reference deployment-backed validation:

- `test/DiamondVaultDeploymentIntegration.t.sol`
- `test/ERC4626VaultIntegrationFacetCore.t.sol`
- `test/ERC4626VaultStrategyAccountingCore.t.sol`
- `test/VaultStrategyFoundationCore.t.sol`
- `test/DiamondVaultHostHardening.t.sol`
- `test/DiamondVaultHostInvariant.t.sol`

## Out Of Scope

The current hosted strategy model does not include:

- multi-strategy allocation
- async or queued withdrawals
- automatic harvest or keeper-driven execution
- extension-standard work deferred to `#24 Advanced Extensions`
