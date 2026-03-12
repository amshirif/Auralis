# Local Diamond Bootstrap

This repo now includes a reference Foundry script for bootstrapping the diamond
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

These outputs are intended to feed later E2E and upgrade rehearsal work.

## Follow-Up Smoke Checks

After bootstrap, run the local smoke suite to validate live routing and a
reference admin state transition against the deployed environment:

```shell
bash script/run-local-diamond-smoke.sh
```
