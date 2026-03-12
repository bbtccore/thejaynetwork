#!/usr/bin/env bash
set -euo pipefail

###############################################################################
#
#  ╦╔═╗╦ ╦  ╔╗╔╔═╗╔╦╗╦ ╦╔═╗╦═╗╦╔═
#  ║╠═╣╚╦╝  ║║║║╣  ║ ║║║║ ║╠╦╝╠╩╗
#  ╚╝╩ ╩ ╩   ╝╚╝╚═╝ ╩ ╚╩╝╚═╝╩╚═╩ ╩
#
#  Multi-Node Network Bootstrap Script
#
#  Orchestrates the full deployment of a Jay Network across multiple servers.
#  Run this from your LOCAL machine (or a bastion host) with SSH access to all nodes.
#
#  Prerequisites:
#    - SSH key-based access to all nodes (as root or sudoer)
#    - Linux jaynd binary built: build/jaynd-linux-amd64
#    - This project directory available locally
#
#  Usage:
#    ./bootstrap_network.sh
#
#  Configuration:
#    Edit the NODES array and DOMAIN variables below.
#
###############################################################################

#==============================================================================
# CONFIGURATION — EDIT THESE
#==============================================================================

# Domain
DOMAIN="pribit.org"

# Chain params
CHAIN_ID="thejaynetwork-1"
BINARY_NAME="jaynd"
DENOM="ujay"

# SSH user (must have sudo)
SSH_USER="root"
SSH_KEY=""  # e.g., ~/.ssh/id_rsa  (leave empty for default)

# Node definitions: NAME|IP|ROLE
# Roles: validator, sentry, seed, archive
NODES=(
    "node1|node1.${DOMAIN}|validator"
    "node2|node2.${DOMAIN}|validator"
    "node3|node3.${DOMAIN}|validator"
    "node4|node4.${DOMAIN}|sentry"
    "node5|node5.${DOMAIN}|archive"
)

# Genesis validator config (first validator node creates genesis)
GENESIS_ACCOUNT_AMOUNT="1000000000000${DENOM}"   # 1M JAY
GENESIS_STAKE_AMOUNT="500000000000${DENOM}"       # 500K JAY
KEYRING_BACKEND="test"

