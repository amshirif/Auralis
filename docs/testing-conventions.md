# Testing Conventions

Use a split test layout so modules stay readable as complexity grows.

## File Layout

- `test/<Module>Core.t.sol`
- `test/<Module>Time.t.sol` (only when time-window behavior exists)
- `test/<Module>Fuzz.t.sol` (for property/fuzz coverage)
- `test/<Module>Integration.t.sol` (optional, cross-module workflows)
- `test/helpers/<Module>TestHarness.sol`

## Responsibilities

- `Core`: role checks, permissions, initialization, enumeration, idempotency.
- `Time`: schedule/window logic, boundary timestamps, active/inactive checks.
- `Integration`: interactions between modules and end-to-end flows.
- `Fuzz`: property-style checks across random inputs and edge value ranges.
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
- Add explicit event assertion tests for every emitted event.
- Prefer deterministic timestamps (`vm.warp`) for time-based tests.
- Keep fuzz assertions invariant-oriented (state/permission properties, not exact gas values).

## Current Reference

- Core example: `test/AccessControlCore.t.sol`
- Core example: `test/PausableCore.t.sol`
- Core example: `test/ReentrancyGuardCore.t.sol`
- Core example: `test/OracleAdapterCore.t.sol`
- Core example: `test/OracleAdapterValidation.t.sol`
- Core example: `test/OracleAdapterCircuitBreaker.t.sol`
- Core example: `test/UpgradeGuardrailsCore.t.sol`
- Core example: `test/ERC4626VaultFoundationCore.t.sol`
- Core example: `test/ERC4626Core.t.sol`
- Fuzz example: `test/AccessControlFuzz.t.sol`
- Fuzz example: `test/OracleAdapterFuzz.t.sol`
- Fuzz example: `test/PausableFuzz.t.sol`
- Fuzz example: `test/UpgradeGuardrailsFuzz.t.sol`
- Time example: `test/AccessControlTime.t.sol`
- Time example: `test/UpgradeGuardrailsTime.t.sol`
- Helper example: `test/helpers/AccessControlTestHarness.sol`
- Helper example: `test/helpers/PausableTestHarness.sol`
- Helper example: `test/helpers/OracleAdapterTestHarness.sol`
- Helper example: `test/helpers/ReentrancyGuardTestHarness.sol`
- Helper example: `test/helpers/UpgradeGuardrailsTestHarness.sol`
- Helper example: `test/helpers/ERC4626VaultTestHarness.sol`
- Helper example: `test/helpers/ERC4626CoreTestHarness.sol`
