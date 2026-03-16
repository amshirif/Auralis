# Runbook: System Hardening Validation

Use this runbook when validating a milestone branch, reproducing CI failures, or
reviewing the repository's deployment-backed safety checks end to end.

## Recommended Local Execution Order

1. Bootstrap the diamond core if you want the raw deployment step by itself:

```shell
forge script script/DeployDiamondCore.s.sol:DeployDiamondCoreScript \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast
```

2. Run the local smoke flow:

```shell
bash script/run-local-diamond-smoke.sh
```

3. Run the local upgrade rehearsal:

```shell
bash script/run-local-diamond-upgrade-rehearsal.sh
```

4. Run the targeted system suites:

```shell
forge test --offline --match-path test/SystemVaultStressInvariant.t.sol
forge test --offline --match-path test/SystemOracleFailureScenarios.t.sol
```

5. Run the full local hardening entrypoint when you want the entire sequence in
one command:

```shell
bash script/run-local-system-hardening.sh
```

## Expected Outputs And Artifacts

- Bootstrap writes `deployments/diamond-core.local.json`
- Upgrade rehearsal writes `deployments/diamond-core.upgrade-rehearsal.local.json`
- Smoke flow writes `.anvil-smoke.log`
- Upgrade rehearsal writes `.anvil-upgrade-rehearsal.log`
- Successful local flows end with:
  - `Local diamond smoke flow passed.`
  - `Local diamond upgrade rehearsal passed.`
  - `Local system hardening flow passed.`

## Failure Interpretation

- Bootstrap failures usually indicate local RPC readiness problems, deploy
  script issues, or missing artifact output.
- Smoke flow failures point to ownership, loupe, selector routing, or live
  state-transition regressions after deployment.
- Upgrade rehearsal failures point to selector-collision handling, failed-cut
  atomicity, init rollback, owner drift, or selector ownership drift.
- Targeted system suite failures point to vault accounting/pause/reentrancy
  regressions or oracle incident-handling regressions.
- If the full hardening runner fails, inspect the first failing sub-step before
  rerunning the full sequence.

## CI Equivalents

- `Foundry CI / Foundry Checks`
  - baseline formatting, build, and full offline test suite
- `System Hardening / Targeted System Suites`
  - targeted vault/oracle system suites
- `System Hardening / Full Local Hardening Flow`
  - `bash script/run-local-system-hardening.sh`

Use the local commands above to reproduce CI behavior before requesting review
or after a failing run.

## Assumptions

- The flows assume deterministic local Anvil defaults unless environment
  variables override them.
- The operator sequence here is for the current diamond/system-hardening
  milestone, not a future multi-module production deployment.
- Remaining out-of-scope and trust assumptions are tracked in
  `docs/system-hardening.md`.
