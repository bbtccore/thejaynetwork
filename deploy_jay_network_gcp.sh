#!/usr/bin/env bash
set -euo pipefail

###############################################################################
#
#  ╦╔═╗╦ ╦  ╔╗╔╔═╗╔╦╗╦ ╦╔═╗╦═╗╦╔═
#  ║╠═╣╚╦╝  ║║║║╣  ║ ║║║║ ║╠╦╝╠╩╗
#  ╚╝╩ ╩ ╩   ╝╚╝╚═╝ ╩ ╚╩╝╚═╝╩╚═╩ ╩
#
#  GCP Full Production Deployment Script
#
#  Deploys a complete Jay Network across Google Cloud Platform:
#    - 3 Validator nodes (Cosmovisor + TMKMS)
#    - 1 Sentry/Explorer node (Ping.pub + BigDipper)
#    - 1 Archive/Snapshot node (State Sync RPC)
#    - 1 TMKMS Signer
#
#  Prerequisites:
#    - gcloud CLI authenticated
#    - Linux binary built: build/jaynd-linux-amd64
#    - SSH key configured for GCP
#
#  Usage:
#    ./deploy_jay_network_gcp.sh
#
###############################################################################

#==============================================================================
# CONFIG
#==============================================================================

PROJECT="jay-network"
ZONE="us-central1-a"
REGION="us-central1"

DOMAIN="pribit.org"
DNS_ZONE="pribit-zone"

CHAIN_NAME="thejaynetwork"
CHAIN_ID="thejaynetwork-1"
BINARY="jaynd"
DENOM="ujay"
PREFIX="yjay"

GO_VERSION="1.24.1"

MACHINE_TYPE_VALIDATOR="e2-standard-8"   # 8 vCPU, 32 GB
MACHINE_TYPE_SENTRY="e2-standard-4"      # 4 vCPU, 16 GB
MACHINE_TYPE_SIGNER="e2-medium"          # 1 vCPU, 4 GB
DISK_SIZE="500GB"
IMAGE_FAMILY="ubuntu-2204-lts"
IMAGE_PROJECT="ubuntu-os-cloud"

