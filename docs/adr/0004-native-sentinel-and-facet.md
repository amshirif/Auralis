# ADR 0004: Add native asset support with a sentinel and dedicated facet

## Status

Accepted

## Context

The hosted vault platform needed native-asset support without breaking the
standard ERC-4626 surface or overloading existing selectors with asset-mode
specific semantics. The native work also had to fit within facet size limits and
preserve a clear selector ownership model.

## Decision

Represent native mode with the native asset sentinel and expose native-only
entrypoints through a dedicated facet instead of overloading the standard
ERC-4626 selectors.

Standard ERC-4626 selectors remain on the core vault facet. Native-only
entrypoints such as `depositNative` and `mintNative` live on the native facet.

## Consequences

- The ERC-4626 surface stays standard for ERC20-backed vaults.
- Native mode remains explicit in routing, selector ownership, and review.
- Native-specific semantics such as exact `msg.value` handling do not leak into
  the standard selector surface.
- Hosted native deployments must install and validate one additional facet.

## Related Docs/Tests

- `docs/vault-facets.md`
- `docs/auralis-local.md`
- `test/ERC4626VaultFacetCore.t.sol`
- `test/DiamondNativeVaultHostHardening.t.sol`
