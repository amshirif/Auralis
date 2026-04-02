#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/auralis.sh"

auralis_export_env
auralis_require_artifact

erc20_diamond="$(auralis_json_get "${AURALIS_ARTIFACT_PATH}" erc20Host.diamond)"
erc721_diamond="$(auralis_json_get "${AURALIS_ARTIFACT_PATH}" erc721Host.diamond)"
vault_diamond="$(auralis_json_get "${AURALIS_ARTIFACT_PATH}" vaultHost.diamond)"
vault_asset="$(auralis_json_get "${AURALIS_ARTIFACT_PATH}" vaultHost.vaultAsset)"
oracle_feed="$(auralis_json_get "${AURALIS_ARTIFACT_PATH}" vaultHost.oracleFeed)"
strategy="$(auralis_json_get "${AURALIS_ARTIFACT_PATH}" vaultHost.strategy)"

now_ts="$(date +%s)"

auralis_note "Minting additional ERC20 liquidity"
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${erc20_diamond}" "mint(address,uint256)" "${AURALIS_ALICE_ADDRESS}" 5000000000000000000000 >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_ALICE_PRIVATE_KEY}" \
  "${erc20_diamond}" "approve(address,uint256)" "${AURALIS_OWNER_ADDRESS}" 1000000000000000000000 >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${erc20_diamond}" "transferFrom(address,address,uint256)" "${AURALIS_ALICE_ADDRESS}" "${AURALIS_OWNER_ADDRESS}" 300000000000000000000 >/dev/null

auralis_note "Minting and moving an ERC721 collectible"
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${erc721_diamond}" "mint(address,uint256)" "${AURALIS_OWNER_ADDRESS}" 2 >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${erc721_diamond}" "approve(address,uint256)" "${AURALIS_ALICE_ADDRESS}" 2 >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_ALICE_PRIVATE_KEY}" \
  "${erc721_diamond}" "transferFrom(address,address,uint256)" "${AURALIS_OWNER_ADDRESS}" "${AURALIS_ALICE_ADDRESS}" 2 >/dev/null

auralis_note "Generating vault and strategy activity"
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${vault_asset}" "mint(address,uint256)" "${AURALIS_ALICE_ADDRESS}" 4000000000 >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_ALICE_PRIVATE_KEY}" \
  "${vault_asset}" "approve(address,uint256)" "${vault_diamond}" 4000000000 >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_ALICE_PRIVATE_KEY}" \
  "${vault_diamond}" "deposit(uint256,address)(uint256)" 1250000000 "${AURALIS_ALICE_ADDRESS}" >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${vault_diamond}" "deployToStrategy(uint256)" 750000000 >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${strategy}" "injectProfit(uint256)" 125000000 >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${vault_diamond}" "syncStrategyAssets()" >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${vault_diamond}" "withdrawFromStrategy(uint256)(uint256)" 200000000 >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_ALICE_PRIVATE_KEY}" \
  "${vault_diamond}" "transfer(address,uint256)" "${AURALIS_OWNER_ADDRESS}" 250000000 >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${vault_diamond}" "redeem(uint256,address,address)(uint256)" 100000000 "${AURALIS_OWNER_ADDRESS}" "${AURALIS_OWNER_ADDRESS}" >/dev/null

auralis_note "Updating oracle and pause state"
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${oracle_feed}" "setRoundData(int256,uint256)" 102000000 "${now_ts}" >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${vault_diamond}" "pause()" >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${vault_diamond}" "unpause()" >/dev/null

idle_assets="$(cast call --rpc-url "${AURALIS_RPC_URL}" "${vault_diamond}" "idleAssets()(uint256)" | awk '{print $1}')"
strategy_debt="$(cast call --rpc-url "${AURALIS_RPC_URL}" "${vault_diamond}" "strategyDebt()(uint256)" | awk '{print $1}')"
live_strategy_assets="$(cast call --rpc-url "${AURALIS_RPC_URL}" "${vault_diamond}" "liveStrategyAssets()(uint256)" | awk '{print $1}')"
total_assets="$(cast call --rpc-url "${AURALIS_RPC_URL}" "${vault_diamond}" "totalAssets()(uint256)" | awk '{print $1}')"
quote_tuple="$(cast call --rpc-url "${AURALIS_RPC_URL}" "${vault_diamond}" "oracleQuote()((int256,uint64,uint8))")"

cat <<MSG
Auralis simulated activity complete.

Idle assets: ${idle_assets}
Strategy debt: ${strategy_debt}
Live strategy assets: ${live_strategy_assets}
Total assets: ${total_assets}
Oracle quote tuple: ${quote_tuple}

The local chain now has representative token, NFT, vault, oracle, and live strategy lifecycle activity.
MSG
