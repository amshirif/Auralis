<p align="center">
  <img src="docs/assets/auralis-logo.svg" alt="Auralis logo" width="140" />
</p>

# Auralis

![Solidity](https://img.shields.io/badge/Solidity-0.8.30-363636?logo=solidity)
[![Foundry CI](https://github.com/amshirif/Auralis/actions/workflows/ci.yml/badge.svg)](https://github.com/amshirif/Auralis/actions/workflows/ci.yml)
![License](https://img.shields.io/github/license/amshirif/Auralis)

Security-first Solidity systems.

`Auralis` is a protocol-engineering portfolio repository focused on
security-first, upgrade-aware Solidity systems. It combines modular contract
design, deployment-backed validation, local operator flows, hardening
coverage, and standalone smart-wallet execution so a reviewer can assess
architecture and evidence together rather than as isolated snippets.

## Why This Repo Exists

This repo is meant to demonstrate more than isolated contract snippets. It
shows how access control, guard rails, oracle safety, vault logic, diamond
routing, deployment scripts, rehearsal flows, and CI checks fit together as a
reviewable engineering system.

## Review In 5 Minutes

- Architecture decisions: `docs/adr/README.md`
- Canonical docs map: `docs/README.md`
- AMM architecture: `docs/amm.md`
- Hosted vault architecture: `docs/vault-facets.md`
- Async vault requests: `docs/erc7540-vault.md`
- Smart-wallet architecture: `docs/multisig-wallet.md`
- Security assumptions: `docs/threat-model.md`
- Validation and CI policy: `docs/security-checks.md`
- Local workflow and deployment artifacts: `docs/auralis-local.md`

## What This Repo Proves

- Core architecture: diamond routing, selector ownership discipline, and
  separate hosted token and vault deployment models plus standalone AMM and
  smart-wallet tracks.
- Safety posture: RBAC, timed permissions, pause semantics, reentrancy
  protection, oracle validation, upgrade guardrails, and threshold-based wallet
  execution.
- Protocol surfaces: ERC20 and ERC721 token hosts plus a hosted ERC-4626 vault
  platform with controls, strategy integration, native-asset support, and an
  ERC-7540 async request track for ERC-20 hosts, plus a standalone V2-style
  AMM with deterministic pair deployment, wrapped-native routing, and
  protocol-fee controls, plus a standalone multisig wallet with single-call,
  batch, and self-managed configuration flows.
- Operational maturity: local bootstrap, smoke validation, activity flows,
  upgrade rehearsal, and matching CI/hardening gates.

## Evidence

### Architecture And Design

- `docs/adr/README.md`: accepted architecture decisions and why the repo is
  shaped this way.
- `docs/diamond-core.md`: diamond routing, cut flow, selector ownership, and
  storage discipline.
- `docs/vault-facets.md`: hosted vault family, facet split, lifecycle, and
  deployment model.
- `docs/erc7540-vault.md`: async request lifecycle, settlement surface,
  controller/operator semantics, and reviewer entrypoints.
- `docs/amm.md`: standalone AMM deployment model, pair/router behavior, math,
  and reviewer path.
- `docs/multisig-wallet.md`: wallet deployment model, signature semantics,
  replay protection, and self-managed configuration surface.
- `docs/threat-model.md`: trust boundaries, threat assumptions, and residual
  risks.

### Validation

- `test/DiamondSelectorIntegrityCore.t.sol`: selector routing and loupe
  integrity regressions.
- `test/DiamondVaultDeploymentIntegration.t.sol`: hosted vault deployment,
  init, async selector ownership, settlement surface, and oracle wiring.
- `test/DiamondVaultHostHardening.t.sol`: replace/remove/re-add hardening
  across the hosted vault diamond path.
- `test/DiamondVaultHostInvariant.t.sol`: diamond-routed hosted vault
  invariants across deposits, withdrawals, strategy lifecycle, roles, and
  pause state.
- `test/DiamondNativeVaultHostHardening.t.sol`: native hosted vault
  force-sent ETH, strategy, selector replacement, and persistence hardening.
- `test/DiamondNativeVaultHostInvariant.t.sol`: native hosted vault invariants
  for managed accounting, immediate liquidity, limits, strategy debt, and
  force-sent surplus.
- `test/ERC7540VaultFoundationCore.t.sol`: aggregate request model, selector
  split, and operator bookkeeping coverage.
- `test/ERC7540VaultDepositCore.t.sol`: async deposit request, settlement, and
  claim coverage.
- `test/ERC7540VaultRedeemCore.t.sol`: async redeem request, settlement, and
  claim coverage.
- `test/ERC7540VaultDepositFuzz.t.sol` and
  `test/ERC7540VaultRedeemFuzz.t.sol`: async request property coverage for
  deposit and redeem flows.
- `test/ERC7540VaultRequestAccountingInvariant.t.sol`: async request
  accounting invariants across pending, claimable, escrowed, and managed
  buckets.
- `test/ERC7540VaultRequestTime.t.sol`: async controller/operator and
  settlement-scope time-window coverage.
- `test/DiamondTokenDeploymentIntegration.t.sol`: ERC20 and ERC721 host
  deployment and selector ownership.
- `test/DiamondTokenHostHardening.t.sol`: token-host replace/remove/re-add,
  role, pause, Permit, and metadata persistence coverage.
- `test/DiamondErc20HostInvariant.t.sol` and
  `test/DiamondErc721HostInvariant.t.sol`: diamond-routed token-host
  invariants for ERC20 and ERC721 behavior.
- `test/AMMFactoryRegistry.t.sol`: AMM factory registry behavior, sorted pair
  lookups, and deterministic pair address coverage.
- `test/AMMPairCore.t.sol`: pair mint/burn/swap accounting, fee switch, and
  reserve update behavior.
- `test/AMMRouterCore.t.sol`: router quoting, liquidity, wrapped-native, and
  single-hop/multi-hop swap coverage.
- `test/AMMRouterTime.t.sol`: cumulative price and reserve timestamp coverage.
- `test/AMMPairFuzz.t.sol` and `test/AMMRouterFuzz.t.sol`: pair and router
  property coverage.
- `test/AMMInvariant.t.sol`: AMM reserve, balance, LP, and factory invariants.
- `test/AMMHardening.t.sol`: malformed token, false/silent transfer,
  reentrancy, protocol-fee, and router balance hardening coverage.
- `test/SystemOracleFailureScenarios.t.sol`: stale-data, breaker, fallback, and
  recovery behavior.
- `test/SystemVaultStressInvariant.t.sol`: higher-signal system stress coverage
  for vault behavior under adversarial sequences.
- `test/MultisigWalletFoundationCore.t.sol`: initializer, owner-set, and clone
  foundation checks.
- `test/MultisigWalletCoreExecution.t.sol`: EIP-712 signing, nonce, ERC-1271,
  and single-call execution behavior.
- `test/MultisigWalletIntegration.t.sol`: batch execution and deterministic
  factory deployment coverage.
- `test/MultisigWalletManagement.t.sol`: self-managed owner and threshold
  mutation coverage.
- `test/MultisigWalletFuzz.t.sol`: signature, signer-ordering, batch, and
  management fuzz coverage.
- `test/MultisigWalletInvariant.t.sol`: owner uniqueness, threshold bounds, and
  nonce progression invariants.

### Deployment And Operator Evidence

- `docs/security-checks.md`: current CI policy and local reproduction path.
- `docs/ops/README.md`: operator runbooks and validation flows.
- `docs/auralis-local.md`: local bootstrap, smoke, activity, reset, and
  artifact layout.

## Validation Path

Foundry uses the Solidity compiler pinned in `foundry.toml` (currently
`0.8.34`); Foundry `1.4.3` will fetch that compiler version on first build if
it is not already installed locally.

Run a bounded reviewer-facing path with the curated groups below. The fuller
local command inventory lives in `docs/security-checks.md`.

```shell
forge fmt --check
forge build --sizes --skip script
```

For hosted diamond and vault behavior:

```shell
forge test --offline --match-path test/DiamondSelectorIntegrityCore.t.sol
forge test --offline --match-path test/DiamondVaultDeploymentIntegration.t.sol
forge test --offline --match-path test/DiamondVaultHostHardening.t.sol
forge test --offline --match-path test/DiamondVaultHostInvariant.t.sol
forge test --offline --match-path test/DiamondNativeVaultHostHardening.t.sol
forge test --offline --match-path test/DiamondNativeVaultHostInvariant.t.sol
forge test --offline --match-path test/ERC7540VaultFoundationCore.t.sol
forge test --offline --match-path test/ERC7540VaultDepositCore.t.sol
forge test --offline --match-path test/ERC7540VaultRedeemCore.t.sol
forge test --offline --match-path test/ERC7540VaultDepositFuzz.t.sol
forge test --offline --match-path test/ERC7540VaultRedeemFuzz.t.sol
forge test --offline --match-path test/ERC7540VaultRequestAccountingInvariant.t.sol
forge test --offline --match-path test/ERC7540VaultRequestTime.t.sol
forge test --offline --match-path test/SystemOracleFailureScenarios.t.sol
forge test --offline --match-path test/SystemVaultStressInvariant.t.sol
```

For the token-host track:

```shell
forge test --offline --match-path test/DiamondTokenDeploymentIntegration.t.sol
forge test --offline --match-path test/DiamondTokenHostHardening.t.sol
forge test --offline --match-path test/DiamondErc20HostInvariant.t.sol
forge test --offline --match-path test/DiamondErc721HostInvariant.t.sol
```

For the wallet track:

```shell
forge test --offline --match-path test/MultisigWalletFoundationCore.t.sol
forge test --offline --match-path test/MultisigWalletCoreExecution.t.sol
forge test --offline --match-path test/MultisigWalletIntegration.t.sol
forge test --offline --match-path test/MultisigWalletManagement.t.sol
forge test --offline --match-path test/MultisigWalletFuzz.t.sol
forge test --offline --match-path test/MultisigWalletInvariant.t.sol
```

For the AMM track:

```shell
forge test --offline --match-path test/AMMFoundationCore.t.sol
forge test --offline --match-path test/AMMFactoryRegistry.t.sol
forge test --offline --match-path test/AMMPairCore.t.sol
forge test --offline --match-path test/AMMRouterCore.t.sol
forge test --offline --match-path test/AMMRouterTime.t.sol
forge test --offline --match-path test/AMMPairFuzz.t.sol
forge test --offline --match-path test/AMMRouterFuzz.t.sol
FOUNDRY_INVARIANT_RUNS=64 FOUNDRY_INVARIANT_DEPTH=32 forge test --offline --match-path test/AMMInvariant.t.sol
forge test --offline --match-path test/AMMHardening.t.sol
```

For the local Auralis workflow:

```shell
bash scripts/auralis-up.sh
bash scripts/auralis-smoke.sh
bash scripts/auralis-reset.sh
```

## Documentation

Start with `docs/README.md` for the canonical docs map.

Recommended reviewer path:

- Architecture decisions: `docs/adr/README.md`
- Core architecture: `docs/diamond-core.md`, `docs/token-facets.md`,
  `docs/vault-facets.md`, `docs/erc7540-vault.md`, `docs/amm.md`,
  `docs/multisig-wallet.md`, `docs/oracle-adapter.md`
- Security and validation: `docs/threat-model.md`, `docs/security-checks.md`
- Operations and local workflow: `docs/ops/README.md`, `docs/auralis-local.md`

## Tooling

Built with Foundry. CI workflows live under `.github/workflows/`.

Foundry docs: [book.getfoundry.sh](https://book.getfoundry.sh/)

## Public Metadata

This is a personal portfolio repository. Contribution, security, changelog, and
GitHub template guidance are provided for public review, while community
operations files such as `CODE_OF_CONDUCT.md`, `SUPPORT.md`, and `FUNDING.yml`
are intentionally omitted.

## AI Usage

AI assistance was used for tests, documentation, scripts, and planning support.

The protocol architecture, technical decisions, and final review/integration of
changes were directed and owned by me.
