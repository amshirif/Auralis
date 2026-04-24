# Contributing

`Auralis` is a personal protocol-engineering portfolio repository. External
feedback is welcome, but this repo is not operated as an open community project
or production support channel.

## Workflow

- Start implementation work from a GitHub issue.
- Branch from the active `milestone/*` branch.
- Open task PRs back into the active milestone branch, not directly into
  `main`.
- Include `Closes #<issue-number>` in the PR body.
- Keep changes scoped to the issue being addressed.

The detailed local workflow is documented in
`docs/ops/workflow-conventions.md`.

## Validation Expectations

Run the checks that match the change scope before requesting review. For most
contract or test changes, start with:

```shell
forge fmt --check
forge build --sizes --skip script
forge test --offline
```

Documentation-only changes should still run `forge fmt --check` and a build
when practical so the repository remains reviewer-ready.

## Public Metadata Choices

This repository intentionally keeps only the public metadata that matches its
portfolio scope:

- `CONTRIBUTING.md` documents the issue and PR workflow.
- `SECURITY.md` documents the security-reporting posture.
- `CHANGELOG.md` documents public release history.
- `.github` templates guide future issues and PRs.

The repo does not currently include `CODE_OF_CONDUCT.md`, `SUPPORT.md`, or
`FUNDING.yml`. Those files are intentionally omitted because this is not an
open community project, a funded project, or a production support channel.
