# Reentrancy Guard

This module provides a dependency-light `nonReentrant` guard using
diamond-ready storage.

## Usage

1. Inherit from `ReentrancyGuard`.
2. Add `nonReentrant` to state-changing external entrypoints.
3. Avoid calling one `nonReentrant` function from another `nonReentrant` function.

## Behavior

- Reentrant calls revert with `ReentrancyGuardReentrantCall`.
- Nested `nonReentrant` calls in the same call stack revert.
- Successful calls reset guard state at the end of execution.

## Diamond-Ready Usage

When used behind a diamond proxy, call the internal initializer from a facet or
init contract:

```solidity
function initReentrancyGuard() external {
    _initializeReentrancyGuard();
}
```

## Composition Notes

- Composes with `AccessControl` and `Pausable`.
- In composed modules, protect critical external entrypoints with both:
  - role/pause checks (`onlyRole`, `whenNotPaused`, etc.)
  - `nonReentrant`

