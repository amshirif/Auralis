# Local Diamond Upgrade Rehearsal

This flow exercises the deployment-backed diamond upgrade path used to validate
cut behavior before production-style operator changes.

## What It Covers

- boots a fresh local Anvil chain
- deploys the reference diamond core
- executes a successful upgrade path against the deployed diamond
- validates selector ownership, loupe state, init-backed state, and owner
  continuity
- executes deliberate selector-collision and init-failure cuts
- confirms failed cuts do not leave partial selector routing behind

The rehearsal validates cut mechanics and state persistence on the current
storage-layout baseline. It does not validate storage migration across renamed
slot namespaces from older pre-public deployments.

## Run

```shell
bash script/run-local-diamond-upgrade-rehearsal.sh
```

## Default Environment

The runner uses Anvil defaults unless overridden:

- `ANVIL_HOST=127.0.0.1`
- `ANVIL_PORT=8545`
- `ANVIL_CHAIN_ID=31337`
- `PRIVATE_KEY=<anvil account 0>`

It also clears proxy environment variables so local RPC calls are kept on the
local node.

## Output

- deployment artifact: `deployments/diamond-core.local.json`
- rehearsal artifact: `deployments/diamond-core.upgrade-rehearsal.local.json`
- Anvil log: `.anvil-upgrade-rehearsal.log`

The rehearsal artifact records the deployed addresses used by the successful and
failed-cut checks:

- `diamond`
- `owner`
- `upgradeFacet`
- `initMock`
- `collisionFacet`
- `failureFacet`

## Success Signals

The flow succeeds only if all of the following hold:

- the upgrade cut executes successfully
- the expected selector owners remain in place after failure simulations
- init-backed state remains readable after failed cuts
- the owner is unchanged after the deliberate revert paths
- the script ends with `Local diamond upgrade rehearsal passed.`

## Failure Interpretation

- `Selector collision rehearsal unexpectedly succeeded.`
  - selector-collision protection regressed
- `Collision rehearsal left partial selector routing in place.`
  - failed-cut atomicity regressed
- `Init-failure rehearsal unexpectedly succeeded.`
  - init delegatecall failure was not enforced
- `Init-failure rehearsal left partial selector routing in place.`
  - init rollback regressed
- `Owner changed during failed-cut rehearsal.`
  - ownership continuity regressed across failed cuts
- `Alpha route regressed...` or `Init-backed state regressed...`
  - successful upgrade state was corrupted by later failed-cut attempts

## Where It Fits

Use this flow after the local smoke pass and before relying on the full
system-hardening runner.

It is also the local counterpart to the `System Hardening / Full Local
Hardening Flow` CI job.
