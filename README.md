# smart-contracts

![Solidity](https://img.shields.io/badge/Solidity-0.8.30-363636?logo=solidity)
![License](https://img.shields.io/github/license/amshirif/smart-contracts)

Portfolio-focused Solidity modules built with Foundry. The codebase is kept
dependency-light and "diamond-ready" so core modules can later be wrapped as
facets without a full rewrite.

## Goals
- Security-first primitives with clear admin and upgrade boundaries.
- Clean, testable modules with minimal external dependencies.
- Diamond-ready storage patterns for future EIP-2535 integration.
- Global and scope-level emergency controls for safer operations.

## Structure
- `src/access`: access control and upgrade-safety primitives.
- `src/access/storage`: module-local storage libraries (diamond-ready slots).
- `src/security`: security primitives such as reentrancy protection.
- `src/security/storage`: module-local storage libraries (diamond-ready slots).
- `src/upgrade`: upgrade authorization and execution guardrails.
- `src/upgrade/storage`: module-local storage libraries (diamond-ready slots).
- `src/interfaces`: local interfaces (ERC-165, `IAccessControl`, `IAccessControlTime`, `IPausable`, `IReentrancyGuard`, `IUpgradeGuardrails`, etc.).
- `src/libraries`: shared cross-module libraries.
- `test`: split by concern (`*Core.t.sol`, `*Time.t.sol`, `*Integration.t.sol`).
- `test/helpers`: shared test fixtures and harnesses.
- `docs`: usage notes and design decisions.

## Commands
```shell
forge build
forge test
forge coverage
forge fmt
```

## Testing
- Convention guide: `docs/testing-conventions.md`

## Module Docs
- Access control: `docs/access-control.md`
- Pausability: `docs/pausable.md`
- Reentrancy guard: `docs/reentrancy-guard.md`
- Upgrade guardrails: `docs/upgrade-guardrails.md`

## Tooling
- Foundry docs: [book.getfoundry.sh](https://book.getfoundry.sh/)
