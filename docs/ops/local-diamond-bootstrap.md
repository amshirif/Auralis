# Local Diamond Bootstrap

This runbook covers the reference Foundry script used to bootstrap the diamond
core on a local Anvil chain.

## What It Deploys

- `DiamondCutFacet`
- `Diamond(initialOwner, initialCutFacet)`
- `DiamondLoupeFacet`

The script installs `diamondCut` during the diamond constructor bootstrap, then
uses `diamondCut` to add the loupe selectors.

## Prerequisites

- `anvil`
- `forge`
- `PRIVATE_KEY` set to the funded Anvil account you want to deploy from

Example Anvil default key:

```shell
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

## Run

Start Anvil:

```shell
anvil
```

Deploy and bootstrap the diamond core:

```shell
forge script script/DeployDiamondCore.s.sol:DeployDiamondCoreScript \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast
```

## Output

The script writes deployment artifacts to:

```text
deployments/diamond-core.local.json
```

Current fields:

- `network`
- `chainId`
- `owner`
- `diamond`
- `diamondCutFacet`
- `diamondLoupeFacet`

These outputs feed the downstream smoke, upgrade rehearsal, and hardening
flows.

Downstream flows that consume this artifact:

- `bash script/run-local-diamond-smoke.sh`
- `bash script/run-local-diamond-upgrade-rehearsal.sh`
- `bash script/run-local-system-hardening.sh`

## Follow-Up Smoke Checks

After bootstrap, run the local smoke suite to validate live routing and a
reference admin state transition against the deployed environment:

```shell
bash script/run-local-diamond-smoke.sh
```

## Failure Interpretation

- If Anvil never becomes reachable, inspect local RPC startup and port
  conflicts first.
- If the deployment artifact is missing or incomplete, do not continue to smoke
  or rehearsal flows.
- If constructor bootstrap or loupe installation fails, treat it as a diamond
  deployment regression and inspect the deployment script output before
  retrying.
