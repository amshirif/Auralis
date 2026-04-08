# System Hardening

This note defines the reproducible system-level hardening coverage used in
`Auralis`.

For the operator-facing execution order and failure interpretation, see
`docs/ops/runbook-system-hardening.md`.

## What Is Simulated

- Local diamond bootstrap and smoke validation through the Foundry deployment
  flow.
- Local diamond upgrade rehearsal, including successful cuts, init-backed state
  checks, and failed-cut atomicity checks.
- Stateful vault stress coverage across deposit, mint, withdraw, redeem,
  pause/unpause, fee configuration, limit configuration, and reentrant asset
  callback attempts.
- Deterministic oracle incident handling across stale/invalid live reads,
  circuit-breaker trips, fallback-mode activation, reset/recovery, and source
  rotation.

## What Remains Out Of Scope

- Real market or economic attack simulation.
- Multisig or governance workflow simulation.
- External provider or network instability beyond deterministic mocked failure
  cases.
- Full protocol composition beyond the current toolkit modules.

## Reproducible Entry Points

Use these commands locally:

```bash
bash script/run-local-system-hardening.sh
forge test --offline --match-path test/SystemVaultStressInvariant.t.sol
forge test --offline --match-path test/SystemOracleFailureScenarios.t.sol
```

The top-level hardening runner passes only when the local deployment bootstrap,
smoke flow, upgrade rehearsal, failed-cut postconditions, and both new
system-level suites all succeed.
