# Threat Model

This summary covers security assumptions and guard rails for access, oracle,
upgrade, and vault modules.

## In-Scope Modules

- `AccessControl`
- `ERC4626Vault`
- `ERC4626VaultControls`
- `OracleAdapter`
- `Pausable`
- `ReentrancyGuard`
- `UpgradeGuardrails`

## Security Goals

- Unauthorized accounts cannot perform privileged actions.
- Role administration and permission state changes are explicit and auditable.
- Oracle reads fail closed by default and only degrade under explicit fallback policy.
- Emergency pause controls can contain incidents.
- Reentrant state-changing entrypoints are blocked.
- Upgrade execution follows explicit authorization and guardrail checks.
- Vault share/accounting behavior remains explicit under rounding and low-liquidity edge conditions.

## Trust Assumptions

- Initial admin/upgrader/pauser assignments are correct at initialization.
- Oracle feed sources are configured to trusted contracts with expected ABI behavior.
- Governance/operator keys are managed securely off-chain.
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

## Residual Risks / Out of Scope

- Compromised privileged keys can still perform privileged actions.
- Economic attacks and protocol-specific business logic exploits are out of scope for this base kit.
- Oracle market manipulation resistance is feed/provider-specific and must be handled at integration and policy layers.
- Diamond-specific `diamondCut` payload validation and multi-step governance workflows are deferred to the diamond milestone.
- The current upgrade guardrails check nonzero implementation; deeper bytecode/interface validation is protocol-specific and should be added where needed.
- Direct token donations to vault addresses can create untracked surplus unless explicitly reconciled by integration policy.

## Operational Guidance

- Use multisig-controlled privileged roles in production.
- Set nonzero upgrade delays in production.
- Restrict and monitor role admin changes.
- Keep pause and upgrade procedures documented and rehearsed.
