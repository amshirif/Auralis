# Diamond Core

This document describes the diamond core behavior implemented in this repository,
including bootstrap expectations, `diamondCut` init flow, selector ownership
rules, and upgrade review guidance.

For the decision to use diamonds as the repository's upgrade and composition
foundation, see `docs/adr/0001-diamond-foundation.md`.

## Contracts

- `src/diamond/Diamond.sol`: base proxy with owner bootstrap and selector routing fallback.
- `src/diamond/facets/DiamondCutFacet.sol`: owner-gated `diamondCut` entrypoint.
- `src/diamond/facets/DiamondLoupeFacet.sol`: loupe reads + `IERC173` ownership surface.
- `src/diamond/libraries/LibDiamond.sol`: selector/owner/interface bookkeeping and cut helpers.
- `src/diamond/storage/LibDiamondStorage.sol`: canonical diamond storage slot layout.

## Deployment And Bootstrap Flow

Current `Diamond` constructor bootstraps the owner and initial cut facet:

- deploy `DiamondCutFacet`.
- deploy `Diamond(initialOwner, initialCutFacet)`.
- deploy remaining initial facets (`DiamondLoupeFacet`, others).
- install additional selectors through `diamondCut`.

In tests, extra selectors can still be installed through
`DiamondProxyHarness.installSelector(...)`. For production, the constructor now
bootstraps `diamondCut`, and the deploy flow should use that to install the
rest of the initial selector set before regular operations begin.

## `diamondCut` And Init Delegatecall Flow

`DiamondCutFacet.diamondCut(...)` enforces owner-only access, then calls
`LibDiamond.diamondCut(...)`.

Validation checks enforced in `LibDiamond`:

- empty selector arrays revert (`DiamondCutEmptySelectors`).
- add/replace targets must contain code (`DiamondTargetHasNoCode`).
- remove actions must use `facetAddress == address(0)`
  (`DiamondCutRemoveFacetAddressNotZero`).
- init calldata without init target reverts (`DiamondCutInitTargetRequired`).
- init target without calldata reverts (`DiamondCutInitCalldataRequired`).
- init delegatecall failures bubble via `DiamondCutInitFailed`.

Execution order:

1. Apply add/replace/remove selector mutations.
2. Execute optional init delegatecall.
3. Emit `DiamondCut` event from `DiamondCutFacet`.

## Selector Ownership Rules

- A selector maps to exactly one facet at a time.
- Add rejects existing selectors (`DiamondSelectorAlreadyExists`).
- Replace rejects unknown selectors and same-facet replacements.
- Remove rejects unknown selectors (`DiamondSelectorNotFound`).
- Facet address and selector arrays use swap-and-pop updates; array ordering can
  change after removals.

Loupe reads (`facets`, `facetAddresses`, `facetFunctionSelectors`,
`facetAddress`) should be treated as the source of truth for live routing state.

## Storage Discipline

To stay diamond-safe:

- keep mutable state in namespaced storage libraries (`src/*/storage`), not in
  facet state variables.
- keep storage structs append-only once deployed.
- use explicit initializers and idempotency guards for new modules/facets.
- review slot constants and struct layout changes before every cut.

## Upgrade Review Checklist

1. Verify cut intent: selectors added/replaced/removed are expected.
2. Verify each facet target has deployed bytecode and reviewed source.
3. Verify selector collisions are intentional and reviewed.
4. Verify init target + calldata, including idempotency and access controls.
5. Verify storage layout assumptions for every touched module.
   - Treat current rehearsal and hardening coverage as proof of same-layout
     persistence on the current namespace baseline, not as proof of storage
     migration across renamed slot namespaces.
6. Execute post-cut checks:
   - loupe snapshot matches expected routing.
   - critical external calls succeed.
   - ownership (`owner()`) is unchanged unless intentionally transferred.

## Security Assumptions And Limits

- Diamond owner authority is highly privileged; use multisig/governance in production.
- This core does not include built-in timelock/governance policy for cuts.
- Current diamond cuts are not queued or timelocked through
  `UpgradeGuardrails`; that module is standalone unless a future deployment
  explicitly wires a guardrail controller.
- Bootstrap/install strategy is deployment-specific and must be reviewed.
- Safety depends on off-chain cut payload review and post-cut validation.

## Test References

- `test/DiamondFoundationCore.t.sol`
- `test/DiamondProxyCore.t.sol`
- `test/DiamondCutCore.t.sol`
- `test/DiamondLoupeCore.t.sol`
- `test/DiamondSelectorIntegrityCore.t.sol`
