# Auralis Local Workflow

`Auralis` ships with a local-first workflow for bootstrapping the token hosts,
vault host, and a small amount of simulated protocol activity on Anvil.

## Prerequisites

- `anvil`
- `forge`
- `cast`
- Python 3

The scripts assume the default local Anvil account key unless overridden with
`PRIVATE_KEY` and `ALICE_PRIVATE_KEY`.

## Commands

Bootstrap the full local environment:

```shell
bash scripts/auralis-up.sh
```

Smoke-check the deployed stack:

```shell
bash scripts/auralis-smoke.sh
```

Generate simulated local activity:

```shell
bash scripts/auralis-activity.sh
```

Reset local artifacts and stop the managed Anvil process:

```shell
bash scripts/auralis-reset.sh
```

## What The Scripts Do

`auralis-up.sh`
- starts Anvil if one is not already available
- deploys the ERC20 host, ERC721 host, and vault host
- writes `deployments/auralis.local.json`

`auralis-smoke.sh`
- checks deployed code is present
- runs token, NFT, and vault happy-path transactions
- verifies the vault oracle quote path is live

`auralis-activity.sh`
- generates deterministic demo traffic across the deployed hosts
- mints and transfers ERC20 balances
- mints and moves an ERC721 token
- deposits into the vault, moves shares, redeems shares, updates the oracle, and reports strategy assets

`auralis-reset.sh`
- stops the managed Anvil process if `auralis-up.sh` started it
- removes the Auralis deployment artifacts

## Artifact Layout

`deployments/auralis.local.json` combines the host-specific deployment outputs
and records:

- RPC URL
- chain id
- owner/alice actor addresses
- ERC20 host addresses
- ERC721 host addresses
- vault host addresses

## Simulated Activity

The activity script is explicitly demo traffic for local development and review.
It is meant to create realistic event history and state transitions, not to
model production usage or strategy execution.
