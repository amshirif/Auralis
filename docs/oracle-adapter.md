# Oracle Adapter

This module provides a normalized oracle read surface with configurable
validation guardrails.

## Interfaces

- `IOracleFeed`: provider-facing feed reader (Chainlink-style round data).
- `IOracleAdapter`: normalized adapter API and base configuration surface.

`IOracleAdapter.OracleQuote` returns:
- `value`: signed raw feed value
- `updatedAt`: feed update timestamp (normalized to `uint64`)
- `decimals`: feed decimals

## Base Module Behavior

`OracleAdapter` currently provides:
- source address management
- max staleness policy (seconds)
- optional answer bounds policy (`minAnswer` / `maxAnswer`)
- normalized quote reads from source
- initializer guard for upgrade-safe deployments

Read validation checks enforced in `quote()`:
- `updatedAt` must fit in `uint64` and be nonzero.
- `updatedAt` cannot be in the future.
- quote must be within configured staleness threshold when `maxStaleness != 0`.
- round consistency requires `answeredInRound >= roundId`.
- answer must be within configured bounds when bounds are enabled.

Configuration notes:
- `setMaxStaleness(0)` disables staleness checks.
- bounds are disabled by default.
- bounds can be updated via `setValidationBounds(min, max, enabled)`.

All configuration changes emit events for auditability.

## Diamond-Ready Usage

When used behind a diamond proxy, call the internal initializer from a facet or
init contract:

```solidity
function initOracleAdapter(address source, uint64 maxStaleness) external {
    _initializeOracleAdapter(source, maxStaleness);
}
```

## Next Step

The circuit breaker / fallback policy is implemented separately so validation and
failover decisions remain explicit and testable.
