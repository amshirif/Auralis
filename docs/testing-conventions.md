# Testing Conventions

Use a split test layout so modules stay readable as complexity grows.

## File Layout

- `test/<Module>Core.t.sol`
- `test/<Module>Time.t.sol` (only when time-window behavior exists)
- `test/<Module>Integration.t.sol` (optional, cross-module workflows)
- `test/helpers/<Module>TestHarness.sol`

## Responsibilities

- `Core`: role checks, permissions, initialization, enumeration, idempotency.
- `Time`: schedule/window logic, boundary timestamps, active/inactive checks.
- `Integration`: interactions between modules and end-to-end flows.
- `helpers`: shared fixture setup, actors, harness wrappers, and utility assertions.

## Naming

- Test contract names: `<Module>CoreTest`, `<Module>TimeTest`, `<Module>IntegrationTest`.
- Test function names should describe one behavior each, for example:
  - `testNonAdminCannotSetRoleWindow`
  - `testRoleWindowBoundariesAndOnlyActiveRole`
  - `testRoleAdminChange`

## Practical Rules

- Keep each test file focused on one concern.
- Move shared setup to `test/helpers` to avoid duplication.
- Add explicit boundary tests for any timestamp logic.
- Keep revert expectation tests close to the feature they validate.
- Prefer deterministic timestamps (`vm.warp`) for time-based tests.

## Current Reference

- Core example: `test/AccessControlCore.t.sol`
- Time example: `test/AccessControlTime.t.sol`
- Helper example: `test/helpers/AccessControlTestHarness.sol`
