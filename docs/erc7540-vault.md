# ERC-7540 Async Vault

This document is the canonical reviewer guide for the hosted ERC-7540 async
request track in `Auralis`.

It covers the shipped async request model for ERC-20 hosted vaults. For the
broader hosted-vault architecture, selector ownership, native-mode behavior,
and strategy model, see `docs/vault-facets.md`. For the standalone synchronous
vault module, see `docs/erc4626-vault.md`.

## Supported Host Variants

The hosted vault family currently has three reviewer-relevant variants:

- synchronous ERC-20 hosted vaults
- synchronous native hosted vaults
- async ERC-20 hosted vaults with ERC-7540-style request flows

The async ERC-20 track uses two deployment shapes:

- async-deposit host: async deposit requests plus synchronous withdraw/redeem
- fully async host: async deposit requests plus async redeem requests

The native hosted vault does not currently expose the async request surface.

Async hosts still bootstrap through `initializeVault(...)` on the core facet.
The reference deployment path uses atomic cut+init, and the first hosted
initialization on an uninitialized diamond is restricted to the current
diamond owner.

## Selector Ownership

The async request model is implemented by splitting the hosted selector groups
across the diamond.

### Async-Deposit Host

- `ERC4626VaultFacet`: initialization, metadata, share-token selectors,
  `asset()`, `totalAssets()`, `totalManagedAssets()`, `convertToShares()`,
  `convertToAssets()`, plus `withdraw` and `redeem` flows
- `ERC7540VaultDepositFacet`: `requestDeposit`, pending/claimable deposit
  views, operator approvals, and async-claim-aware `deposit`, `mint`,
  `maxDeposit`, and `maxMint`
- `ERC4626VaultControlsFacet`: roles, fee/limit config, pause, scoped pause,
  and `supportsInterface(bytes4)`
- `ERC4626VaultIntegrationFacet`: oracle/strategy selectors plus async
  settlement selectors

### Fully Async Host

- `ERC4626VaultFacet`: initialization, metadata, share-token selectors,
  `asset()`, `totalAssets()`, `totalManagedAssets()`, `convertToShares()`, and
  `convertToAssets()`
- `ERC7540VaultDepositFacet`: async deposit request and claim selectors
- `ERC7540VaultRedeemFacet`: async redeem request and claim selectors,
  including async-claim-aware `withdraw`, `redeem`, `maxWithdraw`, and
  `maxRedeem`
- `ERC4626VaultControlsFacet`: roles, fee/limit config, pause, scoped pause,
  and `supportsInterface(bytes4)`
- `ERC4626VaultIntegrationFacet`: oracle/strategy selectors plus async
  settlement selectors

## Request Model

The current implementation uses an aggregate request model rather than
per-request queue ids.

- the only supported request id is `0`
- pending and claimable balances are tracked per `controller`
- nonzero request ids return zero from the view helpers and revert in internal
  aggregate-id validation
- reviewers should treat the implementation as controller-scoped buckets, not a
  FIFO queue of independently claimable requests

Request bookkeeping is shared by
`src/vault/libraries/LibERC7540RequestAccounting.sol` and stored in
`src/vault/storage/LibERC7540VaultStorage.sol`.

## Deposit Lifecycle

Async deposit requests follow this lifecycle:

1. `requestDeposit(assets, controller, owner)` transfers ERC-20 assets into the
   vault and increases the controller's pending deposit bucket.
2. Pending assets remain locked in the vault balance but do not increase
   `totalManagedAssets()` or `totalAssets()`.
3. A vault manager calls `settleDepositRequest(controller, assets)` through the
   integration facet to move assets from pending to claimable.
4. The controller, or an approved operator for that controller, claims the
   settled assets through the standard ERC-4626 entrypoints on the async
   deposit facet:
   - `deposit(assets, receiver)`
   - `mint(shares, receiver)`
   - `deposit(assets, receiver, controller)`
   - `mint(shares, receiver, controller)`
5. Claiming consumes claimable assets, increases managed assets by the net
   post-fee amount, mints shares, and pays any configured deposit fee.

Reviewer-visible implications:

- assets are committed before they are priced into shares
- claims use the current exchange rate at claim time rather than request time
- `previewDeposit` and `previewMint` revert on async deposit hosts
- `maxDeposit` and `maxMint` track the caller's current claimable bucket rather
  than open-ended fresh deposits

## Redeem Lifecycle

Fully async hosts extend the model to redeem requests:

1. `requestRedeem(shares, controller, owner)` moves shares from `owner` into
   vault escrow and increases the controller's pending redeem bucket.
2. Escrowed shares remain part of total supply and managed assets until claim;
   they are not burned at request time.
3. A vault manager calls `settleRedeemRequest(controller, shares)` through the
   integration facet to move shares from pending to claimable.
4. The controller, or an approved operator for that controller, claims the
   settled shares through the async redeem facet:
   - `withdraw(assets, receiver, controller)`
   - `redeem(shares, receiver, controller)`
5. Claiming consumes claimable shares, burns the escrowed shares, reduces
   managed assets by the gross asset exit amount, transfers the net assets to
   the receiver, and pays any configured withdraw fee.

