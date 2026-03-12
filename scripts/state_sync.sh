#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Jay Network State Sync Configuration Script
#
# Configures a node to use state sync for fast bootstrapping from a trusted
# RPC endpoint. This wipes local chain data and syncs from a recent snapshot.
#
# Usage:
#   ./state_sync.sh <RPC_ENDPOINT> [RPC_ENDPOINT_2]
#
# Examples:
#   ./state_sync.sh http://node5.pribit.org:26657
#   ./state_sync.sh http://node4.pribit.org:26657 http://node5.pribit.org:26657
###############################################################################

RPC1="${1:?Usage: $0 <RPC_ENDPOINT> [RPC_ENDPOINT_2]}"
RPC2="${2:-${RPC1}}"
HOME_DIR="${HOME}/.jayn"
CONFIG_TOML="${HOME_DIR}/config/config.toml"
BINARY="jaynd"

echo "============================================"
echo "  Jay Network State Sync Setup"
echo "============================================"
echo "  RPC 1: ${RPC1}"
echo "  RPC 2: ${RPC2}"
echo "  Home:  ${HOME_DIR}"
echo "============================================"
echo ""

# Verify config exists
if [[ ! -f "${CONFIG_TOML}" ]]; then
    echo "ERROR: config.toml not found at ${CONFIG_TOML}"
    echo "Run 'jaynd init' first."
    exit 1
fi

# Stop the service if running
if systemctl is-active --quiet ${BINARY} 2>/dev/null; then
    echo "Stopping ${BINARY} service..."
    sudo systemctl stop ${BINARY}
fi

# Get latest block info
echo "[1/4] Querying latest block from ${RPC1}..."
LATEST=$(curl -sf "${RPC1}/block" | jq -r '.result.block.header.height')
if [[ -z "${LATEST}" || "${LATEST}" == "null" ]]; then
    echo "ERROR: Could not query block height from ${RPC1}"
    echo "Make sure the RPC endpoint is reachable and the node is synced."
    exit 1
fi
echo "  Latest block height: ${LATEST}"

# Calculate trust height (2000 blocks behind for safety)
TRUST_HEIGHT=$((LATEST - 2000))
if [[ ${TRUST_HEIGHT} -lt 1 ]]; then
    echo "ERROR: Chain is too young for state sync (height ${LATEST} < 2000)."
    echo "Sync from genesis instead."
    exit 1
fi
echo "  Trust height: ${TRUST_HEIGHT}"

# Get trust hash
echo "[2/4] Getting trust hash at height ${TRUST_HEIGHT}..."
TRUST_HASH=$(curl -sf "${RPC1}/block?height=${TRUST_HEIGHT}" | jq -r '.result.block_id.hash')
if [[ -z "${TRUST_HASH}" || "${TRUST_HASH}" == "null" ]]; then
    echo "ERROR: Could not get block hash at height ${TRUST_HEIGHT}"
    exit 1
fi
echo "  Trust hash: ${TRUST_HASH}"

# Wipe existing data (keep config and keys)
echo "[3/4] Resetting node data..."
${BINARY} comet unsafe-reset-all --home "${HOME_DIR}" --keep-addr-book 2>/dev/null || \
    rm -rf "${HOME_DIR}/data" && mkdir -p "${HOME_DIR}/data"

# Update config.toml
echo "[4/4] Updating config.toml..."

# Use sed to update the [statesync] section
sed -i '/\[statesync\]/,/^\[/{
    s/enable = false/enable = true/
}' "${CONFIG_TOML}"
sed -i "s|rpc_servers = \".*\"|rpc_servers = \"${RPC1},${RPC2}\"|" "${CONFIG_TOML}"
sed -i "s/trust_height = .*/trust_height = ${TRUST_HEIGHT}/" "${CONFIG_TOML}"
sed -i "s/trust_hash = \".*\"/trust_hash = \"${TRUST_HASH}\"/" "${CONFIG_TOML}"
sed -i 's/trust_period = ".*"/trust_period = "168h0m0s"/' "${CONFIG_TOML}"
sed -i 's/discovery_time = ".*"/discovery_time = "15s"/' "${CONFIG_TOML}"
sed -i 's/chunk_request_timeout = ".*"/chunk_request_timeout = "10s"/' "${CONFIG_TOML}"

echo ""
echo "============================================"
echo "  State Sync Configured!"
echo "============================================"
echo ""
echo "  RPC Servers:   ${RPC1}, ${RPC2}"
echo "  Trust Height:  ${TRUST_HEIGHT}"
echo "  Trust Hash:    ${TRUST_HASH}"
echo "  Trust Period:  168h0m0s"
echo ""
echo "Start the node:"
echo "  sudo systemctl start ${BINARY}"
echo "  # or: ${BINARY} start --home ${HOME_DIR}"
echo ""
echo "Monitor sync progress:"
echo "  sudo journalctl -u ${BINARY} -f"
echo "  curl -s localhost:26657/status | jq '.result.sync_info'"
echo ""
