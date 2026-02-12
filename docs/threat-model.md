# Threat Model

This summary covers the security assumptions and guard rails for the
Access Control + Upgrade Safety Kit modules.

## In-Scope Modules

- `AccessControl`
- `Pausable`
- `ReentrancyGuard`
- `UpgradeGuardrails`

## Security Goals

- Unauthorized accounts cannot perform privileged actions.
- Role administration and permission state changes are explicit and auditable.
- Emergency pause controls can contain incidents.
- Reentrant state-changing entrypoints are blocked.
- Upgrade execution follows explicit authorization and guardrail checks.

## Trust Assumptions

- Initial admin/upgrader/pauser assignments are correct at initialization.
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

5. Unsafe or rushed upgrades
- Mitigation: upgrader role, queued intent model, optional timelock delay, strict implementation matching, cancel flow.

## Residual Risks / Out of Scope

- Compromised privileged keys can still perform privileged actions.
- Economic attacks and protocol-specific business logic exploits are out of scope for this base kit.
- Diamond-specific `diamondCut` payload validation and multi-step governance workflows are deferred to the diamond milestone.
- The current upgrade guardrails check nonzero implementation; deeper bytecode/interface validation is protocol-specific and should be added where needed.

## Operational Guidance

- Use multisig-controlled privileged roles in production.
- Set nonzero upgrade delays in production.
- Restrict and monitor role admin changes.
- Keep pause and upgrade procedures documented and rehearsed.
