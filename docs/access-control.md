# Access Control

This module provides a minimal role-based access control (RBAC) system with
an admin hierarchy. Roles default to being administered by `DEFAULT_ADMIN_ROLE`.
It also supports ERC-165 interface detection and role member enumeration.
The storage layout is diamond-ready via a fixed storage slot library.
It supports optional time windows per `(role, account)` for temporary access.

## Usage

1. Inherit from `AccessControl` (implements `IAccessControl` and `IAccessControlTime`).
2. Pass the initial admin to the constructor.
3. Define roles as `bytes32` constants.
4. Protect functions with `onlyRole(ROLE)`.
5. Optionally change role admins with `_setRoleAdmin`.
6. Use `getRoleMemberCount` and `getRoleMember` to enumerate role members.
7. Use `setRoleWindow` and `clearRoleWindow` to manage temporary role activity.
8. Use `grantRoleWithWindow` for one-transaction role + window assignment.
9. Protect time-gated flows with `onlyActiveRole(ROLE)`.

## Diamond-Ready Usage

When used behind a diamond proxy, call the internal initializer from a facet or init
contract instead of relying on the constructor.

```solidity
function init(address admin) external {
    _initializeAccessControl(admin);
}
```

## Upgrade Compatibility Boundary

The current hosted-vault upgrade story only claims compatibility for
access-control state created on the current
`keccak256("auralis.access-control.storage")` namespace.

Older pre-public deployments created before the namespace rename from
`smart-contracts.access-control.storage` are not claimed as in-place upgrade
compatible. If those deployments ever matter, they require a redeploy or an
explicit migration plan rather than a same-address facet replacement.

## Time Window Semantics

- Time windows are optional and stored per `(role, account)`.
- Time windows can be pre-set before role grant.
- `hasRole` is unchanged and does not require a window.
- `hasActiveRole` requires both:
  - account has the role
  - configured window is active
- Active window condition: `start <= block.timestamp < end`.
- `end == 0` means no expiry.
- Window operations and role grant/revoke reject `address(0)` accounts.

## Example

```solidity
contract MyContract is AccessControl {
    bytes32 public constant WRITER_ROLE = keccak256("WRITER_ROLE");

    constructor(address admin) AccessControl(admin) {}

    function write() external onlyRole(WRITER_ROLE) {
        // ...
    }

    function writeTemporarily() external onlyActiveRole(WRITER_ROLE) {
        // ...
    }
}
```
