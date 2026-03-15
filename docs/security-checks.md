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
  - `Full Local Hardening Flow` runs on pushes to `main`/`milestone/**`, on manual dispatch, and on pull requests targeting `main` or `milestone/**`.
- Scope: deployment bootstrap, smoke flow, upgrade rehearsal, vault stress invariants, and oracle failure scenarios.

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
