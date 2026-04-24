# Slither Triage

This is the current static-analysis closeout artifact for the pre-public audit
remediation branch. It records the accepted medium, low, and informational
Slither findings that remain after high-severity gating. It does not suppress
detectors globally, change public ABI shape, or change runtime behavior.

## Measured Baseline

- Branch: `codex/close-slither-triage-218`
- Commit measured: `10cdef11aa01b142a50f6dfc402897414a72a596`
- Slither version: `0.11.5`
- CLI flag verified with: `slither --help`
- Local command:

```bash
slither . --exclude-dependencies --fail-high --filter-paths 'test/|script/' --disable-color
```

- Result: exit code `0`; Slither analyzed 99 contracts with 101 detectors and
  reported 174 retained non-high findings.

The local triage command filters `test/|script/` so the closeout output stays
focused on production contracts. CI intentionally keeps the broader
high-severity gate in `.github/workflows/slither.yml` through
`crytic/slither-action` with `fail-on: high` and `slither-args:
--exclude-dependencies`.

## Accepted Detector Families

### AMM

- `incorrect-equality`: accepted for zero-value sentinels, initial liquidity
  checks, empty return-data checks, and invariant-style swap/burn guard
  conditions. These are exact state predicates, not price comparisons.
- `calls-loop`: accepted for router path traversal. The path is user supplied,
  each hop intentionally reads factory/pair state, and gas scales with route
  length.
- `low-level-calls`: accepted for SafeERC20-style transfer shims and wrapped
  native deposit/withdraw helpers. Return data is checked where tokens may
  return `false` or no value.
- `missing-zero-check`: accepted for `AMMFactory.setFeeTo(address)`. A zero fee
  recipient intentionally disables protocol fee collection.
- `reentrancy-events`: accepted for event emission after pair transfers and
  diamond/router-style effects. State is updated before external token
  transfers where the AMM invariant depends on it, and events describe completed
  state transitions.
- `timestamp`: accepted for permit deadlines, router deadlines, and pair
  cumulative price time elapsed logic.
- `unused-return`: accepted for reserve tuple destructuring where timestamp
  return values are intentionally irrelevant to the caller.

### Vault

- `calls-loop`: accepted for single active strategy liquidity sourcing. Slither
  reports these through routed call stacks, but the implementation does not
  iterate across an unbounded strategy set.
- `low-level-calls`: accepted for native-asset and ERC-20 transfer adapters and
  metadata reads. The helpers normalize optional token return data and native
  transfer success.
- `unused-return`: accepted for tuple return discards in limit and fee math.
  Named tuple positions are used to make selected values explicit and avoid
  shadow state.
- `reentrancy-events`: accepted for deposit, mint, withdraw, redeem, and fee
  payout sequencing. The externally visible events are emitted after the
  corresponding transfer path completes.
- `assembly`: accepted for diamond/facet storage-slot access and facet-local
  initialization checks. These are the intended storage layout mechanism.
- `dead-code`: accepted for internal foundation hooks used by concrete hosts,
  tests, or future facet composition even when Slither analyzes a base contract
  in isolation.
- `unimplemented-functions`: accepted for hosted vault facets that inherit
  shared ERC-4626 interfaces but intentionally own only a subset of selectors in
  a diamond. Selector ownership is defined by `LibVaultFacetSelectors` and
  covered by selector-integrity and hosted-vault tests.
- `redundant-statements`: accepted for ERC-7540 revert-only preview stubs. The
  no-op parameter references preserve named parameters and NatSpec while
  avoiding unused-parameter compiler warnings.

### Wallet

- `calls-loop`: accepted for `MultiSendCallOnly.multiSend(bytes)`. Batched calls
  are the feature surface and the caller controls batch size.
- `low-level-calls`: accepted for wallet execution and call-only batch delegate
  execution. Success is checked and revert data is surfaced.
- `assembly`: accepted for packed multisend parsing, revert bubbling, and
  signature extraction.
- `reentrancy-events`: accepted on factory deployment events. The factory emits
  after clone initialization so logs describe initialized wallets only.
- `unindexed-event-address`: accepted for `WalletInitialized(address[],uint256,address)`.
  Indexing the dynamic owner array would only expose a hash, and changing topics
  would alter the public log shape.

### Diamond And Upgrade

- `locked-ether`: accepted for the diamond fallback/receive artifact. Native
  assets are handled by installed facets; the core proxy intentionally exposes
  only dispatch and ownership/loupe surfaces.
- `low-level-calls`: accepted for upgrade initialization `delegatecall`. The
  target and calldata are part of an authorized diamond cut.
- `reentrancy-events`: accepted for `DiamondCut` emission after the authorized
  cut and optional init call complete.
- `unimplemented-functions`: accepted for abstract
  `UpgradeGuardrails._applyUpgrade(address)`. Concrete upgrade hosts provide
  the application-specific implementation.
- `timestamp`: accepted for upgrade timelock readiness checks.
- `unindexed-event-address`: accepted for
  `DiamondCut(FacetCut[],address,bytes)`. Indexing would change the public event
  topic shape, and the dynamic cut payload is more useful as event data than as
  indexed hashes.

### Oracle, Access, And Token

- `timestamp`: accepted for access-control validity windows, oracle staleness
  and future-round rejection, token permit deadlines, and upgrade windows.
- `low-level-calls`: accepted for oracle feed reads because strict and try-read
  paths intentionally distinguish call failure from invalid round data.
- `naming-convention`: accepted for canonical Solidity API names such as
  `DOMAIN_SEPARATOR()`, role constants, scope constants, and
  `MINIMUM_LIQUIDITY()`.
- `assembly`: accepted for storage-layout libraries that pin diamond/facet
  storage slots.
- `shadowing-local`: accepted for interface parameter names that mirror function
  names and keep external ABI/NatSpec names descriptive.
- `too-many-digits`: accepted for creation-code hash generation and selector
  constants used in low-level initialization probes.

## Concrete Issue 218 Findings

- Hosted vault facet-local ambiguity: Slither reports several hosted facets as
  missing `IERC4626.asset()`. This is a static-analysis artifact of analyzing
  facet contracts locally. Diamond selector ownership is enforced through
  `LibVaultFacetSelectors` and covered by selector ownership tests, so adding
  forwarding methods to every facet would create selector churn without changing
  runtime safety.
- Unindexed events: `DiamondCut` and `WalletInitialized` are intentionally left
  unchanged. Adding `indexed` would be an observable log-topic change, and the
  dynamic payloads are more useful to indexers as decoded event data.
- ERC-7540 preview stubs: the four unsupported preview functions keep no-op
  references to their named parameters before reverting. This preserves
  signature/NatSpec clarity and avoids unused-parameter compiler warnings
  without adding behavior.
