# Oracle Adapter

This module defines the oracle adapter and breaker controls for the oracle
milestone:
- provider-facing feed interface
- normalized quote read interface
- validation guardrails for live reads
- circuit breaker + fallback policy
- upgrade-safe storage layout and initializer guard

## Interfaces

- `IOracleFeed`: provider-facing feed reader (Chainlink-style round data).
- `IOracleAdapter`: normalized adapter API and configuration surface.

`IOracleAdapter.OracleQuote` returns:
- `value`: signed raw feed value
- `updatedAt`: feed update timestamp (normalized to `uint64`)
- `decimals`: feed decimals

## Base Module Behavior

`OracleAdapter` currently provides:
- source address management
- max staleness policy (seconds)
- optional answer bounds policy (`minAnswer` / `maxAnswer`)
- breaker state transitions (`trip` / `reset`)
- fallback policy:
  - `StrictRevert`: unhealthy reads revert
  - `UseConfiguredQuote`: unhealthy reads return configured fallback quote
- fallback quote management
- initializer guard for upgrade-safe deployments

Read validation checks enforced in strict mode:
- `updatedAt` must fit in `uint64` and be nonzero
- `updatedAt` cannot be in the future
- quote must be within configured staleness threshold when `maxStaleness != 0`
- round consistency requires `answeredInRound >= roundId`
- answer must be within configured bounds when bounds are enabled

Unhealthy read conditions include:
- source call failure
- malformed oracle responses
- zero/future/out-of-range timestamps
- stale quotes (when `maxStaleness != 0`)
- `answeredInRound < roundId`
- out-of-bounds answers (when bounds are enabled)

Configuration notes:
- `setMaxStaleness(0)` disables staleness checks
- bounds are disabled by default
- bounds can be updated via `setValidationBounds(min, max, enabled)`
- fallback mode defaults to `StrictRevert`
- fallback quote must be configured before using `UseConfiguredQuote`
- fallback usage during `quote()` is not emitted as an event because reads are `view`

## Diamond-Ready Usage

When used behind a diamond proxy, call the internal initializer from a facet or
init contract:

```solidity
function initOracleAdapter(address source, uint64 maxStaleness) external {
    _initializeOracleAdapter(source, maxStaleness);
}
```

## Operational Policy

- Use `tripCircuitBreaker()` during oracle incidents.
- Choose fallback behavior with `setFallbackMode(...)`.
- If using configured fallback mode, set a fallback quote first with
  `setFallbackQuote(...)`.
- Return to normal mode by fixing feed health and calling
  `resetCircuitBreaker()`.