Reviewer-visible implications:

- share escrow happens at request time, but burning happens at claim time
- redeem claims can source immediately withdrawable strategy liquidity before
  payout
- `previewWithdraw` and `previewRedeem` revert on fully async hosts
- `maxWithdraw` and `maxRedeem` are bounded by both claimable shares and
  immediately sourceable liquidity

## Authorization Model

The async request track separates owner, controller, operator, and manager
responsibilities.

### Deposit Requests

- `owner` is the asset owner whose ERC-20 balance funds the request
- `controller` is the account whose pending/claimable deposit bucket is updated
- `msg.sender` may be:
  - the owner
  - an operator approved by the owner through `setOperator`

Claiming settled deposit requests requires:

- the controller, or
- an operator approved by the controller

### Redeem Requests

- `owner` is the share owner whose shares are escrowed
- `controller` is the account whose pending/claimable redeem bucket is updated
- `msg.sender` may be:
  - the owner
  - an operator approved by the owner
  - an allowance holder spending the owner's share allowance

Claiming settled redeem requests requires:

- the controller, or
- an operator approved by the controller

### Settlement

Settlement is manager-only:

- `settleDepositRequest(controller, assets)`
- `settleRedeemRequest(controller, shares)`

Both settlement entrypoints require `VAULT_MANAGER_ROLE` and do not become
available to operators.

## Pause And Settlement Semantics

The async request track uses both the global pause model and a dedicated
settlement scope.

- global pause blocks request and claim entrypoints
- share-token flows (`approve`, `transfer`, `transferFrom`) remain outside the
  write-path pause surface
- settlement entrypoints are additionally gated by
  `ASYNC_SETTLEMENT_SCOPE = keccak256("ASYNC_SETTLEMENT_SCOPE")`

Important behavior:

- pausing `ASYNC_SETTLEMENT_SCOPE` blocks new manager settlement transitions
- already-claimable requests remain claimable while settlement is scope-paused
- the settlement scope does not replace the global pause for request or claim
  entrypoints

## Accounting And Safety Assumptions

The async request model introduces two extra committed-balance states that a
reviewer needs to track.

### Pending And Claimable Deposits

- pending deposit assets are held by the vault but excluded from managed assets
- claimable deposit assets are also excluded from managed assets until claimed
- deposit limit checks account for committed assets by including:
  - `totalAssets()`
  - total pending deposit request assets
  - total claimable deposit request assets

### Pending And Claimable Redeems

- pending redeem shares are escrowed in the vault and remain unburned
- claimable redeem shares are still escrowed until claimed
- redeem claims burn escrowed shares only when the controller executes the
  claim flow

### Liquidity Boundary

- async redeem claims may pull immediately withdrawable assets from the active
  strategy before paying the receiver
- `maxWithdraw` and `maxRedeem` do not promise access to full mark-to-market
  value when strategy liquidity is constrained

## Known Limitations

- ERC-20 hosted vaults only; native hosted vaults remain on the synchronous
  surface
- aggregate request model only; there is no per-request queue id surface beyond
  `requestId == 0`
- no FIFO or time-priority queue semantics are promised
- no automatic or keeper-driven settlement loop is built in
- async preview helpers intentionally revert instead of approximating future
  settlement pricing
- manager settlement is a trust and operations assumption that reviewers should
  evaluate alongside the role model

## Reviewer Entry Points

Start here when reviewing the async request implementation:

- Interfaces:
  - `src/interfaces/IERC7540Deposit.sol`
  - `src/interfaces/IERC7540Redeem.sol`
  - `src/interfaces/IERC7540Operators.sol`
  - `src/interfaces/IERC7540VaultSettlementFacet.sol`
- Facets:
  - `src/vault/facets/ERC7540VaultDepositFacet.sol`
  - `src/vault/facets/ERC7540VaultRedeemFacet.sol`
  - `src/vault/facets/ERC4626VaultIntegrationFacet.sol`
- Libraries and storage:
  - `src/vault/libraries/LibERC7540RequestAccounting.sol`
  - `src/vault/libraries/LibVaultFacetSelectors.sol`
  - `src/vault/libraries/LibVaultFacetConstants.sol`
  - `src/vault/storage/LibERC7540VaultStorage.sol`

## Validation References

Use these suites to review the async request surface locally:

- `test/ERC7540VaultFoundationCore.t.sol`: aggregate request model, selector
  split, operator bookkeeping, and request-accounting helpers
- `test/ERC7540VaultDepositCore.t.sol`: async deposit request, settlement,
  claim, operator, limit, and settlement-pause behavior
- `test/ERC7540VaultRedeemCore.t.sol`: async redeem request, settlement,
  claim, allowance/operator behavior, limit, and settlement-pause behavior
- `test/DiamondVaultDeploymentIntegration.t.sol`: fully async host deployment,
  selector ownership, interface support, and strategy wiring
- `test/DiamondVaultHostHardening.t.sol`: persistence across replace/remove
  flows with async selectors installed
- `test/DiamondVaultHostInvariant.t.sol`: diamond-routed invariant coverage for
  the hosted async vault path
