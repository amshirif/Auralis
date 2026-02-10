# Access Control

This module provides a minimal role-based access control (RBAC) system with
an admin hierarchy. Roles default to being administered by `DEFAULT_ADMIN_ROLE`.
It also supports ERC-165 interface detection and role member enumeration.
The storage layout is diamond-ready via a fixed storage slot library.

## Usage

1. Inherit from `AccessControl` (implements `IAccessControl`).
2. Pass the initial admin to the constructor.
3. Define roles as `bytes32` constants.
4. Protect functions with `onlyRole(ROLE)`.
5. Optionally change role admins with `_setRoleAdmin`.
6. Use `getRoleMemberCount` and `getRoleMember` to enumerate role members.

## Diamond-Ready Usage

When used behind a diamond proxy, call the internal initializer from a facet or init
contract instead of relying on the constructor.

```solidity
function init(address admin) external {
    _initializeAccessControl(admin);
}
```

## Example

```solidity
contract MyContract is AccessControl {
    bytes32 public constant WRITER_ROLE = keccak256("WRITER_ROLE");

    constructor(address admin) AccessControl(admin) {}

    function write() external onlyRole(WRITER_ROLE) {
        // ...
    }
}
```
