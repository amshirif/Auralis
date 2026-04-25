#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANVIL_HOST="${ANVIL_HOST:-127.0.0.1}"
ANVIL_PORT="${ANVIL_PORT:-8545}"
ANVIL_CHAIN_ID="${ANVIL_CHAIN_ID:-31337}"
RPC_URL="${RPC_URL:-http://${ANVIL_HOST}:${ANVIL_PORT}}"
ANVIL_LOG_PATH="${ANVIL_LOG_PATH:-${ROOT_DIR}/.anvil-smoke.log}"
PRIVATE_KEY="${PRIVATE_KEY:-}"
NEXT_OWNER_PRIVATE_KEY="${NEXT_OWNER_PRIVATE_KEY:-}"
export NO_PROXY="${NO_PROXY:-127.0.0.1,localhost}"
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy

ANVIL_PID=""

cleanup() {
  if [[ -n "${ANVIL_PID}" ]] && kill -0 "${ANVIL_PID}" >/dev/null 2>&1; then
    kill "${ANVIL_PID}" >/dev/null 2>&1 || true
    wait "${ANVIL_PID}" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

load_anvil_keys_if_needed() {
  if [[ -n "${PRIVATE_KEY}" && -n "${NEXT_OWNER_PRIVATE_KEY}" ]]; then
    return 0
  fi

  local key_count=0
  local key
  while IFS= read -r key; do
    key_count=$((key_count + 1))
    if [[ "${key_count}" -eq 1 && -z "${PRIVATE_KEY}" ]]; then
      PRIVATE_KEY="${key}"
    elif [[ "${key_count}" -eq 2 && -z "${NEXT_OWNER_PRIVATE_KEY}" ]]; then
      NEXT_OWNER_PRIVATE_KEY="${key}"
    fi
    if [[ -n "${PRIVATE_KEY}" && -n "${NEXT_OWNER_PRIVATE_KEY}" ]]; then
      break
    fi
  done < <(awk '
    /^Private Keys/ { in_keys = 1; next }
    in_keys && /^\([0-9]+\)/ {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^0x[[:xdigit:]]{64}$/) print $i
      }
    }
  ' "${ANVIL_LOG_PATH}")

  if [[ -z "${PRIVATE_KEY}" || -z "${NEXT_OWNER_PRIVATE_KEY}" ]]; then
    echo "Set PRIVATE_KEY and NEXT_OWNER_PRIVATE_KEY, or run against a managed Anvil that prints local test keys." >&2
    exit 1
  fi
}

rm -f "${ROOT_DIR}/deployments/diamond-core.local.json"

anvil --host "${ANVIL_HOST}" --port "${ANVIL_PORT}" --chain-id "${ANVIL_CHAIN_ID}" >"${ANVIL_LOG_PATH}" 2>&1 &
ANVIL_PID="$!"

for _ in {1..30}; do
  if cast block-number --rpc-url "${RPC_URL}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! cast block-number --rpc-url "${RPC_URL}" >/dev/null 2>&1; then
  echo "Anvil did not become ready. See ${ANVIL_LOG_PATH}."
  exit 1
fi

load_anvil_keys_if_needed
export PRIVATE_KEY
export NEXT_OWNER_PRIVATE_KEY

cd "${ROOT_DIR}"

forge script script/DeployDiamondCore.s.sol:DeployDiamondCoreScript --rpc-url "${RPC_URL}" --broadcast
forge script script/SmokeDiamondCore.s.sol:SmokeDiamondCoreScript --rpc-url "${RPC_URL}" --broadcast

echo "Local diamond smoke flow passed."
