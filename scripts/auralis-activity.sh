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

auralis_note "Generating vault flow activity"
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${vault_asset}" "mint(address,uint256)" "${AURALIS_ALICE_ADDRESS}" 4000000000 >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_ALICE_PRIVATE_KEY}" \
  "${vault_asset}" "approve(address,uint256)" "${vault_diamond}" 4000000000 >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_ALICE_PRIVATE_KEY}" \
  "${vault_diamond}" "deposit(uint256,address)(uint256)" 1250000000 "${AURALIS_ALICE_ADDRESS}" >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_ALICE_PRIVATE_KEY}" \
  "${vault_diamond}" "transfer(address,uint256)" "${AURALIS_OWNER_ADDRESS}" 250000000 >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${vault_diamond}" "redeem(uint256,address,address)(uint256)" 100000000 "${AURALIS_OWNER_ADDRESS}" "${AURALIS_OWNER_ADDRESS}" >/dev/null

auralis_note "Updating oracle and strategy reporting"
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${oracle_feed}" "setRoundData(int256,uint256)" 102000000 "${now_ts}" >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${vault_diamond}" "setStrategy(address)" "${AURALIS_ALICE_ADDRESS}" >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_ALICE_PRIVATE_KEY}" \
  "${vault_diamond}" "reportStrategyAssets(uint256)" 275000000 >/dev/null

auralis_note "Toggling global pause state"
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${vault_diamond}" "pause()" >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${vault_diamond}" "unpause()" >/dev/null

estimated_assets="$(cast call --rpc-url "${AURALIS_RPC_URL}" "${vault_diamond}" "estimatedTotalManagedAssets()(uint256)" | awk '{print $1}')"
quote_tuple="$(cast call --rpc-url "${AURALIS_RPC_URL}" "${vault_diamond}" "oracleQuote()((int256,uint64,uint8))")"

cat <<MSG
Auralis simulated activity complete.

Estimated managed assets: ${estimated_assets}
Oracle quote tuple: ${quote_tuple}

The local chain now has representative token, NFT, vault, oracle, and strategy-report activity.
MSG
