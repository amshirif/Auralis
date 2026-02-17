# Repository Governance

This document defines ownership and merge controls for this repository.

## CODEOWNERS Policy

Repository ownership is defined in `.github/CODEOWNERS`.

Current owner map:
- Global default owner: `@amshirif`
- Contracts and interfaces: `/src/`
- Tests: `/test/`
- Workflows: `/.github/workflows/`
- Documentation: `/docs/`

## Branch Protection Target State

Apply protections to:
- `main`
- `milestone/**`

Required settings:
- Require a pull request before merging.
- Require approvals.
- Require review from code owners.
- Require status checks to pass.
- Require linear history.
- Block force pushes.
- Restrict branch deletion.

## Required Status Checks

Once branch protection is available, configure these checks as required:
- `Foundry Checks`
- `Slither`

Conditionally required (only after enabled in private repo):
- `Dependency Review`

## Platform Constraint

This repository currently receives `403` responses for branch protection/ruleset APIs:
- `GET /repos/{owner}/{repo}/branches/{branch}/protection`
- `GET /repos/{owner}/{repo}/rulesets`

GitHub indicates branch protection/ruleset features require a higher plan tier for this private repository.

## Interim Operating Policy (Until Protection Is Available)

- Do not push directly to `main`.
- Use issue branches and PRs into milestone branches.
- Merge milestone branches into `main` only via PR.
- Do not force-push milestone or `main` branches.
- Treat CI checks (`Foundry CI`, `Slither`) as merge gates.
