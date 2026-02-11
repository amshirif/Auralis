# Pausable

This module adds role-gated pause controls for both:
- a global protocol-wide emergency stop
- independent scoped pauses for specific flows

## Usage

1. Inherit from `Pausable`.
2. `PAUSER_ROLE` is granted to the initial admin at construction.
3. Protect globally critical paths with `whenNotPaused`.
4. Protect scope-specific paths with `whenScopeNotPaused(SCOPE)`.
5. Protect emergency-only handlers with `whenPaused` or `whenScopePaused(SCOPE)`.
6. Use `pause`/`unpause` for global controls, and `pauseScope`/`unpauseScope` for independent flows.

## Behavior

- `pause` and `unpause` require `PAUSER_ROLE`.
- `pauseScope` and `unpauseScope` require `PAUSER_ROLE`.
- Calling `pause` while paused reverts with `PausableEnforcedPause`.
- Calling `unpause` while unpaused reverts with `PausableExpectedPause`.
- Calling `pauseScope` while that scope is paused reverts with `PausableScopeEnforcedPause`.
- Calling `unpauseScope` while that scope is unpaused reverts with `PausableScopeExpectedPause`.
- Scope `bytes32(0)` is rejected with `PausableZeroScope`.
- `paused()` returns global pause state.
- `scopePaused(scope)` returns local scope pause state.
- `paused(scope)` returns effective scope state (global OR local scope pause).
- Global pause overrides all scope checks.

## Diamond-Ready Usage

When used behind a diamond proxy, call the internal initializer from a facet or
init contract:

```solidity
function initPausable(address initialPauser) external {
    _initializePausable(initialPauser);
}
```

## Example

```solidity
contract MyModule is Pausable {
    bytes32 internal constant WITHDRAWALS_SCOPE = keccak256("WITHDRAWALS_SCOPE");

    constructor(address admin) Pausable(admin) {}

    function criticalOperation() external whenNotPaused {
        // ...
    }

    function withdrawals() external whenScopeNotPaused(WITHDRAWALS_SCOPE) {
        // ...
    }

    function emergencyOperation() external whenScopePaused(WITHDRAWALS_SCOPE) {
        // ...
    }
}
```
