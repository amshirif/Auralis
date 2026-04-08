<p align="center">
  <img src="docs/assets/auralis-logo.svg" alt="Auralis logo" width="140" />
</p>

# Auralis

![Solidity](https://img.shields.io/badge/Solidity-0.8.30-363636?logo=solidity)
[![Foundry CI](https://github.com/amshirif/Auralis/actions/workflows/ci.yml/badge.svg)](https://github.com/amshirif/Auralis/actions/workflows/ci.yml)
![License](https://img.shields.io/github/license/amshirif/Auralis)

Security-first, diamond-ready Solidity systems.

`Auralis` is a protocol-engineering portfolio repository focused on
security-first, upgrade-aware Solidity systems. It combines modular contract
design, deployment-backed validation, local operator flows, and hardening
coverage so a reviewer can assess architecture and evidence together rather
than as isolated snippets.

## Why This Repo Exists

This repo is meant to demonstrate more than isolated contract snippets. It
shows how access control, guard rails, oracle safety, vault logic, diamond
routing, deployment scripts, rehearsal flows, and CI checks fit together as a
reviewable engineering system.

## Review In 5 Minutes

- Architecture decisions: `docs/adr/README.md`
- Canonical docs map: `docs/README.md`
- Hosted vault architecture: `docs/vault-facets.md`
- Security assumptions: `docs/threat-model.md`
- Validation and CI policy: `docs/security-checks.md`
- Local workflow and deployment artifacts: `docs/auralis-local.md`

## What This Repo Proves

- Core architecture: diamond routing, selector ownership discipline, and
  separate hosted token and vault deployment models.
- Safety posture: RBAC, timed permissions, pause semantics, reentrancy
  protection, oracle validation, and upgrade guardrails.
- Protocol surfaces: ERC20 and ERC721 token hosts plus a hosted ERC-4626 vault
  platform with controls, strategy integration, and native-asset support.
- Operational maturity: local bootstrap, smoke validation, activity flows,
  upgrade rehearsal, and matching CI/hardening gates.

## Evidence

### Architecture And Design

- `docs/adr/README.md`: accepted architecture decisions and why the repo is
  shaped this way.
- `docs/diamond-core.md`: diamond routing, cut flow, selector ownership, and
  storage discipline.
- `docs/vault-facets.md`: hosted vault facet split, lifecycle, and deployment
  model.
- `docs/threat-model.md`: trust boundaries, threat assumptions, and residual
  risks.

### Validation

- `test/DiamondSelectorIntegrityCore.t.sol`: selector routing and loupe
  integrity regressions.
- `test/DiamondVaultDeploymentIntegration.t.sol`: hosted vault deployment,
  init, selector ownership, and oracle wiring.
- `test/DiamondVaultHostHardening.t.sol`: replace/remove/re-add hardening
  across the hosted vault diamond path.
- `test/DiamondTokenDeploymentIntegration.t.sol`: ERC20 and ERC721 host
  deployment and selector ownership.
- `test/SystemOracleFailureScenarios.t.sol`: stale-data, breaker, fallback, and
  recovery behavior.
- `test/SystemVaultStressInvariant.t.sol`: higher-signal system stress coverage
  for vault behavior under adversarial sequences.

### Deployment And Operator Evidence

- `docs/security-checks.md`: current CI policy and local reproduction path.
- `docs/ops/README.md`: operator runbooks and validation flows.
- `docs/auralis-local.md`: local bootstrap, smoke, activity, reset, and
  artifact layout.

## Validation Path

Run a bounded reviewer-facing path with:

```shell
forge fmt --check
forge build --sizes --skip script
forge test --offline --match-path test/DiamondSelectorIntegrityCore.t.sol
forge test --offline --match-path test/DiamondVaultDeploymentIntegration.t.sol
forge test --offline --match-path test/DiamondVaultHostHardening.t.sol
forge test --offline --match-path test/DiamondTokenDeploymentIntegration.t.sol
forge test --offline --match-path test/SystemOracleFailureScenarios.t.sol
forge test --offline --match-path test/SystemVaultStressInvariant.t.sol
```

For the local Auralis workflow:

```shell
bash scripts/auralis-up.sh
bash scripts/auralis-smoke.sh
bash scripts/auralis-reset.sh
```

## Documentation

Start with `docs/README.md` for the canonical docs map.

Recommended reviewer path:

- Architecture decisions: `docs/adr/README.md`
- Core architecture: `docs/diamond-core.md`, `docs/token-facets.md`,
  `docs/vault-facets.md`, `docs/oracle-adapter.md`
- Security and validation: `docs/threat-model.md`, `docs/security-checks.md`
- Operations and local workflow: `docs/ops/README.md`, `docs/auralis-local.md`

## Tooling

Built with Foundry. CI workflows live under `.github/workflows/`.

Foundry docs: [book.getfoundry.sh](https://book.getfoundry.sh/)

## AI Usage

AI assistance was used for tests, documentation, scripts, planning support.

The protocol architecture, technical decisions, and final review/integration of
changes were directed and owned by me.
