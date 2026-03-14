#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export NO_PROXY="${NO_PROXY:-127.0.0.1,localhost}"
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy

cd "${ROOT_DIR}"

echo "==> Running local diamond smoke flow"
bash script/run-local-diamond-smoke.sh

echo "==> Running local diamond upgrade rehearsal"
bash script/run-local-diamond-upgrade-rehearsal.sh

echo "==> Running system vault stress invariant suite"
forge test --offline --match-path test/SystemVaultStressInvariant.t.sol

echo "==> Running system oracle failure scenarios"
forge test --offline --match-path test/SystemOracleFailureScenarios.t.sol

echo "Local system hardening flow passed."
