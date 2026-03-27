#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/auralis.sh"

auralis_export_env
auralis_note "Stopping managed Anvil if present"
auralis_stop_managed_anvil

auralis_note "Removing local Auralis artifacts"
auralis_remove_artifacts
rm -f "${AURALIS_ANVIL_LOG_PATH}"

auralis_note "Auralis local environment reset complete"
