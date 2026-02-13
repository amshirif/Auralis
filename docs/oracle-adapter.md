# Oracle Adapter

This module defines the oracle adapter foundation for the oracle milestone:
- provider-facing feed interface
- normalized quote read interface
- upgrade-safe storage layout and initializer guard

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
- max staleness config storage
- normalized quote read passthrough from source
- initializer guard for upgrade-safe deployments

Validation policy (staleness, bounds, and validity checks) is implemented in
the next issue (`#15`).

## Diamond-Ready Usage

When used behind a diamond proxy, call the internal initializer from a facet or
init contract:

```solidity
function initOracleAdapter(address source, uint64 maxStaleness) external {
    _initializeOracleAdapter(source, maxStaleness);
}
```

