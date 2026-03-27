#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/auralis.sh"

auralis_export_env
auralis_require_artifact

erc20_diamond="$(auralis_json_get "${AURALIS_ARTIFACT_PATH}" erc20Host.diamond)"
erc721_diamond="$(auralis_json_get "${AURALIS_ARTIFACT_PATH}" erc721Host.diamond)"
vault_diamond="$(auralis_json_get "${AURALIS_ARTIFACT_PATH}" vaultHost.diamond)"
vault_asset="$(auralis_json_get "${AURALIS_ARTIFACT_PATH}" vaultHost.vaultAsset)"
oracle_adapter="$(auralis_json_get "${AURALIS_ARTIFACT_PATH}" vaultHost.oracleAdapter)"

for address in "${erc20_diamond}" "${erc721_diamond}" "${vault_diamond}" "${vault_asset}" "${oracle_adapter}"; do
  code="$(cast code --rpc-url "${AURALIS_RPC_URL}" "${address}")"
  if [[ "${code}" == "0x" ]]; then
    echo "Expected deployed code at ${address}, found empty code." >&2
    exit 1
  fi
done

auralis_note "ERC20 host smoke: mint and transfer"
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${erc20_diamond}" "mint(address,uint256)" "${AURALIS_ALICE_ADDRESS}" 1000000000000000000000 >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_ALICE_PRIVATE_KEY}" \
  "${erc20_diamond}" "transfer(address,uint256)" "${AURALIS_OWNER_ADDRESS}" 250000000000000000000 >/dev/null
alice_erc20_balance="$(cast call --rpc-url "${AURALIS_RPC_URL}" "${erc20_diamond}" "balanceOf(address)(uint256)" "${AURALIS_ALICE_ADDRESS}" | awk '{print $1}')"
if [[ "${alice_erc20_balance}" != "750000000000000000000" ]]; then
  echo "Unexpected ERC20 balance after smoke flow: ${alice_erc20_balance}" >&2
  exit 1
fi

auralis_note "ERC721 host smoke: mint and transfer"
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${erc721_diamond}" "mint(address,uint256)" "${AURALIS_ALICE_ADDRESS}" 1 >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_ALICE_PRIVATE_KEY}" \
  "${erc721_diamond}" "transferFrom(address,address,uint256)" "${AURALIS_ALICE_ADDRESS}" "${AURALIS_OWNER_ADDRESS}" 1 >/dev/null
nft_owner="$(cast call --rpc-url "${AURALIS_RPC_URL}" "${erc721_diamond}" "ownerOf(uint256)(address)" 1)"
if [[ "${nft_owner,,}" != "${AURALIS_OWNER_ADDRESS,,}" ]]; then
  echo "Unexpected ERC721 owner after smoke flow: ${nft_owner}" >&2
  exit 1
fi

auralis_note "Vault host smoke: deposit, quote, and withdraw"
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" \
  "${vault_asset}" "mint(address,uint256)" "${AURALIS_ALICE_ADDRESS}" 1500000000 >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_ALICE_PRIVATE_KEY}" \
  "${vault_asset}" "approve(address,uint256)" "${vault_diamond}" 1500000000 >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_ALICE_PRIVATE_KEY}" \
  "${vault_diamond}" "deposit(uint256,address)(uint256)" 1000000000 "${AURALIS_ALICE_ADDRESS}" >/dev/null
cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_ALICE_PRIVATE_KEY}" \
  "${vault_diamond}" "withdraw(uint256,address,address)(uint256)" 250000000 "${AURALIS_ALICE_ADDRESS}" "${AURALIS_ALICE_ADDRESS}" >/dev/null
shares_after="$(cast call --rpc-url "${AURALIS_RPC_URL}" "${vault_diamond}" "balanceOf(address)(uint256)" "${AURALIS_ALICE_ADDRESS}" | awk '{print $1}')"
if [[ "${shares_after}" != "750000000" ]]; then
  echo "Unexpected vault share balance after smoke flow: ${shares_after}" >&2
  exit 1
fi
quote_tuple="$(cast call --rpc-url "${AURALIS_RPC_URL}" "${vault_diamond}" "oracleQuote()((int256,uint64,uint8))")"
if [[ -z "${quote_tuple}" ]]; then
  echo "oracleQuote() returned empty output." >&2
  exit 1
fi

auralis_note "Auralis smoke flow passed"
