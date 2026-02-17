# Runbook: Oracle Incident

Use this runbook when live oracle reads are unhealthy or untrusted.

## Relevant Controls

- `tripCircuitBreaker()` requires `ORACLE_GUARDIAN_ROLE`.
- `resetCircuitBreaker()` requires `ORACLE_ADMIN_ROLE`.
- `setFallbackMode(...)` requires `ORACLE_ADMIN_ROLE`.
- `setFallbackQuote(...)` requires `ORACLE_ADMIN_ROLE`.
- `clearFallbackQuote()` requires `ORACLE_ADMIN_ROLE`.

## Incident Triggers

- feed call reverts or returns malformed payload
- stale or future timestamps
- invalid round consistency (`answeredInRound < roundId`)
- out-of-bounds answers when bounds are enabled

## Immediate Response

1. Confirm signal quality from monitoring and logs.
2. Trip breaker:
  - call `tripCircuitBreaker()`
3. Choose fallback policy:
  - strict safety: keep `FallbackMode.StrictRevert`
  - degraded operation: set `FallbackMode.UseConfiguredQuote`
4. If degraded operation is needed, set a vetted fallback:
  - call `setFallbackQuote(value, updatedAt, decimals)`

## Ongoing Management

- Reassess fallback quote freshness on a fixed cadence.
- Keep incident notes with:
  - trigger timestamp
  - account used for control actions
  - fallback quote source and rationale

## Recovery

1. Validate live feed health (round updates, timestamp freshness, value sanity).
2. If degraded mode was enabled, decide whether to keep or clear fallback quote.
3. Reset breaker:
  - call `resetCircuitBreaker()`
4. Confirm `quote()` returns expected live data.

## Post-Incident

- Document root cause and timeline.
- Record whether bounds, staleness window, or responder roles should be adjusted.