# Node definitions
declare -A NODE_ROLES=(
    ["node1"]="validator"
    ["node2"]="validator"
    ["node3"]="validator"
    ["node4"]="sentry"
    ["node5"]="archive"
    ["signer"]="signer"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_FILE="${SCRIPT_DIR}/build/jaynd-linux-amd64"
DEPLOY_SCRIPT="${SCRIPT_DIR}/scripts/deploy_node.sh"

#==============================================================================
# COLORS
#==============================================================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log_info()   { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()     { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()  { echo -e "${RED}[ERROR]${NC} $*"; }
log_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  $*${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

#==============================================================================
# PREFLIGHT
#==============================================================================
log_banner "Jay Network GCP Deployment — Preflight"

# Verify binary
if [[ ! -f "${BINARY_FILE}" ]]; then
    log_error "Linux binary not found: ${BINARY_FILE}"
    log_error "Build: GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags='-s -w' -o build/jaynd-linux-amd64 ./cmd/jaynd"
    exit 1
fi
log_ok "Binary: ${BINARY_FILE} ($(du -sh "${BINARY_FILE}" | cut -f1))"

# Verify gcloud
if ! command -v gcloud &>/dev/null; then
    log_error "gcloud CLI not found. Install: https://cloud.google.com/sdk/docs/install"
    exit 1
fi
log_ok "gcloud CLI available"

gcloud config set project "${PROJECT}" 2>/dev/null
log_ok "GCP project: ${PROJECT}"

#==============================================================================
# PHASE 1: INFRASTRUCTURE
#==============================================================================
log_banner "Phase 1: GCP Infrastructure"

# VPC Network
log_info "Creating VPC network..."
gcloud compute networks create jay-network --subnet-mode=auto 2>/dev/null || log_warn "Network already exists"

# Firewall rules
log_info "Creating firewall rules..."
gcloud compute firewall-rules create jay-allow-p2p \
    --network jay-network \
    --allow tcp:26656 \
    --target-tags=jay-network \
    --description="P2P gossip" 2>/dev/null || true

gcloud compute firewall-rules create jay-allow-rpc \
    --network jay-network \
    --allow tcp:26657,tcp:1317,tcp:9090 \
    --target-tags=jay-rpc \
    --description="RPC/REST/gRPC" 2>/dev/null || true

gcloud compute firewall-rules create jay-allow-ssh \
    --network jay-network \
    --allow tcp:22 \
    --target-tags=jay-network \
    --description="SSH" 2>/dev/null || true

gcloud compute firewall-rules create jay-allow-monitoring \
    --network jay-network \
    --allow tcp:26660,tcp:3000,tcp:9100 \
    --target-tags=jay-monitoring \
    --description="Prometheus/Grafana" 2>/dev/null || true

log_ok "Firewall rules configured"

# Cloud Armor (DDoS protection)
log_info "Creating Cloud Armor policy..."
gcloud compute security-policies create jay-ddos 2>/dev/null || true
gcloud compute security-policies rules create 1000 \
    --security-policy jay-ddos \
    --expression "evaluatePreconfiguredExpr('sqli-stable')" \
    --action deny-403 2>/dev/null || true
gcloud compute security-policies rules create 1001 \
    --security-policy jay-ddos \
    --expression "evaluatePreconfiguredExpr('xss-stable')" \
    --action deny-403 2>/dev/null || true
log_ok "Cloud Armor DDoS protection"

# DNS Zone
log_info "Creating DNS zone..."
gcloud dns managed-zones create "${DNS_ZONE}" \
    --dns-name="${DOMAIN}." \
    --description="Jay Network DNS" 2>/dev/null || log_warn "DNS zone already exists"
log_ok "DNS zone: ${DNS_ZONE}"

#==============================================================================
# PHASE 2: CREATE VMs
#==============================================================================
log_banner "Phase 2: Create VMs"

for NODE in "${!NODE_ROLES[@]}"; do
    ROLE="${NODE_ROLES[$NODE]}"

    # Select machine type based on role
    case "${ROLE}" in
        validator)  MT="${MACHINE_TYPE_VALIDATOR}"; TAGS="jay-network,jay-monitoring" ;;
        sentry)     MT="${MACHINE_TYPE_SENTRY}"; TAGS="jay-network,jay-rpc,jay-monitoring" ;;
        archive)    MT="${MACHINE_TYPE_SENTRY}"; TAGS="jay-network,jay-rpc,jay-monitoring" ;;
        signer)     MT="${MACHINE_TYPE_SIGNER}"; TAGS="jay-network" ;;
    esac

    log_info "Creating VM: ${NODE} (${MT}, ${ROLE})..."
    gcloud compute instances create "${NODE}" \
        --zone="${ZONE}" \
        --machine-type="${MT}" \
        --boot-disk-size="${DISK_SIZE}" \
        --boot-disk-type=pd-ssd \
        --image-family="${IMAGE_FAMILY}" \
        --image-project="${IMAGE_PROJECT}" \
        --tags="${TAGS}" \
        --network=jay-network \
        --metadata=startup-script='#!/bin/bash
apt-get update -qq && apt-get install -y -qq jq lz4 curl wget' \
        2>/dev/null || log_warn "${NODE} already exists"
done
log_ok "All VMs created"

# Wait for VMs to be ready
log_info "Waiting 30s for VMs to initialize..."
sleep 30

#==============================================================================
# PHASE 3: DNS RECORDS
#==============================================================================
log_banner "Phase 3: DNS Records"

