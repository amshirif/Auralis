# Threat Model

This summary covers security assumptions and guard rails for access, oracle,
upgrade, vault, AMM, and wallet modules.

For the accepted architecture decisions that shape these assumptions, see
`docs/adr/README.md`.

## In-Scope Modules

- `AccessControl`
- `ERC4626Vault`
- `ERC4626VaultControls`
- `OracleAdapter`
- `Pausable`
- `ReentrancyGuard`
- `UpgradeGuardrails`
- `AMMFactory`
- `AMMPair`
- `AMMRouter`
- `AMMLpToken`
- `MultisigWallet`
- `MultisigWalletFactory`
- `MultiSendCallOnly`

## Security Goals

- Unauthorized accounts cannot perform privileged actions.
- Role administration and permission state changes are explicit and auditable.
- Oracle reads fail closed by default and only degrade under explicit fallback policy.
- Emergency pause controls can contain incidents.
- Reentrant state-changing entrypoints are blocked.
- Upgrade execution follows explicit authorization and guardrail checks.
- Vault share/accounting behavior remains explicit under rounding and low-liquidity edge conditions.
- AMM liquidity, reserve updates, and fee-switch behavior remain explicit under
  direct-transfer, malformed-token, and adversarial routing conditions.
- Wallet execution requires the configured threshold of valid owner signatures.
- Wallet replay protection prevents nonce reuse across signed transactions.
- Wallet configuration changes require wallet-authorized self-calls.

## Trust Assumptions

- Initial admin/upgrader/pauser assignments are correct at initialization.
- Oracle feed sources are configured to trusted contracts with expected ABI behavior.
- Governance/operator keys are managed securely off-chain.
- The configured wrapped-native contract implements the expected deposit,
  withdraw, and ERC-20 transfer semantics.
- Wallet owners review and approve transaction payloads securely off-chain.
- The configured `MultiSendCallOnly` helper is the intended fixed batch helper for deployed wallets.
- Deployed contracts integrate `_applyUpgrade` correctly for their proxy/diamond mechanism.
- Time-based checks rely on `block.timestamp` and accept normal timestamp variance.

## Key Threats and Mitigations

1. Privilege escalation
- Mitigation: role-based checks (`onlyRole`), role admin hierarchy, explicit grant/revoke/renounce flows.

2. Misuse of temporary permissions
- Mitigation: role windows with start/end bounds and active-role checks.

3. Incident blast radius
- Mitigation: global and scoped pausing, plus role-gated pause/unpause controls.

4. Reentrant write-path execution
- Mitigation: `nonReentrant` guard for state-changing entrypoints.

5. Oracle data quality failures (stale/invalid/malformed source reads)
- Mitigation: strict validation of timestamps/round consistency/bounds, strict-revert default mode, breaker trip path, optional configured fallback.

6. Oracle control-plane misuse
- Mitigation: separate `ORACLE_ADMIN_ROLE` (config/reset) and `ORACLE_GUARDIAN_ROLE` (trip-only) with explicit admin hierarchy.

7. Unsafe or rushed upgrades
- Mitigation: upgrader role, queued intent model, optional timelock delay, strict implementation matching, cancel flow.

8. Donation-style vault share-price manipulation
- Mitigation: vault conversions use managed accounting (`totalManagedAssets`) instead of raw token balance.

9. Rounding edge exploitation in low-liquidity vault states
- Mitigation: deterministic rounding direction plus fuzz/invariant tests for roundtrip and accounting properties.

10. Emergency response lag on vault write paths
- Mitigation: pausable controls block `deposit`, `mint`, `withdraw`, and `redeem` when paused.

11. Wallet replay or stale approval reuse
- Mitigation: every signed wallet transaction includes the current monotonic nonce, and nonce advances on successful wallet execution.

12. Duplicate or malformed threshold approvals
- Mitigation: wallet signatures are packed at fixed length, recovered signers must be valid owners, and signer addresses must be strictly increasing.

13. Unauthorized wallet reconfiguration
- Mitigation: owner and threshold mutation methods require `msg.sender == address(this)` and can only be reached through an already-authorized wallet execution.

14. Batch execution widening into arbitrary delegatecall
- Mitigation: batch execution delegatecalls only into the fixed `MultiSendCallOnly` helper, which performs plain external calls to the encoded targets.

15. Unauthorized AMM fee-switch control
- Mitigation: `feeTo` and `feeToSetter` changes are restricted to the current
  `feeToSetter`, and pair fee minting is derived only from the factory state.

16. Reentrant or malformed token behavior during AMM transfers
- Mitigation: pair write paths are lock-guarded, router and pair transfers use
  strict low-level success checks, and the hardening suites cover false,
  silent, malformed, and reentrant token behaviors.

17. Invalid wrapped-native routing or stuck native value
- Mitigation: the router validates wrapped-native path boundaries, accepts raw
  native value only from the configured wrapped-native contract, unwraps only
  on native-out paths, and refunds surplus native input where applicable.

18. Reserve drift after direct donations or token transfers
- Mitigation: reserves are tracked separately from raw balances, `skim` and
  `sync` remain explicit correction surfaces, and the invariant coverage checks
  reserve and LP accounting consistency.

19. Unstated assumptions around AMM price accumulation
- Mitigation: cumulative prices advance only on elapsed-time reserve updates,
  and the reviewer documentation treats them as low-level accounting outputs
  rather than as a full oracle policy.

## Residual Risks / Out of Scope

- Compromised privileged keys can still perform privileged actions.
- Economic attacks and protocol-specific business logic exploits are out of scope for this base kit.
- Oracle market manipulation resistance is feed/provider-specific and must be handled at integration and policy layers.
- Diamond `diamondCut` flows include core guardrails, but governance policy (timelocks/multisig approvals) remains an integration responsibility.
- The current upgrade guardrails check nonzero implementation; deeper bytecode/interface validation is protocol-specific and should be added where needed.
- Direct token donations to vault addresses can create untracked surplus unless explicitly reconciled by integration policy.
- AMM cumulative prices are not, by themselves, a manipulation-resistant
  oracle design.
- Compromised `feeToSetter` control can redirect AMM protocol-fee minting.
- Highly adversarial ERC-20 behavior beyond the documented supported semantics
  remains an integration risk.
- Compromised wallet owner keys can still authorize malicious transactions.
- Off-chain signing and transaction review policy for multisig owners remains an operational responsibility.
- The wallet does not yet include modules, guards, fallback handlers, contract owners, or ERC-4337 integration.

## Operational Guidance

- Use multisig-controlled privileged roles in production.
- Set nonzero upgrade delays in production.
- Restrict and monitor role admin changes.
- Keep pause and upgrade procedures documented and rehearsed.
