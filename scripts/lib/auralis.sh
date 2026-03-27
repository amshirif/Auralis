#!/usr/bin/env bash

AURALIS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AURALIS_STATE_DIR="${AURALIS_ROOT}/.auralis"
AURALIS_DEPLOYMENTS_DIR="${AURALIS_ROOT}/deployments"
AURALIS_ARTIFACT_PATH="${AURALIS_DEPLOYMENTS_DIR}/auralis.local.json"
AURALIS_ERC20_ARTIFACT_PATH="${AURALIS_DEPLOYMENTS_DIR}/diamond-erc20.local.json"
AURALIS_ERC721_ARTIFACT_PATH="${AURALIS_DEPLOYMENTS_DIR}/diamond-erc721.local.json"
AURALIS_VAULT_ARTIFACT_PATH="${AURALIS_DEPLOYMENTS_DIR}/diamond-vault.local.json"
AURALIS_ANVIL_PID_PATH="${AURALIS_STATE_DIR}/anvil.pid"
AURALIS_ANVIL_LOG_PATH="${ANVIL_LOG_PATH:-${AURALIS_STATE_DIR}/anvil.log}"
AURALIS_OWNER_PRIVATE_KEY="${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
AURALIS_ALICE_PRIVATE_KEY="${ALICE_PRIVATE_KEY:-0x59c6995e998f97a5a0044976f094538e0d7bafad8d4d49d7dc1f6c4b2f6e6d5f}"
AURALIS_HOST="${ANVIL_HOST:-127.0.0.1}"
AURALIS_PORT="${ANVIL_PORT:-8545}"
AURALIS_CHAIN_ID="${ANVIL_CHAIN_ID:-31337}"
AURALIS_RPC_URL="${RPC_URL:-http://${AURALIS_HOST}:${AURALIS_PORT}}"

AURALIS_OWNER_ADDRESS=""
AURALIS_ALICE_ADDRESS=""

auralis_export_env() {
  export PRIVATE_KEY="${AURALIS_OWNER_PRIVATE_KEY}"
  export ALICE_PRIVATE_KEY="${AURALIS_ALICE_PRIVATE_KEY}"
  export ANVIL_HOST="${AURALIS_HOST}"
  export ANVIL_PORT="${AURALIS_PORT}"
  export ANVIL_CHAIN_ID="${AURALIS_CHAIN_ID}"
  export RPC_URL="${AURALIS_RPC_URL}"
  export NO_PROXY="${NO_PROXY:-127.0.0.1,localhost}"
  unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy

  mkdir -p "${AURALIS_STATE_DIR}" "${AURALIS_DEPLOYMENTS_DIR}"

  if [[ -z "${AURALIS_OWNER_ADDRESS}" ]]; then
    AURALIS_OWNER_ADDRESS="$(cast wallet address --private-key "${AURALIS_OWNER_PRIVATE_KEY}")"
  fi
  if [[ -z "${AURALIS_ALICE_ADDRESS}" ]]; then
    AURALIS_ALICE_ADDRESS="$(cast wallet address --private-key "${AURALIS_ALICE_PRIVATE_KEY}")"
  fi
}

auralis_note() {
  printf '==> %s\n' "$1"
}

auralis_json_get() {
  python3 - "$1" "$2" <<'PY'
import json
import sys

path = sys.argv[2].split('.')
value = json.load(open(sys.argv[1], 'r', encoding='utf-8'))
for part in path:
    value = value[part]
if isinstance(value, bool):
    print('true' if value else 'false')
elif value is None:
    print('null')
else:
    print(value)
PY
}

auralis_rpc_ready() {
  cast block-number --rpc-url "${AURALIS_RPC_URL}" >/dev/null 2>&1
}

auralis_wait_for_rpc() {
  for _ in {1..30}; do
    if auralis_rpc_ready; then
      return 0
    fi
    sleep 1
  done

  return 1
}

