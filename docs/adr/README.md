# Architecture Decision Records

This directory captures durable architecture decisions for `Auralis`.

ADRs explain why the repository is shaped the way it is. They are intentionally
short and decision-focused. Module behavior, operational flows, and validation
details continue to live in the subsystem docs and test suites.

## Status Vocabulary

- `Accepted`: the decision is in force for the current repository shape.
- `Superseded`: the decision was replaced by a later ADR.
- `Proposed`: the decision is under consideration and not yet the documented
  baseline.

## Current ADRs

- [0001 - Use diamond architecture as the upgrade and composition foundation](0001-diamond-foundation.md)
- [0002 - Deploy separate diamond hosts instead of a single mega-host](0002-separate-diamond-hosts.md)
- [0003 - Base hosted vault accounting on tracked managed assets](0003-tracked-managed-assets.md)
- [0004 - Add native asset support with a sentinel and dedicated facet](0004-native-sentinel-and-facet.md)
- [0005 - Exclude force-sent ETH from managed accounting and pricing](0005-exclude-force-sent-eth.md)
