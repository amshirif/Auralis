# Milestone Close Checklist

Use this checklist before merging a milestone branch into `main`.

## 1. Issue Hygiene

- All milestone issues are closed or explicitly deferred.
- Parent milestone issue includes final scope summary.
- Blocking relationships are updated and resolved.

## 2. Branch and PR Hygiene

- Milestone branch is up to date with child PR merges.
- Final milestone PR to `main` has:
  - clear summary
  - test/security evidence
  - linked issues

## 3. Validation Evidence

- CI checks are green on milestone PR.
- Required local checks were run and documented:
  - `forge fmt --check`
  - `forge build --sizes`
  - `forge test --offline`
  - `forge coverage --offline`

## 4. Security and Operations

- Slither and dependency review status reviewed (as enabled).
- Relevant runbooks are updated for new controls.
- Residual risks are documented in threat model or milestone PR notes.

## 5. Release Readiness

- Version bump decision made (patch/minor/major).
- Release notes draft prepared from template.
- Tag and release plan confirmed.

## 6. Post-Merge Tasks

- Merge milestone branch into `main`.
- Publish release/tag if in scope.
- Start next milestone branch and seed initial issues.
