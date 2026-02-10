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

## Structure
- `src/access`: access control and upgrade-safety primitives.
- `src/interfaces`: local interfaces (ERC-165, RBAC, etc.).
- `test`: Foundry tests and coverage.
- `docs`: usage notes and design decisions.

## Commands
```shell
forge build
forge test
forge coverage
forge fmt
```

## Tooling
- Foundry docs: [book.getfoundry.sh](https://book.getfoundry.sh/)
