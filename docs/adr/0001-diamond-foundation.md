# ADR 0001: Use diamond architecture as the upgrade and composition foundation

## Status

Accepted

## Context

`Auralis` is meant to demonstrate systems that evolve from standalone modules
into reviewable hosted platforms. That requires upgradeable composition without
collapsing storage discipline, selector ownership, or operational review into a
single monolithic contract.

## Decision

Use EIP-2535 diamond architecture as the repository's upgrade and composition
foundation.

The repository keeps mutable state in namespaced storage libraries and treats
selector ownership as an explicit review surface. Feature groups that need to
evolve independently are expressed as facets behind diamond hosts rather than
being merged into one large upgradeable implementation.

## Consequences

- New hosted systems can reuse the same cut, loupe, and selector-integrity
  review model.
- Upgrade safety depends on strict storage discipline and explicit post-cut
  validation.
- Facet boundaries become part of the architecture and must stay legible to
  reviewers.
- Some complexity moves from inheritance and constructor flow into deployment,
  routing, and selector bookkeeping.

## Related Docs/Tests

- `docs/diamond-core.md`
- `docs/vault-facets.md`
- `test/DiamondSelectorIntegrityCore.t.sol`
- `test/DiamondVaultDeploymentIntegration.t.sol`
