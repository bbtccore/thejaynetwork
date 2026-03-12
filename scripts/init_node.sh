#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Jay Network Node Initialization Script
#
# Initializes a jaynd node with production-tuned configuration.
# Can be run standalone (without deploy_node.sh) for manual setups.
#
# Usage:
#   ./init_node.sh <MONIKER> [CHAIN_ID] [ROLE]
#
# Examples:
#   ./init_node.sh my-validator thejaynetwork-1 validator
#   ./init_node.sh my-sentry thejaynetwork-1 sentry
###############################################################################

BINARY="jaynd"
CHAIN_ID="${2:-thejaynetwork-1}"
MONIKER="${1:?Usage: $0 <MONIKER> [CHAIN_ID] [ROLE]}"
ROLE="${3:-validator}"
DENOM="ujay"
HOME_DIR="${HOME}/.jayn"
MIN_GAS_PRICE="0.0025${DENOM}"

echo "============================================"
echo "  Jay Network Node Initialization"
echo "============================================"
echo "Moniker:   ${MONIKER}"
echo "Chain ID:  ${CHAIN_ID}"
echo "Role:      ${ROLE}"
echo "Home:      ${HOME_DIR}"
echo "Denom:     ${DENOM}"
echo "============================================"

# Verify binary
if ! command -v ${BINARY} &>/dev/null; then
    echo "ERROR: ${BINARY} binary not found in PATH."
    echo "Install with: cp build/jaynd-linux-amd64 /usr/local/bin/jaynd"
    exit 1
fi

# Check existing installation
if [[ -d "${HOME_DIR}/config" ]]; then
    echo "WARNING: Node directory already exists at ${HOME_DIR}"
    read -p "  Overwrite? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    rm -rf "${HOME_DIR}"
fi

# Initialize the node
echo "[1/8] Initializing node..."
${BINARY} init "${MONIKER}" \
    --chain-id "${CHAIN_ID}" \
    --home "${HOME_DIR}" \
    --default-denom "${DENOM}" \
    > /dev/null 2>&1

# Fix genesis denom (belt and suspenders)
echo "[2/8] Configuring genesis denom..."
GENESIS="${HOME_DIR}/config/genesis.json"
sed -i.bak "s/\"stake\"/\"${DENOM}\"/g" "${GENESIS}"
rm -f "${GENESIS}.bak"

# Set minimum gas prices
echo "[3/8] Setting minimum gas prices..."
APP_TOML="${HOME_DIR}/config/app.toml"
sed -i.bak "s/minimum-gas-prices = \"\"/minimum-gas-prices = \"${MIN_GAS_PRICE}\"/g" "${APP_TOML}"
sed -i.bak "s/minimum-gas-prices = \"0stake\"/minimum-gas-prices = \"${MIN_GAS_PRICE}\"/g" "${APP_TOML}"
rm -f "${APP_TOML}.bak"

# Configure config.toml for production
echo "[4/8] Configuring consensus & P2P..."
CONFIG_TOML="${HOME_DIR}/config/config.toml"

# Consensus speed
sed -i 's/timeout_propose = "3s"/timeout_propose = "2s"/' "${CONFIG_TOML}"
sed -i 's/timeout_commit = "5s"/timeout_commit = "3s"/' "${CONFIG_TOML}"

# Mempool
sed -i 's/size = 5000/size = 10000/' "${CONFIG_TOML}"

# P2P tuning
sed -i 's/max_num_inbound_peers = 40/max_num_inbound_peers = 120/' "${CONFIG_TOML}"
sed -i 's/max_num_outbound_peers = 10/max_num_outbound_peers = 40/' "${CONFIG_TOML}"
sed -i 's/send_rate = 5120000/send_rate = 20480000/' "${CONFIG_TOML}"
sed -i 's/recv_rate = 5120000/recv_rate = 20480000/' "${CONFIG_TOML}"

# Enable prometheus
sed -i 's/prometheus = false/prometheus = true/' "${CONFIG_TOML}"

# Role-specific indexer
if [[ "${ROLE}" == "validator" ]]; then
    sed -i 's/indexer = "kv"/indexer = "null"/' "${CONFIG_TOML}"
fi
if [[ "${ROLE}" == "seed" ]]; then
    sed -i 's/seed_mode = false/seed_mode = true/' "${CONFIG_TOML}"
fi

# Enable API and gRPC
echo "[5/8] Enabling API and gRPC..."
sed -i '/\[api\]/,/\[/{s/enable = false/enable = true/}' "${APP_TOML}"
sed -i 's|swagger = false|swagger = true|g' "${APP_TOML}"
sed -i '/\[grpc\]/,/\[/{s/enable = false/enable = true/}' "${APP_TOML}"
rm -f "${APP_TOML}.bak"

# Pruning per role
echo "[6/8] Configuring pruning for role: ${ROLE}..."
case "${ROLE}" in
    validator|sentry)
        sed -i 's/pruning = "default"/pruning = "custom"/' "${APP_TOML}"
        sed -i 's/pruning-keep-recent = "0"/pruning-keep-recent = "100"/' "${APP_TOML}"
        sed -i 's/pruning-interval = "0"/pruning-interval = "17"/' "${APP_TOML}"
        ;;
    archive)
        sed -i 's/pruning = "default"/pruning = "nothing"/' "${APP_TOML}"
        ;;
    seed)
        sed -i 's/pruning = "default"/pruning = "everything"/' "${APP_TOML}"
        ;;
esac

# State sync snapshots
echo "[7/8] Configuring state sync snapshots..."
if [[ "${ROLE}" == "sentry" || "${ROLE}" == "archive" ]]; then
    sed -i 's/snapshot-interval = 0/snapshot-interval = 1000/' "${APP_TOML}"
    sed -i 's/snapshot-keep-recent = 2/snapshot-keep-recent = 5/' "${APP_TOML}"
else
    sed -i 's/snapshot-interval = 0/snapshot-interval = 1000/' "${APP_TOML}"
    sed -i 's/snapshot-keep-recent = 2/snapshot-keep-recent = 2/' "${APP_TOML}"
fi

# Client config
echo "[8/8] Setting client config..."
CLIENT_TOML="${HOME_DIR}/config/client.toml"
if [[ -f "${CLIENT_TOML}" ]]; then
    sed -i "s/chain-id = \"\"/chain-id = \"${CHAIN_ID}\"/" "${CLIENT_TOML}"
fi

# Get node ID
NODE_ID=$(${BINARY} comet show-node-id --home "${HOME_DIR}" 2>/dev/null || echo "unknown")

echo ""
echo "============================================"
echo "  Node initialization complete!"
echo "============================================"
echo ""
echo "  Node ID:     ${NODE_ID}"
echo "  Peer Addr:   ${NODE_ID}@<YOUR_IP>:26656"
echo "  Home:        ${HOME_DIR}"
echo "  Role:        ${ROLE}"
echo ""
echo "Next steps:"
echo "  1. Add validator key:  ${BINARY} keys add validator --keyring-backend file --home ${HOME_DIR}"
echo "  2. Add genesis account and gentx (if genesis validator)"
echo "  3. Copy the final genesis.json to ${HOME_DIR}/config/genesis.json"
echo "  4. Set persistent peers in ${CONFIG_TOML}"
echo "  5. Start: ${BINARY} start --home ${HOME_DIR}"
echo ""
