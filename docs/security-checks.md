# Security Checks

This repository runs security-focused CI checks in addition to baseline Foundry checks.

## CI Policy

### Foundry CI (`.github/workflows/ci.yml`)

- Trigger: pull requests, pushes to `main` and `milestone/**`, manual dispatch.
- Tooling: GitHub Actions + Foundry.
- Policy:
  - `Foundry Fast PR Gate` runs formatting, `forge build --sizes --skip script`,
    and the current fast diamond-host and system suites.
  - `AMM Hardening` runs the standalone AMM fuzz, invariant, and hardening
    suites.
- AMM scope:
  - `forge test --offline --match-path test/AMMPairFuzz.t.sol`
  - `forge test --offline --match-path test/AMMRouterFuzz.t.sol`
  - `FOUNDRY_INVARIANT_RUNS=64 FOUNDRY_INVARIANT_DEPTH=32 forge test --offline --match-path test/AMMInvariant.t.sol`
  - `forge test --offline --match-path test/AMMHardening.t.sol`

### System Hardening (`.github/workflows/system-hardening.yml`)

- Trigger: pull requests, pushes to `main` and `milestone/**`, manual dispatch.
- Tooling: GitHub Actions + Foundry.
- Policy:
  - `Targeted System Suites` runs on every workflow trigger and executes:
    - `forge test --offline --match-path test/SystemVaultStressInvariant.t.sol`
    - `forge test --offline --match-path test/SystemOracleFailureScenarios.t.sol`
  - `Full Local Hardening Flow` runs on pushes to `main`/`milestone/**` and on
    manual dispatch.
- Scope: deployment bootstrap, smoke flow, upgrade rehearsal, vault stress invariants, and oracle failure scenarios.
- Operational execution order and local reproduction context:
  `docs/ops/runbook-system-hardening.md`

### Slither (`.github/workflows/slither.yml`)

- Trigger: pull requests, pushes to `main` and `milestone/**`, manual dispatch.
- Tooling: `crytic/slither-action`.
- Policy: fail when Slither reports **high-severity** findings (`fail-on: high`).
- Scope: contract/static analysis findings are printed in CI logs. The CI gate
  intentionally keeps the broader `crytic/slither-action` scope, while local
  triage can filter test and script findings to focus production closeout.

### Dependency Review (`.github/workflows/dependency-review.yml`)

- Trigger: pull requests, manual dispatch.
- Tooling: `actions/dependency-review-action`.
- Policy: fail on dependencies with **high** (or higher) known vulnerabilities.
- Private repository note:
  - Dependency review for private repositories may require additional GitHub security entitlement.
  - The workflow runs automatically on private repositories only when repository variable
    `ENABLE_PRIVATE_DEPENDENCY_REVIEW=true` is set.

## Local Reproduction

### System Hardening

Run the same bounded and full entrypoints locally:

```bash
forge test --offline --match-path test/SystemVaultStressInvariant.t.sol
forge test --offline --match-path test/SystemOracleFailureScenarios.t.sol
bash script/run-local-system-hardening.sh
```

Use the targeted suites for faster iteration and the full hardening runner for the same deployment-backed flow used by the higher-signal CI gate.

### Token Hosts

The token hosts have reviewer-facing validation suites for the separate
ERC20-host and ERC721-host deployment model:

```bash
forge test --offline --match-path test/DiamondTokenDeploymentIntegration.t.sol
forge test --offline --match-path test/DiamondTokenHostHardening.t.sol
forge test --offline --match-path test/DiamondErc20HostInvariant.t.sol
forge test --offline --match-path test/DiamondErc721HostInvariant.t.sol
```

Use these to reproduce token-host deployment, selector ownership, replace and
reinstall persistence, and diamond-routed invariant coverage locally.

### Hosted Vault

The hosted vault family now has matching deployment, strategy lifecycle,
async-request, hardening, and invariant coverage for the supported hosted vault
variants with one active strategy per vault:

```bash
forge test --offline --match-path test/DiamondVaultDeploymentIntegration.t.sol
forge test --offline --match-path test/ERC7540VaultFoundationCore.t.sol
forge test --offline --match-path test/ERC7540VaultDepositCore.t.sol
forge test --offline --match-path test/ERC7540VaultRedeemCore.t.sol
forge test --offline --match-path test/ERC7540VaultRequestAccountingInvariant.t.sol
forge test --offline --match-path test/ERC7540VaultDepositFuzz.t.sol
forge test --offline --match-path test/ERC7540VaultRedeemFuzz.t.sol
forge test --offline --match-path test/ERC7540VaultRequestTime.t.sol
forge test --offline --match-path test/ERC4626VaultIntegrationFacetCore.t.sol
forge test --offline --match-path test/ERC4626VaultStrategyAccountingCore.t.sol
forge test --offline --match-path test/VaultStrategyFoundationCore.t.sol
forge test --offline --match-path test/DiamondVaultHostHardening.t.sol
forge test --offline --match-path test/DiamondVaultHostInvariant.t.sol
```

