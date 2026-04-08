# ADR 0002: Deploy separate diamond hosts instead of a single mega-host

## Status

Accepted

## Context

The repository hosts multiple standards and protocol surfaces, including ERC20,
ERC721, and ERC-4626-based vault flows. Trying to expose all of them from one
diamond would create selector collisions, blur upgrade intent, and make review
of supported surfaces harder.

## Decision

Deploy separate diamond hosts for materially different external surfaces instead
of building one shared mega-host.

ERC20, ERC721, and vault deployments remain distinct hosts even when they share
supporting control-plane or diamond-core patterns.

## Consequences

- Standard selector surfaces stay unchanged and do not require namespacing.
- Deployment artifacts, upgrade review, and hardening coverage remain scoped to
  one host type at a time.
- Shared logic must be reused through libraries, patterns, and scripts rather
  than a single catch-all host contract.
- Cross-host composition is explicit and easier to reason about operationally.

## Related Docs/Tests

- `docs/token-facets.md`
- `docs/vault-facets.md`
- `test/DiamondTokenDeploymentIntegration.t.sol`
- `test/DiamondVaultDeploymentIntegration.t.sol`
