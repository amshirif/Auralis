# Runbook: Upgrade Execution

Use this runbook for guarded upgrade operations.

## Relevant Controls

- `queueUpgradeIntent(address)` requires `UPGRADER_ROLE`.
- `cancelUpgradeIntent()` requires `UPGRADER_ROLE`.
- `executeUpgrade(address)` requires `UPGRADER_ROLE`.
- Guardrails enforce:
  - nonzero implementation
  - queued intent existence
  - implementation match
  - minimum delay (`minUpgradeDelay`)

## Pre-Queue Checklist

- Confirm implementation address is final and deployed.
- Confirm compatibility and migration assumptions.
- Confirm rollback or cancel path is clear.

## Execution Flow

1. Queue:
  - call `queueUpgradeIntent(implementation)`
2. Verify queued intent:
  - call `getUpgradeIntent()`
3. Wait until `executeAfter` is reached.
4. Execute:
  - call `executeUpgrade(implementation)`
5. Verify post-upgrade behavior and key invariants.

## Cancel Flow

- If any concern appears before execution:
  - call `cancelUpgradeIntent()`
- Re-queue only after updated review.

## Post-Execution Validation

- Confirm expected implementation is active (module-specific check).
- Run smoke checks on critical paths.
- Record:
  - queued by / executed by
  - queue and execution timestamps
  - validation results

## Failure Handling

- If `executeUpgrade` reverts:
  - inspect revert reason (not ready / mismatch / zero implementation / no intent)
  - do not force retries without diagnosing queue state
  - cancel and re-queue when needed
