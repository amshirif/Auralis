# Security Checks

This repository runs security-focused CI checks in addition to baseline Foundry checks.

## CI Policy

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
