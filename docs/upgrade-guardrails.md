# Upgrade Guardrails

This module adds role-gated controls for upgrade operations with queue/execute
guardrails and an optional timelock.

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

## Diamond-Ready Usage

When used behind a diamond proxy, call the internal initializer from a facet or
init contract:

```solidity
function initUpgradeGuardrails(address initialUpgrader, uint64 minDelaySeconds) external {
    _initializeUpgradeGuardrails(initialUpgrader, minDelaySeconds);
}
```

## Example

```solidity
contract MyUpgradeController is UpgradeGuardrails {
    constructor(address admin, uint64 delay) UpgradeGuardrails(admin, delay) {}

    function _applyUpgrade(address implementation) internal override {
        // call proxy/diamond upgrade primitive here
    }
}
```