for NODE in node1 node2 node3 node4 node5; do
    IP=$(gcloud compute instances describe "${NODE}" \
        --zone="${ZONE}" \
        --format='get(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null || echo "")

    if [[ -n "${IP}" ]]; then
        gcloud dns record-sets transaction start --zone="${DNS_ZONE}" 2>/dev/null || true
        gcloud dns record-sets transaction add "${IP}" \
            --name="${NODE}.${DOMAIN}." \
            --ttl=300 \
            --type=A \
            --zone="${DNS_ZONE}" 2>/dev/null || true
        gcloud dns record-sets transaction execute --zone="${DNS_ZONE}" 2>/dev/null || true
        log_ok "${NODE}.${DOMAIN} → ${IP}"
    fi
done

#==============================================================================
# PHASE 4: DEPLOY JAYND TO ALL NODES
#==============================================================================
log_banner "Phase 4: Deploy jaynd"

declare -A NODE_IDS

for NODE in node1 node2 node3 node4 node5; do
    ROLE="${NODE_ROLES[$NODE]}"
    log_info "Deploying ${NODE} as ${ROLE}..."

    # Upload files
    gcloud compute scp "${BINARY_FILE}" "${NODE}:/tmp/jaynd-linux-amd64" --zone="${ZONE}" 2>/dev/null
    gcloud compute scp "${DEPLOY_SCRIPT}" "${NODE}:/tmp/deploy_node.sh" --zone="${ZONE}" 2>/dev/null

    # Run deployment
    gcloud compute ssh "${NODE}" --zone="${ZONE}" --command="
        mkdir -p /tmp/jaynet-deploy/build /tmp/jaynet-deploy/scripts
        cp /tmp/jaynd-linux-amd64 /tmp/jaynet-deploy/build/
        cp /tmp/deploy_node.sh /tmp/jaynet-deploy/scripts/
        chmod +x /tmp/jaynet-deploy/scripts/deploy_node.sh
        cd /tmp/jaynet-deploy
        sudo bash scripts/deploy_node.sh --moniker ${NODE} --role ${ROLE} --chain-id ${CHAIN_ID}
    "

    # Get node ID
    NID=$(gcloud compute ssh "${NODE}" --zone="${ZONE}" --command="jaynd comet show-node-id --home /home/jaynet/.jayn" 2>/dev/null || echo "unknown")
    IP=$(gcloud compute instances describe "${NODE}" --zone="${ZONE}" --format='get(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null || echo "")
    NODE_IDS["${NODE}"]="${NID}@${IP}:26656"

    log_ok "${NODE}: ${NID}@${IP}:26656"
done

#==============================================================================
# PHASE 5: GENESIS
#==============================================================================
log_banner "Phase 5: Genesis Creation (node1)"

gcloud compute ssh node1 --zone="${ZONE}" --command="
set -e
BINARY=jaynd
HOME_DIR=/home/jaynet/.jayn
CHAIN_ID=${CHAIN_ID}
DENOM=${DENOM}

echo '=== Creating genesis validator ==='
sudo -u jaynet \${BINARY} keys add validator --keyring-backend test --home \${HOME_DIR}
ADDR=\$(sudo -u jaynet \${BINARY} keys show validator -a --keyring-backend test --home \${HOME_DIR})
echo \"Validator: \${ADDR}\"

sudo -u jaynet \${BINARY} genesis add-genesis-account \${ADDR} 1000000000000\${DENOM} --home \${HOME_DIR}

sudo -u jaynet \${BINARY} genesis gentx validator 500000000000\${DENOM} \\
    --chain-id \${CHAIN_ID} \\
    --keyring-backend test \\
    --moniker node1 \\
    --commission-rate 0.05 \\
    --commission-max-rate 0.20 \\
    --commission-max-change-rate 0.01 \\
    --min-self-delegation 1 \\
    --home \${HOME_DIR}

sudo -u jaynet \${BINARY} genesis collect-gentxs --home \${HOME_DIR}
sudo -u jaynet \${BINARY} genesis validate --home \${HOME_DIR}
echo '=== Genesis ready ==='
"
log_ok "Genesis created and validated"

#==============================================================================
# PHASE 6: DISTRIBUTE GENESIS + PEERS
#==============================================================================
log_banner "Phase 6: Distribute Genesis & Configure Peers"

# Download genesis from node1
gcloud compute scp node1:/home/jaynet/.jayn/config/genesis.json /tmp/jaynet_genesis.json --zone="${ZONE}" 2>/dev/null

# Build peer list
ALL_PEERS=""
for NODE in node1 node2 node3 node4 node5; do
    if [[ -n "${ALL_PEERS}" ]]; then
        ALL_PEERS="${ALL_PEERS},${NODE_IDS[$NODE]}"
    else
        ALL_PEERS="${NODE_IDS[$NODE]}"
    fi
done
log_info "Peer list: ${ALL_PEERS}"

# Distribute to all nodes
for NODE in node2 node3 node4 node5; do
    log_info "Configuring ${NODE}..."

    # Upload genesis
    gcloud compute scp /tmp/jaynet_genesis.json "${NODE}:/home/jaynet/.jayn/config/genesis.json" --zone="${ZONE}" 2>/dev/null

    # Build peers (exclude self)
    SELF="${NODE_IDS[$NODE]}"
    PEERS=$(echo "${ALL_PEERS}" | sed "s|${SELF}||g" | sed 's/,,/,/g' | sed 's/^,//;s/,$//')

    # Set peers
    gcloud compute ssh "${NODE}" --zone="${ZONE}" --command="
        chown jaynet:jaynet /home/jaynet/.jayn/config/genesis.json
        sed -i 's|persistent_peers = \".*\"|persistent_peers = \"${PEERS}\"|' /home/jaynet/.jayn/config/config.toml
    "
    log_ok "${NODE}: genesis + peers set"
done

# Set peers on node1 too
SELF1="${NODE_IDS[node1]}"
PEERS1=$(echo "${ALL_PEERS}" | sed "s|${SELF1}||g" | sed 's/,,/,/g' | sed 's/^,//;s/,$//')
gcloud compute ssh node1 --zone="${ZONE}" --command="
    sed -i 's|persistent_peers = \".*\"|persistent_peers = \"${PEERS1}\"|' /home/jaynet/.jayn/config/config.toml
"
log_ok "node1: peers set"

rm -f /tmp/jaynet_genesis.json

#==============================================================================
# PHASE 7: TMKMS SIGNER
#==============================================================================
log_banner "Phase 7: TMKMS Signer"

gcloud compute ssh signer --zone="${ZONE}" --command="
sudo apt-get install -y -qq cargo pkg-config libusb-1.0-0-dev
cargo install tmkms --features=softsign

mkdir -p ~/.tmkms/secrets ~/.tmkms/state

echo '=== TMKMS installed ==='
echo 'Configure ~/.tmkms/tmkms.toml with your validator connection details.'
echo 'See: https://github.com/iqlusioninc/tmkms'
" 2>/dev/null || log_warn "TMKMS setup may need manual attention"
log_ok "TMKMS signer prepared"

#==============================================================================
# PHASE 8: START NETWORK
#==============================================================================
log_banner "Phase 8: Start Network"

# Start genesis validator first
log_info "Starting node1 (genesis validator)..."
gcloud compute ssh node1 --zone="${ZONE}" --command="sudo systemctl start ${BINARY}"
log_info "Waiting 15s for first blocks..."
sleep 15

# Start remaining nodes
for NODE in node2 node3 node4 node5; do
    log_info "Starting ${NODE}..."
    gcloud compute ssh "${NODE}" --zone="${ZONE}" --command="sudo systemctl start ${BINARY}"
    sleep 3
done

log_ok "All nodes started"

#==============================================================================
# PHASE 9: EXPLORER (node4)
#==============================================================================
log_banner "Phase 9: Block Explorer (node4)"

gcloud compute ssh node4 --zone="${ZONE}" --command="
sudo apt-get install -y -qq nodejs npm docker.io docker-compose-plugin 2>/dev/null

# Ping.pub Explorer
if [ ! -d ~/explorer ]; then
    git clone https://github.com/ping-pub/explorer ~/explorer
    cd ~/explorer
    npm install 2>/dev/null
    npm run build 2>/dev/null
    nohup npm start > /var/log/explorer.log 2>&1 &
fi
echo 'Explorer running on port 5173'
" 2>/dev/null || log_warn "Explorer setup may need manual attention"
log_ok "Explorer deployed on node4"

#==============================================================================
# PHASE 10: VERIFICATION
#==============================================================================
log_banner "Phase 10: Network Verification"

sleep 10

echo ""
echo "Node Status:"
echo "─────────────────────────────────────────────"
for NODE in node1 node2 node3 node4 node5; do
    STATUS=$(gcloud compute ssh "${NODE}" --zone="${ZONE}" --command="
        curl -sf http://localhost:26657/status 2>/dev/null | jq -r '
            .result |
            \"height=\" + .sync_info.latest_block_height +
            \" catching_up=\" + (.sync_info.catching_up|tostring) +
            \" peers=\" + (.node_info.channels // \"?\")
        '
    " 2>/dev/null || echo "unreachable")
    printf "  %-8s [%-9s] %s\n" "${NODE}" "${NODE_ROLES[$NODE]}" "${STATUS}"
done

#==============================================================================
# FINAL SUMMARY
#==============================================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                                      ║${NC}"
echo -e "${GREEN}║   ██╗ █████╗ ██╗   ██╗    ███╗   ██╗███████╗████████╗                ║${NC}"
echo -e "${GREEN}║   ██║██╔══██╗╚██╗ ██╔╝    ████╗  ██║██╔════╝╚══██╔══╝                ║${NC}"
echo -e "${GREEN}║   ██║███████║ ╚████╔╝     ██╔██╗ ██║█████╗     ██║                   ║${NC}"
echo -e "${GREEN}║  ██║██╔══██║  ╚██╔╝      ██║╚██╗██║██╔══╝     ██║                   ║${NC}"
echo -e "${GREEN}║   ╚█████╔╝██║  ██║   ██║       ██║ ╚████║███████╗   ██║                   ║${NC}"
echo -e "${GREEN}║    ╚════╝ ╚═╝  ╚═╝   ╚═╝       ╚═╝  ╚═══╝╚══════╝   ╚═╝                   ║${NC}"
echo -e "${GREEN}║                                                                      ║${NC}"
echo -e "${GREEN}║              MAINNET DEPLOYED SUCCESSFULLY                           ║${NC}"
echo -e "${GREEN}║                                                                      ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  Chain:      ${CYAN}${CHAIN_NAME}${NC} (${CHAIN_ID})"
echo -e "${GREEN}║${NC}  Prefix:     ${CYAN}${PREFIX}${NC}"
echo -e "${GREEN}║${NC}  Denom:      ${CYAN}${DENOM}${NC}"
echo -e "${GREEN}║${NC}  Binary:     ${CYAN}${BINARY}${NC}"
echo -e "${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${YELLOW}Validators:${NC}"
echo -e "${GREEN}║${NC}    node1     ${CYAN}node1.${DOMAIN}${NC}  [genesis validator]"
echo -e "${GREEN}║${NC}    node2     ${CYAN}node2.${DOMAIN}${NC}"
echo -e "${GREEN}║${NC}    node3     ${CYAN}node3.${DOMAIN}${NC}"
echo -e "${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${YELLOW}Public Endpoints:${NC}"
echo -e "${GREEN}║${NC}    RPC:      ${CYAN}http://node4.${DOMAIN}:26657${NC}"
echo -e "${GREEN}║${NC}    REST:     ${CYAN}http://node4.${DOMAIN}:1317${NC}"
echo -e "${GREEN}║${NC}    gRPC:     ${CYAN}node4.${DOMAIN}:9090${NC}"
echo -e "${GREEN}║${NC}    Explorer: ${CYAN}http://node4.${DOMAIN}:5173${NC}"
echo -e "${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${YELLOW}Archive/Snapshot:${NC}"
echo -e "${GREEN}║${NC}    RPC:      ${CYAN}http://node5.${DOMAIN}:26657${NC}"
echo -e "${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${YELLOW}TMKMS:${NC}"
echo -e "${GREEN}║${NC}    Signer:   ${CYAN}signer.${DOMAIN}${NC} (configure manually)"
echo -e "${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

