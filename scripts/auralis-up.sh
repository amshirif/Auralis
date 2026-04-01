#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/auralis.sh"

auralis_export_env
auralis_start_anvil_if_needed
auralis_remove_artifacts

auralis_note "Funding local actor accounts"
auralis_fund_actor "${AURALIS_ALICE_ADDRESS}"

auralis_note "Deploying ERC20 host"
(
  cd "${AURALIS_ROOT}"
  forge script script/DeployDiamondErc20Host.s.sol:DeployDiamondErc20HostScript --rpc-url "${AURALIS_RPC_URL}" --broadcast
)

auralis_note "Deploying ERC721 host"
(
  cd "${AURALIS_ROOT}"
  forge script script/DeployDiamondErc721Host.s.sol:DeployDiamondErc721HostScript --rpc-url "${AURALIS_RPC_URL}" --broadcast
)

auralis_note "Deploying strategy-enabled vault host"
(
  cd "${AURALIS_ROOT}"
  forge script script/DeployDiamondVaultHost.s.sol:DeployDiamondVaultHostScript --rpc-url "${AURALIS_RPC_URL}" --broadcast
)

auralis_note "Writing unified Auralis artifact"
auralis_write_unified_artifact

vault_strategy="$(auralis_json_get "${AURALIS_ARTIFACT_PATH}" vaultHost.strategy)"

cat <<MSG
Auralis local environment is ready.

RPC: ${AURALIS_RPC_URL}
Artifact: ${AURALIS_ARTIFACT_PATH}
Owner: ${AURALIS_OWNER_ADDRESS}
Alice: ${AURALIS_ALICE_ADDRESS}
Vault strategy: ${vault_strategy}

Next steps:
- bash scripts/auralis-smoke.sh
- bash scripts/auralis-activity.sh
- bash scripts/auralis-reset.sh
MSG
