#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANVIL_HOST="${ANVIL_HOST:-127.0.0.1}"
ANVIL_PORT="${ANVIL_PORT:-8545}"
ANVIL_CHAIN_ID="${ANVIL_CHAIN_ID:-31337}"
RPC_URL="${RPC_URL:-http://${ANVIL_HOST}:${ANVIL_PORT}}"
ANVIL_LOG_PATH="${ANVIL_LOG_PATH:-${ROOT_DIR}/.anvil-upgrade-rehearsal.log}"
PRIVATE_KEY="${PRIVATE_KEY:-}"
DEPLOYMENT_ARTIFACT="${ROOT_DIR}/deployments/diamond-core.local.json"
REHEARSAL_ARTIFACT="${ROOT_DIR}/deployments/diamond-core.upgrade-rehearsal.local.json"
ZERO_ADDRESS="0x0000000000000000000000000000000000000000"

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

load_anvil_key_if_needed() {
  if [[ -n "${PRIVATE_KEY}" ]]; then
    return 0
  fi

  PRIVATE_KEY="$(awk '
    /^Private Keys/ { in_keys = 1; next }
    in_keys && /^\([0-9]+\)/ {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^0x[[:xdigit:]]{64}$/) {
          print $i
          exit
        }
      }
    }
  ' "${ANVIL_LOG_PATH}")"

  if [[ -z "${PRIVATE_KEY}" ]]; then
    echo "Set PRIVATE_KEY, or run against a managed Anvil that prints local test keys." >&2
    exit 1
  fi
}

json_value() {
  python3 -c 'import json, sys; print(json.load(open(sys.argv[1], "r", encoding="utf-8"))[sys.argv[2]])' "$1" "$2"
}

rm -f "${DEPLOYMENT_ARTIFACT}" "${REHEARSAL_ARTIFACT}"

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

load_anvil_key_if_needed
export PRIVATE_KEY

cd "${ROOT_DIR}"

forge script script/DeployDiamondCore.s.sol:DeployDiamondCoreScript --rpc-url "${RPC_URL}" --broadcast
forge script script/RehearseDiamondUpgrade.s.sol:RehearseDiamondUpgradeScript --rpc-url "${RPC_URL}" --broadcast

DIAMOND_ADDRESS="$(json_value "${REHEARSAL_ARTIFACT}" diamond)"
OWNER_ADDRESS="$(json_value "${REHEARSAL_ARTIFACT}" owner)"
UPGRADE_FACET="$(json_value "${REHEARSAL_ARTIFACT}" upgradeFacet)"
INIT_MOCK="$(json_value "${REHEARSAL_ARTIFACT}" initMock)"
COLLISION_FACET="$(json_value "${REHEARSAL_ARTIFACT}" collisionFacet)"
FAILURE_FACET="$(json_value "${REHEARSAL_ARTIFACT}" failureFacet)"

ALPHA_SELECTOR="$(cast sig "alpha()")"
GAMMA_SELECTOR="$(cast sig "gamma()")"
ZETA_SELECTOR="$(cast sig "zeta()")"
COLLISION_ERROR_SELECTOR="$(cast sig "DiamondSelectorAlreadyExists(bytes4,address)")"
INIT_FAILURE_ERROR_SELECTOR="$(cast sig "DiamondCutInitFailed(address,bytes)")"
REVERT_INIT_CALLDATA="$(cast calldata "revertInit()")"

if collision_output=$(cast send \
  "${DIAMOND_ADDRESS}" \
  "diamondCut((address,uint8,bytes4[])[],address,bytes)" \
  "[( ${COLLISION_FACET}, 0, [${GAMMA_SELECTOR},${ALPHA_SELECTOR}] )]" \
  "${ZERO_ADDRESS}" \
  "0x" \
  --rpc-url "${RPC_URL}" \
  --private-key "${PRIVATE_KEY}" 2>&1); then
  echo "Selector collision rehearsal unexpectedly succeeded."
  exit 1
fi

if [[ "${collision_output}" != *"${COLLISION_ERROR_SELECTOR}"* ]]; then
  echo "Selector collision rehearsal reverted with an unexpected error."
  echo "${collision_output}"
  exit 1
fi

gamma_owner="$(cast call "${DIAMOND_ADDRESS}" "facetAddress(bytes4)(address)" "${GAMMA_SELECTOR}" --rpc-url "${RPC_URL}")"
if [[ "${gamma_owner,,}" != "${ZERO_ADDRESS,,}" ]]; then
  echo "Collision rehearsal left partial selector routing in place."
  exit 1
fi

if init_failure_output=$(cast send \
  "${DIAMOND_ADDRESS}" \
  "diamondCut((address,uint8,bytes4[])[],address,bytes)" \
  "[( ${FAILURE_FACET}, 0, [${ZETA_SELECTOR}] )]" \
  "${INIT_MOCK}" \
  "${REVERT_INIT_CALLDATA}" \
  --rpc-url "${RPC_URL}" \
  --private-key "${PRIVATE_KEY}" 2>&1); then
  echo "Init-failure rehearsal unexpectedly succeeded."
  exit 1
fi

if [[ "${init_failure_output}" != *"${INIT_FAILURE_ERROR_SELECTOR}"* ]]; then
  echo "Init-failure rehearsal reverted with an unexpected error."
  echo "${init_failure_output}"
  exit 1
fi

zeta_owner="$(cast call "${DIAMOND_ADDRESS}" "facetAddress(bytes4)(address)" "${ZETA_SELECTOR}" --rpc-url "${RPC_URL}")"
if [[ "${zeta_owner,,}" != "${ZERO_ADDRESS,,}" ]]; then
  echo "Init-failure rehearsal left partial selector routing in place."
  exit 1
fi

owner_after="$(cast call "${DIAMOND_ADDRESS}" "owner()(address)" --rpc-url "${RPC_URL}")"
if [[ "${owner_after,,}" != "${OWNER_ADDRESS,,}" ]]; then
  echo "Owner changed during failed-cut rehearsal."
  exit 1
fi

alpha_owner="$(cast call "${DIAMOND_ADDRESS}" "facetAddress(bytes4)(address)" "${ALPHA_SELECTOR}" --rpc-url "${RPC_URL}")"
if [[ "${alpha_owner,,}" != "${UPGRADE_FACET,,}" ]]; then
  echo "Alpha selector ownership changed unexpectedly after failed-cut rehearsal."
  exit 1
fi

alpha_value="$(cast call "${DIAMOND_ADDRESS}" "alpha()(uint256)" --rpc-url "${RPC_URL}")"
if [[ "${alpha_value}" != "11" ]]; then
  echo "Alpha route regressed after failed-cut rehearsal."
  exit 1
fi

read_value="$(cast call "${DIAMOND_ADDRESS}" "readValue()(uint256)" --rpc-url "${RPC_URL}")"
if [[ "${read_value}" != "42" ]]; then
  echo "Init-backed state regressed after failed-cut rehearsal."
  exit 1
fi

echo "Local diamond upgrade rehearsal passed."
