<p align="center">
  <img src="docs/assets/keystone-logo.svg" alt="Keystone logo" width="140" />
</p>

# Keystone

![Solidity](https://img.shields.io/badge/Solidity-0.8.30-363636?logo=solidity)
[![Foundry CI](https://github.com/amshirif/smart-contracts/actions/workflows/ci.yml/badge.svg)](https://github.com/amshirif/smart-contracts/actions/workflows/ci.yml)
![License](https://img.shields.io/github/license/amshirif/smart-contracts)

Security-first, diamond-ready Solidity systems.

`Keystone` is a portfolio-focused Solidity repository built to show
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
- Operational maturity through local bootstrap, smoke validation, upgrade
  rehearsal, system-hardening flows, and matching CI gates.

## Current Status

Implemented milestones so far:

- Access Control + Upgrade Safety Kit
- Oracle Adapter + Circuit Breaker
- Diamond Core (EIP-2535)
- System-Level Testing & Hardening

## Validation

Run the highest-signal local checks with:

```shell
forge test --offline
bash script/run-local-diamond-smoke.sh
bash script/run-local-diamond-upgrade-rehearsal.sh
bash script/run-local-system-hardening.sh
```

## Documentation

Architecture and module docs live in `docs/diamond-core.md`,
`docs/oracle-adapter.md`, `docs/erc4626-vault.md`, `docs/token-facets.md`, and
`docs/threat-model.md`.

Operational guidance lives in `docs/ops/README.md`, with the end-to-end
execution order collected in `docs/ops/runbook-system-hardening.md`.

CI and local validation parity are documented in `docs/security-checks.md`.

## Tooling

Built with Foundry. CI workflows live under `.github/workflows/`.

Foundry docs: [book.getfoundry.sh](https://book.getfoundry.sh/)
