<p align="center">
  <img src="docs/assets/auralis-logo.svg" alt="Auralis logo" width="140" />
</p>

# Auralis

![Solidity](https://img.shields.io/badge/Solidity-0.8.30-363636?logo=solidity)
[![Foundry CI](https://github.com/amshirif/Auralis/actions/workflows/ci.yml/badge.svg)](https://github.com/amshirif/Auralis/actions/workflows/ci.yml)
![License](https://img.shields.io/github/license/amshirif/Auralis)

Security-first, diamond-ready Solidity systems.

`Auralis` is a portfolio-focused Solidity repository built to show
security-first protocol engineering, dependency-light design, and
deployment-backed validation. The codebase is intentionally diamond-ready, so
core modules can evolve into facetized systems without rewriting storage or
control-plane assumptions.

## Why This Repo Exists

This repo is meant to demonstrate more than isolated contract snippets. It
shows how access control, guard rails, oracle safety, vault logic, diamond
routing, deployment scripts, rehearsal flows, and CI checks fit together as a
reviewable engineering system.

## What It Currently Demonstrates

- A security-first control plane with RBAC, time-based permissions,
  pausability, reentrancy protection, and upgrade guardrails.
- Oracle safety patterns including validation bounds, stale-data handling,
  circuit breakers, and controlled fallback behavior.
- A diamond core with selector routing, cut/loupe support, ownership
  introspection, and selector-integrity regression coverage.
- Hosted ERC20 and ERC721 token facets deployed behind separate diamond hosts,
  with init, selector ownership, Permit/metadata support, and host-level
  hardening coverage.
- A hosted ERC-4626 vault platform deployed behind a diamond host, split across
  core, controls, and integration facets with active strategy lifecycle
  management, live strategy-aware accounting, loss-aware withdrawals,
  emergency-exit safety, deployment-backed init, and diamond-routed hardening
  plus invariant coverage.
- Operational maturity through local bootstrap, smoke validation, upgrade
  rehearsal, system-hardening flows, and matching CI gates.
- A local Auralis workflow for full-stack bootstrap, smoke checks, simulated
  activity, reset flows, and unified deployment artifacts.

## Current Status

Implemented milestones so far:

- Access Control + Upgrade Safety Kit
- Oracle Adapter + Circuit Breaker
- Diamond Core (EIP-2535)
- System-Level Testing & Hardening
- Diamond Token Facets
- Diamond-Hosted Vault Platform
- Auralis Launch Readiness
- Strategy / Yield Abstraction

## Validation

Run the highest-signal local checks with:

```shell
forge test --offline
bash script/run-local-diamond-smoke.sh
bash script/run-local-diamond-upgrade-rehearsal.sh
bash script/run-local-system-hardening.sh
```

For the local Auralis workflow:

```shell
bash scripts/auralis-up.sh
bash scripts/auralis-smoke.sh
bash scripts/auralis-activity.sh
bash scripts/auralis-reset.sh
```

## Documentation

Architecture and module docs live in `docs/diamond-core.md`,
`docs/oracle-adapter.md`, `docs/erc4626-vault.md`, `docs/vault-facets.md`,
`docs/token-facets.md`, and `docs/threat-model.md`.

Operational guidance lives in `docs/ops/README.md`, with the end-to-end
execution order collected in `docs/ops/runbook-system-hardening.md`.

CI and local validation parity are documented in `docs/security-checks.md`.

Token-host architecture and safety assumptions live in `docs/token-facets.md`,
including the init model, selector ownership rules, separate-host deployment
constraint, and token-host upgrade assumptions.

Hosted-vault architecture and safety assumptions live in
`docs/vault-facets.md`, including the init model, selector ownership split,
live strategy lifecycle, accounting model, emergency-exit behavior, deployment
references, and hosted-vault upgrade assumptions.

Local Auralis bootstrap, smoke, simulated activity, reset flow, and artifact
layout are documented in `docs/auralis-local.md`.

## Tooling

Built with Foundry. CI workflows live under `.github/workflows/`.

Foundry docs: [book.getfoundry.sh](https://book.getfoundry.sh/)

## AI Usage

AI assistance was used for tests, documentation, scripts, planning support.

The protocol architecture, technical decisions, and final review/integration of
changes were directed and owned by me.
