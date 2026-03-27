# Diamond Vault Facets

This document is the canonical guide for the hosted vault model implemented in
the `Diamond-Hosted Vault Platform` milestone.

It covers the supported diamond-hosted vault deployment:

- one diamond
- one `ERC4626VaultFacet`
- one `ERC4626VaultControlsFacet`
- one `ERC4626VaultIntegrationFacet`

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
- strategy reference
- strategy report hook
- `idleAssets()`
- `estimatedTotalManagedAssets()`
- `oracleQuote()`

## Initialization Model

The hosted vault uses one initializer on the core facet only.

Initialization sequence:

1. Install loupe selectors.
2. Install the core, controls, and integration selector groups.
3. Call
   `initializeVault(address vaultAsset, string vaultName, string vaultSymbol, address admin)`
   through the diamond.
4. Optionally call `setOracleAdapter(address newAdapter)` through the
   integration facet.

Initialization behavior:

- `initializeVault(...)` initializes vault storage and shared control storage.
- `DEFAULT_ADMIN_ROLE`, `PAUSER_ROLE`, and `VAULT_MANAGER_ROLE` are granted to
  `admin`.
- `feeRecipient` defaults to `admin` at initialization.
- `ERC4626VaultControlsFacet` has no independent initializer.
- `ERC4626VaultIntegrationFacet` has no independent initializer.
- a second call to `initializeVault(...)` reverts.

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
- manager-authorized `reportStrategyAssets(...)`

If a strategy is configured, the strategy address may also call
`reportStrategyAssets(...)`.

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

## Integration Behavior

The integration facet is config/report infrastructure, not an active strategy
engine.

Oracle behavior:

- the oracle adapter is an external contract reference
- the reference host deployment wires it after vault initialization
- `oracleQuote()` reads through the configured adapter

Strategy behavior:

- `setStrategy(...)` stores a configured strategy reference
- `reportStrategyAssets(...)` updates an advisory reported amount
- `strategyReportedAssets` does not mutate core ERC-4626 liquidity accounting

Asset helpers:

- `idleAssets()` returns the underlying balance held directly by the vault
- `estimatedTotalManagedAssets()` returns
  `idleAssets() + strategyReportedAssets()`
- `totalManagedAssets()` and ERC-4626 preview/liquidity math continue to use the
  vault's managed accounting only

That means strategy reports are visible to operators and reviewers, but they do
not automatically change `withdraw`, `redeem`, preview math, or live liquidity
semantics in this milestone.

## Selector Ownership Model

For the supported hosted vault deployment:

- `diamondCut` is owned by `DiamondCutFacet`
- loupe and ownership-introspection selectors are owned by
  `DiamondLoupeFacet`
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

Hosted vault state lives in the diamond, not in the facet bytecode.

Supported replace/remove/re-add flows assume:

- replacement facets preserve the same storage layout
- selectors are restored before the corresponding surface is expected to route
- no re-initialization is performed during upgrades

Current hardening coverage explicitly validates persistence for:

- vault metadata and ERC-4626/share-token state
- fee config, limit config, roles, role windows, and pause state
- oracle adapter, strategy reference, and reported strategy assets

## Deployment References

Reference local deployment flow:

- `script/DeployDiamondVaultHost.s.sol`

Reference local artifact:

- `deployments/diamond-vault.local.json`

The reference deployment:

- installs loupe, core, controls, and integration selectors
- initializes the vault through the core facet
- wires the oracle adapter through the integration facet
- leaves `strategy == address(0)` and `strategyReportedAssets == 0`

## Validation References

The hosted vault model is covered by:

- `test/DiamondVaultDeploymentIntegration.t.sol`
- `test/DiamondVaultHostHardening.t.sol`
- `test/DiamondVaultHostInvariant.t.sol`