Use these to reproduce hosted-vault deployment, strategy binding, live
strategy-aware accounting, async request lifecycle and settlement behavior,
controller/operator authorization, loss and emergency-exit behavior, selector
ownership, facet replacement persistence, and diamond-routed vault invariants
locally.

### Async Vault Requests

The ERC-7540 reviewer path is intentionally separate from the broader hosted
vault strategy suites:

```bash
forge test --offline --match-path test/ERC7540VaultFoundationCore.t.sol
forge test --offline --match-path test/ERC7540VaultDepositCore.t.sol
forge test --offline --match-path test/ERC7540VaultRedeemCore.t.sol
forge test --offline --match-path test/ERC7540VaultRequestAccountingInvariant.t.sol
forge test --offline --match-path test/ERC7540VaultDepositFuzz.t.sol
forge test --offline --match-path test/ERC7540VaultRedeemFuzz.t.sol
forge test --offline --match-path test/ERC7540VaultRequestTime.t.sol
forge test --offline --match-path test/DiamondVaultDeploymentIntegration.t.sol
forge test --offline --match-path test/DiamondVaultHostHardening.t.sol
forge test --offline --match-path test/DiamondVaultHostInvariant.t.sol
```

Use these when reviewing the aggregate request-id model, pending versus
claimable request buckets, manager settlement, controller/operator semantics,
settlement-scope pause behavior, async selector ownership, and strategy-aware
redeem claims.

### Standalone AMM

The standalone AMM track has a bounded reviewer path plus a separate hardening
gate in `Foundry CI`:

```bash
forge test --offline --match-path test/AMMFoundationCore.t.sol
forge test --offline --match-path test/AMMFactoryRegistry.t.sol
forge test --offline --match-path test/AMMPairCore.t.sol
forge test --offline --match-path test/AMMRouterCore.t.sol
forge test --offline --match-path test/AMMRouterTime.t.sol
forge test --offline --match-path test/AMMPairFuzz.t.sol
forge test --offline --match-path test/AMMRouterFuzz.t.sol
FOUNDRY_INVARIANT_RUNS=64 FOUNDRY_INVARIANT_DEPTH=32 forge test --offline --match-path test/AMMInvariant.t.sol
forge test --offline --match-path test/AMMHardening.t.sol
```

Use the first five suites when reviewing factory, pair, router, permit, and
wrapped-native behavior, then run the fuzz, invariant, and hardening suites for
the adversarial AMM surface.

### Multisig Wallet

The standalone wallet track has a bounded reviewer-facing suite set for
foundation, execution, batch/factory, management, and invariant coverage:

```bash
forge test --offline --match-path test/MultisigWalletFoundationCore.t.sol
forge test --offline --match-path test/MultisigWalletCoreExecution.t.sol
forge test --offline --match-path test/MultisigWalletIntegration.t.sol
forge test --offline --match-path test/MultisigWalletManagement.t.sol
forge test --offline --match-path test/MultisigWalletFuzz.t.sol
forge test --offline --match-path test/MultisigWalletInvariant.t.sol
```

Use these to reproduce initializer behavior, EIP-712 signing, ERC-1271
verification, deterministic clone deployment, call-only batch execution,
self-managed owner/threshold changes, and the wallet invariants around owner
uniqueness, threshold bounds, signature validity, signer ordering, and nonce
progression.

### Slither

Install and run the local high-severity triage gate:

```bash
python3 -m pip install --upgrade pip slither-analyzer
slither . --exclude-dependencies --fail-high --filter-paths 'test/|script/'
```

See [`../SLITHER_TRIAGE.md`](../SLITHER_TRIAGE.md) for the current accepted
medium, low, and informational detector families, the measured local baseline,
and the local-vs-CI scope difference.

### Dependency Review

Equivalent local execution can be done via the workflow using [`act`](https://github.com/nektos/act):

```bash
act pull_request -W .github/workflows/dependency-review.yml
```

If `act` is unavailable, run the dependency review check in a draft PR before requesting final review.
