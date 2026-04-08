# Security Checks

This repository runs security-focused CI checks in addition to baseline Foundry checks.

## CI Policy

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
- Scope: contract/static analysis findings are printed in CI logs.

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

The hosted vault now has matching deployment, strategy lifecycle, hardening,
and invariant coverage for the supported three-facet vault host with one active
strategy per vault:

```bash
forge test --offline --match-path test/DiamondVaultDeploymentIntegration.t.sol
forge test --offline --match-path test/ERC4626VaultIntegrationFacetCore.t.sol
forge test --offline --match-path test/ERC4626VaultStrategyAccountingCore.t.sol
forge test --offline --match-path test/VaultStrategyFoundationCore.t.sol
forge test --offline --match-path test/DiamondVaultHostHardening.t.sol
forge test --offline --match-path test/DiamondVaultHostInvariant.t.sol
```

Use these to reproduce hosted-vault deployment, strategy binding, live
strategy-aware accounting, loss and emergency-exit behavior, selector
ownership, facet replacement persistence, and diamond-routed vault invariants
locally.

### Slither

Install and run the same high-severity gate locally:

```bash
python3 -m pip install --upgrade pip slither-analyzer
slither . --exclude-dependencies --fail-on high
```

### Dependency Review

Equivalent local execution can be done via the workflow using [`act`](https://github.com/nektos/act):

```bash
act pull_request -W .github/workflows/dependency-review.yml
```

If `act` is unavailable, run the dependency review check in a draft PR before requesting final review.
