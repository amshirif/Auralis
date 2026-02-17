# Runbook: Pause and Unpause

Use this runbook for operational containment using global or scoped pauses.

## Relevant Controls

- `pause()` / `unpause()` require `PAUSER_ROLE`.
- `pauseScope(bytes32)` / `unpauseScope(bytes32)` require `PAUSER_ROLE`.
- Global pause overrides all scoped pause checks.

## Decision Guide

- Use global pause when blast radius is unclear or cross-module.
- Use scoped pause when impact is isolated to a known scope.

## Emergency Pause Procedure

1. Confirm incident and affected module/scope.
2. Choose containment mode:
  - global: call `pause()`
  - scoped: call `pauseScope(scope)`
3. Verify enforcement by exercising a protected path expected to revert.
4. Record:
  - actor
  - timestamp
  - scope/global decision
  - reason

## Unpause Procedure

1. Confirm mitigation is complete.
2. Validate that unsafe condition is no longer present.
3. Unpause in reverse order:
  - scoped: call `unpauseScope(scope)`
  - global: call `unpause()`
4. Verify normal behavior on previously paused paths.

## Safety Notes

- Do not unpause on partial diagnosis.
- Prefer phased scope unpausing before global unpausing in uncertain recoveries.
- Keep a short post-incident report with timeline and remediation details.