auralis_start_anvil_if_needed() {
  if auralis_rpc_ready; then
    auralis_note "Using existing Anvil at ${AURALIS_RPC_URL}"
    return 0
  fi

  auralis_note "Starting Anvil at ${AURALIS_RPC_URL}"
  nohup anvil --host "${AURALIS_HOST}" --port "${AURALIS_PORT}" --chain-id "${AURALIS_CHAIN_ID}" >"${AURALIS_ANVIL_LOG_PATH}" 2>&1 < /dev/null &
  echo $! >"${AURALIS_ANVIL_PID_PATH}"

  if ! auralis_wait_for_rpc; then
    echo "Anvil did not become ready. See ${AURALIS_ANVIL_LOG_PATH}." >&2
    return 1
  fi
}

auralis_stop_managed_anvil() {
  if [[ ! -f "${AURALIS_ANVIL_PID_PATH}" ]]; then
    return 0
  fi

  local pid
  pid="$(cat "${AURALIS_ANVIL_PID_PATH}")"
  if [[ -n "${pid}" ]] && kill -0 "${pid}" >/dev/null 2>&1; then
    kill "${pid}" >/dev/null 2>&1 || true
    wait "${pid}" >/dev/null 2>&1 || true
  fi
  rm -f "${AURALIS_ANVIL_PID_PATH}"
}

auralis_require_artifact() {
  if [[ ! -f "${AURALIS_ARTIFACT_PATH}" ]]; then
    echo "Missing ${AURALIS_ARTIFACT_PATH}. Run scripts/auralis-up.sh first." >&2
    return 1
  fi
  if ! auralis_rpc_ready; then
    echo "RPC ${AURALIS_RPC_URL} is not reachable. Start Anvil or rerun scripts/auralis-up.sh." >&2
    return 1
  fi
}

auralis_remove_artifacts() {
  rm -f \
    "${AURALIS_ARTIFACT_PATH}" \
    "${AURALIS_ERC20_ARTIFACT_PATH}" \
    "${AURALIS_ERC721_ARTIFACT_PATH}" \
    "${AURALIS_VAULT_ARTIFACT_PATH}"
}

auralis_write_unified_artifact() {
  python3 - "${AURALIS_ERC20_ARTIFACT_PATH}" "${AURALIS_ERC721_ARTIFACT_PATH}" "${AURALIS_VAULT_ARTIFACT_PATH}" "${AURALIS_ARTIFACT_PATH}" "${AURALIS_RPC_URL}" "${AURALIS_OWNER_ADDRESS}" "${AURALIS_ALICE_ADDRESS}" <<'PY'
import json
import sys
from pathlib import Path

erc20 = json.load(open(sys.argv[1], 'r', encoding='utf-8'))
erc721 = json.load(open(sys.argv[2], 'r', encoding='utf-8'))
vault = json.load(open(sys.argv[3], 'r', encoding='utf-8'))
out_path = Path(sys.argv[4])
rpc_url = sys.argv[5]
owner = sys.argv[6]
alice = sys.argv[7]

artifact = {
    'project': 'Auralis',
    'network': 'local-anvil',
    'chainId': vault['chainId'],
    'rpcUrl': rpc_url,
    'actors': {
        'owner': owner,
        'alice': alice,
    },
    'erc20Host': {
        **erc20,
        'label': 'ERC20 host',
    },
    'erc721Host': {
        **erc721,
        'label': 'ERC721 host',
    },
    'vaultHost': {
        **vault,
        'label': 'Vault host',
    },
}

out_path.write_text(json.dumps(artifact, indent=2) + '\n', encoding='utf-8')
PY
}

auralis_fund_actor() {
  local recipient="$1"
  local value_wei="${2:-1000000000000000000}"
  cast send --rpc-url "${AURALIS_RPC_URL}" --private-key "${AURALIS_OWNER_PRIVATE_KEY}" --value "${value_wei}" "${recipient}" >/dev/null
}

