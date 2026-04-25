#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANVIL_HOST="${ANVIL_HOST:-127.0.0.1}"
ANVIL_PORT="${ANVIL_PORT:-8545}"
ANVIL_CHAIN_ID="${ANVIL_CHAIN_ID:-31337}"
RPC_URL="${RPC_URL:-http://${ANVIL_HOST}:${ANVIL_PORT}}"
ANVIL_LOG_PATH="${ANVIL_LOG_PATH:-${ROOT_DIR}/.anvil-smoke.log}"
PRIVATE_KEY="${PRIVATE_KEY:?Set PRIVATE_KEY to a funded local Anvil account key before running this smoke script.}"
NEXT_OWNER_PRIVATE_KEY="${NEXT_OWNER_PRIVATE_KEY:?Set NEXT_OWNER_PRIVATE_KEY to a second local Anvil account key before running this smoke script.}"

export PRIVATE_KEY
export NEXT_OWNER_PRIVATE_KEY
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

cd "${ROOT_DIR}"

forge script script/DeployDiamondCore.s.sol:DeployDiamondCoreScript --rpc-url "${RPC_URL}" --broadcast
forge script script/SmokeDiamondCore.s.sol:SmokeDiamondCoreScript --rpc-url "${RPC_URL}" --broadcast

echo "Local diamond smoke flow passed."