#==============================================================================
# COLORS & HELPERS
#==============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()   { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()     { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()  { echo -e "${RED}[ERROR]${NC} $*"; }
log_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  $*${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
if [[ -n "${SSH_KEY}" ]]; then
    SSH_OPTS="${SSH_OPTS} -i ${SSH_KEY}"
fi

remote_exec() {
    local host="$1"
    shift
    ssh ${SSH_OPTS} "${SSH_USER}@${host}" "$@"
}

remote_copy() {
    local src="$1"
    local host="$2"
    local dst="$3"
    scp ${SSH_OPTS} -r "${src}" "${SSH_USER}@${host}:${dst}"
}

get_node_field() {
    local node_entry="$1"
    local field="$2"
    echo "${node_entry}" | cut -d'|' -f"${field}"
}

#==============================================================================
# PREFLIGHT
#==============================================================================
log_banner "Jay Network Multi-Node Bootstrap"

# Verify binary exists
BINARY_FILE="${PROJECT_DIR}/build/jaynd-linux-amd64"
if [[ ! -f "${BINARY_FILE}" ]]; then
    log_error "Linux binary not found: ${BINARY_FILE}"
    log_error "Build it first: GOOS=linux GOARCH=amd64 go build -o build/jaynd-linux-amd64 ./cmd/jaynd"
    exit 1
fi
log_ok "Binary found: ${BINARY_FILE} ($(du -sh "${BINARY_FILE}" | cut -f1))"

# Verify deploy_node.sh exists
DEPLOY_SCRIPT="${SCRIPT_DIR}/deploy_node.sh"
if [[ ! -f "${DEPLOY_SCRIPT}" ]]; then
    log_error "deploy_node.sh not found: ${DEPLOY_SCRIPT}"
    exit 1
fi
log_ok "Deploy script found: ${DEPLOY_SCRIPT}"

echo ""
log_info "Nodes to deploy:"
for entry in "${NODES[@]}"; do
    name=$(get_node_field "${entry}" 1)
    host=$(get_node_field "${entry}" 2)
    role=$(get_node_field "${entry}" 3)
    printf "  %-10s %-30s %s\n" "${name}" "${host}" "[${role}]"
done
echo ""

read -p "Proceed with deployment? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Aborted."
    exit 0
fi

#==============================================================================
# PHASE 1: DEPLOY NODES
#==============================================================================
log_banner "Phase 1: Deploy jaynd to all nodes"

NODE_IDS=()
for entry in "${NODES[@]}"; do
    name=$(get_node_field "${entry}" 1)
    host=$(get_node_field "${entry}" 2)
    role=$(get_node_field "${entry}" 3)

    log_info "━━━ Deploying ${name} (${host}) as ${role} ━━━"

    # Upload binary and scripts
    remote_exec "${host}" "mkdir -p /tmp/jaynet-deploy/build /tmp/jaynet-deploy/scripts"
    remote_copy "${BINARY_FILE}" "${host}" "/tmp/jaynet-deploy/build/jaynd-linux-amd64"
    remote_copy "${DEPLOY_SCRIPT}" "${host}" "/tmp/jaynet-deploy/scripts/deploy_node.sh"

    # Run deploy script
    remote_exec "${host}" "chmod +x /tmp/jaynet-deploy/scripts/deploy_node.sh && \
        cd /tmp/jaynet-deploy && \
        bash scripts/deploy_node.sh --moniker ${name} --role ${role} --chain-id ${CHAIN_ID}"

    # Collect node ID
    NODE_ID=$(remote_exec "${host}" "jaynd comet show-node-id --home /home/jaynet/.jayn 2>/dev/null" || echo "unknown")
    NODE_IDS+=("${NODE_ID}@${host}:26656")

    log_ok "${name} deployed (ID: ${NODE_ID})"
    echo ""
done

#==============================================================================
# PHASE 2: BUILD PEER LIST
#==============================================================================
log_banner "Phase 2: Build persistent peer list"

PEER_LIST=$(IFS=,; echo "${NODE_IDS[*]}")
log_info "Peer list: ${PEER_LIST}"

#==============================================================================
# PHASE 3: GENESIS CREATION (on first validator)
#==============================================================================
log_banner "Phase 3: Create Genesis (on first validator)"

GENESIS_NODE_ENTRY="${NODES[0]}"
GENESIS_NAME=$(get_node_field "${GENESIS_NODE_ENTRY}" 1)
GENESIS_HOST=$(get_node_field "${GENESIS_NODE_ENTRY}" 2)

log_info "Genesis node: ${GENESIS_NAME} (${GENESIS_HOST})"

# Create validator key, genesis account, gentx
remote_exec "${GENESIS_HOST}" bash << GENESISEOF
set -euo pipefail

export HOME=/home/jaynet
BINARY="jaynd"
HOME_DIR="/home/jaynet/.jayn"
CHAIN_ID="${CHAIN_ID}"
DENOM="${DENOM}"
KEYRING="${KEYRING_BACKEND}"

echo "=== Creating genesis validator key ==="
sudo -u jaynet \${BINARY} keys add validator \
    --keyring-backend \${KEYRING} \
    --home "\${HOME_DIR}" 2>&1 | tail -1

ADDR=\$(sudo -u jaynet \${BINARY} keys show validator -a \
    --keyring-backend \${KEYRING} \
    --home "\${HOME_DIR}")
echo "Validator address: \${ADDR}"

echo "=== Adding genesis account ==="
sudo -u jaynet \${BINARY} genesis add-genesis-account "\${ADDR}" "${GENESIS_ACCOUNT_AMOUNT}" \
    --home "\${HOME_DIR}"

echo "=== Creating gentx ==="
sudo -u jaynet \${BINARY} genesis gentx validator "${GENESIS_STAKE_AMOUNT}" \
    --chain-id "\${CHAIN_ID}" \
    --keyring-backend \${KEYRING} \
    --moniker "${GENESIS_NAME}" \
    --commission-rate "0.05" \
    --commission-max-rate "0.20" \
    --commission-max-change-rate "0.01" \
    --min-self-delegation "1" \
    --home "\${HOME_DIR}"

echo "=== Collecting gentxs ==="
sudo -u jaynet \${BINARY} genesis collect-gentxs --home "\${HOME_DIR}"

echo "=== Validating genesis ==="
sudo -u jaynet \${BINARY} genesis validate --home "\${HOME_DIR}"

echo "=== Genesis created successfully ==="
GENESISEOF

log_ok "Genesis created on ${GENESIS_NAME}"

#==============================================================================
# PHASE 4: DISTRIBUTE GENESIS + SET PEERS
#==============================================================================
log_banner "Phase 4: Distribute genesis.json and configure peers"

# Download genesis from first node
GENESIS_TEMP="/tmp/jaynet_genesis.json"
scp ${SSH_OPTS} "${SSH_USER}@${GENESIS_HOST}:/home/jaynet/.jayn/config/genesis.json" "${GENESIS_TEMP}"
log_ok "Genesis downloaded from ${GENESIS_NAME}"

for entry in "${NODES[@]}"; do
    name=$(get_node_field "${entry}" 1)
    host=$(get_node_field "${entry}" 2)

    log_info "Configuring ${name} (${host})..."

    # Copy genesis (skip for genesis node, it already has it)
    if [[ "${host}" != "${GENESIS_HOST}" ]]; then
        remote_copy "${GENESIS_TEMP}" "${host}" "/home/jaynet/.jayn/config/genesis.json"
        remote_exec "${host}" "chown jaynet:jaynet /home/jaynet/.jayn/config/genesis.json"
    fi

    # Set persistent peers (exclude self)
    SELF_ID=""
    OTHER_PEERS=""
    for nid in "${NODE_IDS[@]}"; do
        if [[ "${nid}" == *"${host}"* ]]; then
            SELF_ID="${nid}"
        else
            if [[ -n "${OTHER_PEERS}" ]]; then
                OTHER_PEERS="${OTHER_PEERS},${nid}"
            else
                OTHER_PEERS="${nid}"
            fi
        fi
    done

    remote_exec "${host}" "sed -i 's|persistent_peers = \".*\"|persistent_peers = \"${OTHER_PEERS}\"|' /home/jaynet/.jayn/config/config.toml"

    log_ok "${name}: genesis + peers configured"
done

rm -f "${GENESIS_TEMP}"

#==============================================================================
# PHASE 5: START ALL NODES
#==============================================================================
log_banner "Phase 5: Start All Nodes"

# Start genesis validator first, then others
for entry in "${NODES[@]}"; do
    name=$(get_node_field "${entry}" 1)
    host=$(get_node_field "${entry}" 2)

    log_info "Starting ${name} (${host})..."
    remote_exec "${host}" "systemctl start ${BINARY_NAME}"

    # Wait a moment for the first node
    if [[ "${host}" == "${GENESIS_HOST}" ]]; then
        log_info "Waiting 10s for genesis validator to produce blocks..."
        sleep 10
    else
        sleep 2
    fi

    # Check status
    STATUS=$(remote_exec "${host}" "systemctl is-active ${BINARY_NAME} 2>/dev/null" || echo "failed")
    if [[ "${STATUS}" == "active" ]]; then
        log_ok "${name}: RUNNING ✓"
    else
        log_warn "${name}: status = ${STATUS} (check logs: journalctl -u ${BINARY_NAME} -f)"
    fi
done

#==============================================================================
# PHASE 6: VERIFICATION
#==============================================================================
log_banner "Phase 6: Network Verification"

sleep 5

for entry in "${NODES[@]}"; do
    name=$(get_node_field "${entry}" 1)
    host=$(get_node_field "${entry}" 2)

    # Check sync status
    SYNC_INFO=$(remote_exec "${host}" "curl -s http://localhost:26657/status 2>/dev/null | jq -r '.result.sync_info | \"\(.latest_block_height) catching_up=\(.catching_up)\"'" || echo "unreachable")

    echo -e "  ${CYAN}${name}${NC} (${host}): block ${SYNC_INFO}"
done

#==============================================================================
# FINAL SUMMARY
#==============================================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          JAY NETWORK DEPLOYMENT COMPLETE                        ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  Chain ID:      ${CYAN}${CHAIN_ID}${NC}"
echo -e "${GREEN}║${NC}  Nodes:         ${CYAN}${#NODES[@]}${NC}"
echo -e "${GREEN}║${NC}"
for i in "${!NODES[@]}"; do
    entry="${NODES[$i]}"
    name=$(get_node_field "${entry}" 1)
    host=$(get_node_field "${entry}" 2)
    role=$(get_node_field "${entry}" 3)
    echo -e "${GREEN}║${NC}  ${name}: ${CYAN}${host}${NC} [${role}] → ${NODE_IDS[$i]}"
done
echo -e "${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${YELLOW}Endpoints:${NC}"
echo -e "${GREEN}║${NC}  • RPC:     ${CYAN}http://node4.${DOMAIN}:26657${NC}"
echo -e "${GREEN}║${NC}  • REST:    ${CYAN}http://node4.${DOMAIN}:1317${NC}"
echo -e "${GREEN}║${NC}  • gRPC:    ${CYAN}node4.${DOMAIN}:9090${NC}"
echo -e "${GREEN}║${NC}  • P2P:     ${CYAN}node1.${DOMAIN}:26656${NC}"
echo -e "${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${YELLOW}Monitoring:${NC}"
echo -e "${GREEN}║${NC}  • Logs:    ${CYAN}ssh <node> journalctl -u ${BINARY_NAME} -f${NC}"
echo -e "${GREEN}║${NC}  • Status:  ${CYAN}curl http://<node>:26657/status${NC}"
echo -e "${GREEN}║${NC}  • Health:  ${CYAN}curl http://<node>:26657/health${NC}"
echo -e "${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

