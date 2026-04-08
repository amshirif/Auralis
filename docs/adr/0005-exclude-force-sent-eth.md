# ADR 0005: Exclude force-sent ETH from managed accounting and pricing

## Status

Accepted

## Context

Native-asset hosts can receive ETH outside the intended control flow through
`selfdestruct` or other forced-send patterns. If that surplus is treated as
managed capital automatically, pricing, limits, and withdrawals can become
misleading or manipulable.

## Decision

Exclude force-sent ETH from managed accounting and pricing by default.

Raw native surplus may improve immediate exit liquidity in some cases, but it is
not treated as managed vault assets for pricing, accounting, or share issuance.

## Consequences

- Forced ETH cannot inflate share price or mint pricing.
- Native liquidity checks must distinguish between immediate raw balance and
  tracked managed assets.
- Reviewers must treat force-sent surplus as untracked balance, not protocol
  yield.
- Reconciliation, if ever desired, must be explicit rather than automatic.

## Related Docs/Tests

- `docs/erc4626-vault.md`
- `docs/threat-model.md`
- `test/DiamondNativeVaultHostInvariant.t.sol`
- `test/DiamondNativeVaultHostHardening.t.sol`
