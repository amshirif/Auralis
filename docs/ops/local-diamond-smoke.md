# Local Diamond Smoke Flow

This repo now includes a deterministic local smoke flow for the deployed diamond
core.

## What It Covers

- boots a fresh local Anvil chain
- deploys the reference diamond core through the Foundry bootstrap script
- validates live loupe and ownership routing from the deployment artifact
- executes a real ownership transfer on the deployed diamond
- revalidates the post-transfer state

The smoke flow runs against deployed contracts on a local RPC target rather than
only isolated harnesses.

## Run

```shell
bash script/run-local-diamond-smoke.sh
```

## Default Environment

The runner uses Anvil defaults unless overridden:

- `ANVIL_HOST=127.0.0.1`
- `ANVIL_PORT=8545`
- `ANVIL_CHAIN_ID=31337`
- `PRIVATE_KEY=<anvil account 0>`
- `NEXT_OWNER_PRIVATE_KEY=<deterministic local test key>`

It also clears proxy environment variables so local RPC calls do not get routed
through a system proxy.

## Output

- deployment artifact: `deployments/diamond-core.local.json`
- Anvil log: `.anvil-smoke.log`

This flow is intended to become the baseline smoke suite reused by later
upgrade rehearsal and CI work.

## Success Signals

The flow succeeds only if all of the following hold:

- the deployed diamond routes loupe selectors correctly
- the live owner can be read and updated
- ownership state remains correct after the transfer check
- the script ends with `Local diamond smoke flow passed.`

## Failure Interpretation

- Artifact read failures usually mean bootstrap did not complete correctly.
- Loupe or ownership mismatches indicate selector-routing or state-surface
  regressions.
- Ownership transfer validation failures indicate deployed admin flows are not
  behaving as expected.

Use this flow before the upgrade rehearsal when you want the simplest
deployment-backed validation pass.
