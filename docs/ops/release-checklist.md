# Release Checklist

Use this checklist before tagging and publishing a new release.

## 1. Scope and Versioning

- Confirm merged PR scope for the release.
- Choose semantic version bump:
  - patch: fixes/docs/test-only
  - minor: backwards-compatible features
  - major: breaking interface or behavior changes
- Confirm target tag format (for example `v0.2.0`).

## 2. Changelog and Notes

- Draft release notes using `docs/ops/release-notes-template.md`.
- Include:
  - highlights
  - security-impacting changes
  - migration notes
  - linked PRs/issues
- Confirm closed issues and milestone status match release notes.

## 3. Validation Gates

Run and record:

```bash
forge fmt --check
forge build --sizes
forge test --offline
forge coverage --offline
```

Required outcomes:
- no formatting violations
- no build failures
- no failing tests
- coverage report generated and reviewed for regressions in touched modules
- deployment-backed validation run where the release scope touches diamond or
  system-hardening flows:
  - `bash script/run-local-system-hardening.sh`

## 4. Security/Quality Gates

- Confirm CI status is green for:
  - Foundry CI
  - System Hardening
  - Slither
  - Dependency Review (when enabled)
- Confirm no unresolved high-severity findings introduced by this release.

## 5. Publish

- Create and push tag.
- Publish GitHub release with finalized notes.
- Attach milestone and key issue links.

## 6. Post-Release

- Verify release artifact and commit hash correctness.
- Announce release summary (internal/public channel as appropriate).
- Track follow-up items in a post-release issue if needed.
