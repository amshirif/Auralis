# Upgrade Guardrails

This module adds standalone, opt-in role-gated controls for implementation-style
upgrade operations with queue/execute guardrails and an optional timelock.

`UpgradeGuardrails` is not wired into the repository's current diamond hosts.
Current diamond selector upgrades are executed through
`DiamondCutFacet.diamondCut(...)` and `LibDiamond.diamondCut(...)`; they do not
call this module unless a future deployment explicitly adds a guardrail
controller.

## Usage

1. Inherit from `UpgradeGuardrails`.
2. Configure `minDelaySeconds` in constructor/init.
3. Queue upgrades with `queueUpgradeIntent(implementation)`.
4. Execute upgrades with `executeUpgrade(implementation)` after delay checks.
5. Optionally cancel queued intents with `cancelUpgradeIntent()`.
6. Implement `_applyUpgrade` with protocol-specific upgrade logic.

## Behavior

- `UPGRADER_ROLE` gates queue/cancel/execute operations.
- Queued implementation must be nonzero.
- Execution requires a queued intent and exact implementation match.
- Execution before `executeAfter` reverts.
- When `minUpgradeDelay == 0`, queue and execute can happen immediately.
- Intent is cleared on cancel and after successful execution.

## Opt-In Usage

When a deployment chooses to use this module, inherit from `UpgradeGuardrails`,
call the internal initializer from a constructor, facet, or init contract, and
implement `_applyUpgrade(address)` for that deployment's own upgrade primitive:

```solidity
function initUpgradeGuardrails(address initialUpgrader, uint64 minDelaySeconds) external {
    _initializeUpgradeGuardrails(initialUpgrader, minDelaySeconds);
}
```

No concrete diamond-cut subclass exists in this repository today. The current
diamond cut payload shape includes `FacetCut[]`, an init target, and init
calldata, while this module queues only an implementation address. A future
diamond integration should define explicit queued cut-payload or cut-hash
semantics before wiring this module into `diamondCut`.

## Example

```solidity
contract MyUpgradeController is UpgradeGuardrails {
    constructor(address admin, uint64 delay) UpgradeGuardrails(admin, delay) {}

    function _applyUpgrade(address implementation) internal override {
        // call this deployment's upgrade primitive here
    }
}
```
