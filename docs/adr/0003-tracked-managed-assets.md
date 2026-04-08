# ADR 0003: Base hosted vault accounting on tracked managed assets

## Status

Accepted

## Context

Raw asset balances are not a safe source of truth for vault pricing. Direct
donations, accidental transfers, and raw native balance changes can distort
share pricing or liquidity calculations if conversion math reads underlying
balances directly.

## Decision

Base hosted vault accounting and pricing on tracked managed assets rather than
raw token or ETH balances.

The vault treats managed accounting as the source of truth for ERC-4626
conversions, previews, and share pricing. Raw balance reads are still useful
for immediate liquidity checks and operator visibility, but they do not define
pricing.

## Consequences

- Donation-style price manipulation is reduced because direct surplus does not
  automatically reprice shares.
- Strategy, native-asset, and emergency-liquidity logic must reconcile with
  managed accounting instead of assuming raw balance truth.
- Integrators and reviewers need to distinguish accounting state from idle
  balance state.
- Some flows become more explicit and less automatic, which is safer but less
  implicit than raw-balance-based vaults.

## Related Docs/Tests

- `docs/erc4626-vault.md`
- `docs/vault-facets.md`
- `docs/threat-model.md`
- `test/ERC4626VaultAccountingInvariant.t.sol`
