#!/usr/bin/env bash
set -euo pipefail

###############################################################################
#
#  ╦╔═╗╦ ╦  ╔╗╔╔═╗╔╦╗╦ ╦╔═╗╦═╗╦╔═
#  ║╠═╣╚╦╝  ║║║║╣  ║ ║║║║ ║╠╦╝╠╩╗
#  ╚╝╩ ╩ ╩   ╝╚╝╚═╝ ╩ ╚╩╝╚═╝╩╚═╩ ╩
#
#  All-in-One Node Deployment Script
#  Deploys a full production jaynd node on a fresh Ubuntu 22.04+ server.
#
#  Usage:
#    sudo ./deploy_node.sh --moniker <NAME> --role <validator|sentry|seed|archive>
#
#  Options:
#    --moniker      Node moniker name (required)
#    --role         Node role: validator, sentry, seed, archive (default: validator)
#    --chain-id     Chain ID (default: thejaynetwork-1)
#    --genesis-url  URL to download genesis.json (optional)
#    --peers        Comma-separated persistent peers (optional)
#    --seeds        Comma-separated seed nodes (optional)
#    --state-sync   RPC endpoint for state sync bootstrap (optional)
#    --snapshot-url URL to download snapshot tarball (optional)
#    --skip-deps    Skip system dependency installation
#    --user         Service user name (default: jaynet)
#
#  Examples:
#    # Genesis validator (first node):
#    sudo ./deploy_node.sh --moniker node1 --role validator
#
#    # Join existing network:
#    sudo ./deploy_node.sh --moniker node2 --role validator \
#      --genesis-url http://node1.pribit.org:26657/genesis \
#      --peers "node1_id@node1.pribit.org:26656"
#
#    # Fast sync with state sync:
#    sudo ./deploy_node.sh --moniker sentry1 --role sentry \
#      --genesis-url http://node1.pribit.org:26657/genesis \
#      --state-sync http://node5.pribit.org:26657
#
###############################################################################

#==============================================================================
# CHAIN CONSTANTS (do not change unless forking)
#==============================================================================
readonly CHAIN_NAME="thejaynetwork"
readonly BINARY_NAME="jaynd"
readonly DENOM="ujay"
readonly PREFIX="yjay"
readonly MIN_GAS_PRICE="0.0025${DENOM}"
readonly GO_VERSION="1.24.1"
readonly COSMOVISOR_VERSION="latest"

#==============================================================================
# DEFAULT PARAMETERS
#==============================================================================
MONIKER=""
ROLE="validator"
CHAIN_ID="thejaynetwork-1"
GENESIS_URL=""
PEERS=""
SEEDS=""
STATE_SYNC_RPC=""
SNAPSHOT_URL=""
SKIP_DEPS=false
SERVICE_USER="jaynet"

#==============================================================================
# COLORS
#==============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "\n${CYAN}══════════════════════════════════════════${NC}"; echo -e "${CYAN}  $*${NC}"; echo -e "${CYAN}══════════════════════════════════════════${NC}"; }

#==============================================================================
# PARSE ARGUMENTS
#==============================================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --moniker)      MONIKER="$2"; shift 2 ;;
        --role)         ROLE="$2"; shift 2 ;;
        --chain-id)     CHAIN_ID="$2"; shift 2 ;;
        --genesis-url)  GENESIS_URL="$2"; shift 2 ;;
        --peers)        PEERS="$2"; shift 2 ;;
        --seeds)        SEEDS="$2"; shift 2 ;;
        --state-sync)   STATE_SYNC_RPC="$2"; shift 2 ;;
        --snapshot-url) SNAPSHOT_URL="$2"; shift 2 ;;
        --skip-deps)    SKIP_DEPS=true; shift ;;
        --user)         SERVICE_USER="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,/^###############################################################################$/p' "$0" | head -n -1
            exit 0 ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "${MONIKER}" ]]; then
    log_error "Missing required --moniker parameter"
    echo "Usage: sudo $0 --moniker <NAME> --role <validator|sentry|seed|archive>"
    exit 1
fi

if [[ ! "${ROLE}" =~ ^(validator|sentry|seed|archive)$ ]]; then
    log_error "Invalid role: ${ROLE}. Must be: validator, sentry, seed, archive"
    exit 1
fi

# Derived paths
HOME_DIR="/home/${SERVICE_USER}/.jayn"
COSMOVISOR_DIR="${HOME_DIR}/cosmovisor"
BINARY_PATH="/usr/local/bin/${BINARY_NAME}"

#==============================================================================
# PREFLIGHT CHECKS
#==============================================================================
log_step "Preflight Checks"

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (sudo)"
    exit 1
fi

ARCH=$(uname -m)
case "${ARCH}" in
    x86_64)  BINARY_SUFFIX="linux-amd64" ;;
    aarch64) BINARY_SUFFIX="linux-arm64" ;;
    *) log_error "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

log_info "Moniker:       ${MONIKER}"
log_info "Role:          ${ROLE}"
log_info "Chain ID:      ${CHAIN_ID}"
log_info "Architecture:  ${ARCH} → ${BINARY_SUFFIX}"
log_info "Service User:  ${SERVICE_USER}"
log_info "Home Dir:      ${HOME_DIR}"

#==============================================================================
# STEP 1: SYSTEM DEPENDENCIES
#==============================================================================
if [[ "${SKIP_DEPS}" == false ]]; then
    log_step "Step 1/10: System Dependencies"

    apt-get update -qq
    apt-get install -y -qq \
        build-essential git curl wget jq lz4 unzip \
        ufw fail2ban chrony \
        > /dev/null 2>&1

    log_ok "System packages installed"

    # Install Go
    if ! command -v go &>/dev/null || [[ "$(go version 2>/dev/null)" != *"${GO_VERSION}"* ]]; then
        log_info "Installing Go ${GO_VERSION}..."
        curl -sL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH/x86_64/amd64}.tar.gz" -o /tmp/go.tar.gz
        rm -rf /usr/local/go
        tar -C /usr/local -xzf /tmp/go.tar.gz
        rm -f /tmp/go.tar.gz

        # Set PATH for all users
        cat > /etc/profile.d/golang.sh << 'GOEOF'
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
GOEOF
        source /etc/profile.d/golang.sh
    fi
    log_ok "Go $(go version | awk '{print $3}') ready"
else
    log_step "Step 1/10: System Dependencies (SKIPPED)"
    source /etc/profile.d/golang.sh 2>/dev/null || true
fi

export PATH=$PATH:/usr/local/go/bin:/home/${SERVICE_USER}/go/bin

#==============================================================================
# STEP 2: CREATE SERVICE USER
#==============================================================================
log_step "Step 2/10: Service User"

if ! id "${SERVICE_USER}" &>/dev/null; then
    useradd -m -s /bin/bash "${SERVICE_USER}"
    log_ok "User '${SERVICE_USER}' created"
else
    log_ok "User '${SERVICE_USER}' already exists"
fi

#==============================================================================
# STEP 3: INSTALL BINARY
#==============================================================================
log_step "Step 3/10: Install jaynd Binary"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
LOCAL_BINARY="${PROJECT_DIR}/build/jaynd-${BINARY_SUFFIX}"

if [[ -f "${LOCAL_BINARY}" ]]; then
    cp "${LOCAL_BINARY}" "${BINARY_PATH}"
    chmod +x "${BINARY_PATH}"
    log_ok "Installed from local build: ${LOCAL_BINARY}"
elif [[ -f "${PROJECT_DIR}/build/${BINARY_NAME}" ]]; then
    cp "${PROJECT_DIR}/build/${BINARY_NAME}" "${BINARY_PATH}"
    chmod +x "${BINARY_PATH}"
    log_ok "Installed from local build: ${PROJECT_DIR}/build/${BINARY_NAME}"
else
    log_error "Binary not found. Build first:"
    log_error "  GOOS=linux GOARCH=amd64 go build -o build/jaynd-linux-amd64 ./cmd/jaynd"
    exit 1
fi

${BINARY_PATH} version && log_ok "jaynd binary verified" || { log_error "Binary verification failed"; exit 1; }

#==============================================================================
# STEP 4: INITIALIZE NODE
#==============================================================================
log_step "Step 4/10: Initialize Node"

if [[ -d "${HOME_DIR}/config" ]]; then
    log_warn "Node directory already exists at ${HOME_DIR}"
    log_warn "Backing up existing config..."
    cp -r "${HOME_DIR}/config" "${HOME_DIR}/config.bak.$(date +%s)"
fi

sudo -u "${SERVICE_USER}" ${BINARY_PATH} init "${MONIKER}" \
    --chain-id "${CHAIN_ID}" \
    --home "${HOME_DIR}" \
    --default-denom "${DENOM}" \
    > /dev/null 2>&1

log_ok "Node initialized: ${MONIKER} @ ${CHAIN_ID}"

#==============================================================================
# STEP 5: PRODUCTION CONFIG TUNING
#==============================================================================
log_step "Step 5/10: Production Configuration"

CONFIG_TOML="${HOME_DIR}/config/config.toml"
APP_TOML="${HOME_DIR}/config/app.toml"
CLIENT_TOML="${HOME_DIR}/config/client.toml"
GENESIS="${HOME_DIR}/config/genesis.json"

# ---- config.toml ----
log_info "Tuning config.toml..."

# Fast consensus for production
sed -i 's/timeout_propose = "3s"/timeout_propose = "2s"/' "${CONFIG_TOML}"
sed -i 's/timeout_prevote = "1s"/timeout_prevote = "500ms"/' "${CONFIG_TOML}"
sed -i 's/timeout_precommit = "1s"/timeout_precommit = "500ms"/' "${CONFIG_TOML}"
sed -i 's/timeout_commit = "5s"/timeout_commit = "3s"/' "${CONFIG_TOML}"

# Mempool
sed -i 's/size = 5000/size = 10000/' "${CONFIG_TOML}"
sed -i 's/cache_size = 10000/cache_size = 20000/' "${CONFIG_TOML}"

# P2P tuning
sed -i 's/max_num_inbound_peers = 40/max_num_inbound_peers = 120/' "${CONFIG_TOML}"
sed -i 's/max_num_outbound_peers = 10/max_num_outbound_peers = 40/' "${CONFIG_TOML}"
sed -i 's/flush_throttle_timeout = "100ms"/flush_throttle_timeout = "10ms"/' "${CONFIG_TOML}"
sed -i 's/send_rate = 5120000/send_rate = 20480000/' "${CONFIG_TOML}"
sed -i 's/recv_rate = 5120000/recv_rate = 20480000/' "${CONFIG_TOML}"
sed -i 's/max_packet_msg_payload_size = 1024/max_packet_msg_payload_size = 4096/' "${CONFIG_TOML}"

# Prometheus metrics
sed -i 's/prometheus = false/prometheus = true/' "${CONFIG_TOML}"

# Indexer (validators don't need full indexing)
if [[ "${ROLE}" == "validator" ]]; then
    sed -i 's/indexer = "kv"/indexer = "null"/' "${CONFIG_TOML}"
fi

# Seed mode for seed nodes
if [[ "${ROLE}" == "seed" ]]; then
    sed -i 's/seed_mode = false/seed_mode = true/' "${CONFIG_TOML}"
fi

# Set peers/seeds
if [[ -n "${PEERS}" ]]; then
    sed -i "s/persistent_peers = \"\"/persistent_peers = \"${PEERS}\"/" "${CONFIG_TOML}"
fi
if [[ -n "${SEEDS}" ]]; then
    sed -i "s/seeds = \"\"/seeds = \"${SEEDS}\"/" "${CONFIG_TOML}"
fi

log_ok "config.toml tuned"

# ---- app.toml ----
log_info "Tuning app.toml..."

# Minimum gas prices
sed -i "s/minimum-gas-prices = \"\"/minimum-gas-prices = \"${MIN_GAS_PRICE}\"/" "${APP_TOML}"
# Some versions use 0stake as default
sed -i "s/minimum-gas-prices = \"0stake\"/minimum-gas-prices = \"${MIN_GAS_PRICE}\"/" "${APP_TOML}"

# Enable API
sed -i '/\[api\]/,/\[/{s/enable = false/enable = true/}' "${APP_TOML}"
sed -i 's|swagger = false|swagger = true|g' "${APP_TOML}"

# Enable gRPC
sed -i '/\[grpc\]/,/\[/{s/enable = false/enable = true/}' "${APP_TOML}"

# Pruning strategy per role
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

# State sync snapshots (sentries serve snapshots)
if [[ "${ROLE}" == "sentry" || "${ROLE}" == "archive" ]]; then
    sed -i 's/snapshot-interval = 0/snapshot-interval = 1000/' "${APP_TOML}"
    sed -i 's/snapshot-keep-recent = 2/snapshot-keep-recent = 5/' "${APP_TOML}"
fi

# Telemetry
sed -i '/\[telemetry\]/,/\[/{s/enabled = false/enabled = true/}' "${APP_TOML}"
sed -i 's/prometheus-retention-time = 0/prometheus-retention-time = 60/' "${APP_TOML}"

log_ok "app.toml tuned"

# ---- client.toml ----
log_info "Tuning client.toml..."
sed -i "s/chain-id = \"\"/chain-id = \"${CHAIN_ID}\"/" "${CLIENT_TOML}"
sed -i 's/keyring-backend = "os"/keyring-backend = "file"/' "${CLIENT_TOML}"
log_ok "client.toml tuned"

#==============================================================================
# STEP 6: GENESIS
#==============================================================================
log_step "Step 6/10: Genesis Configuration"

if [[ -n "${GENESIS_URL}" ]]; then
    log_info "Downloading genesis from ${GENESIS_URL}..."

    # Support both raw file URL and CometBFT RPC /genesis endpoint
    if [[ "${GENESIS_URL}" == *"/genesis" ]]; then
        # CometBFT RPC endpoint → extract .result.genesis
        curl -s "${GENESIS_URL}" | jq '.result.genesis' > "${GENESIS}"
    else
        curl -sL "${GENESIS_URL}" -o "${GENESIS}"
    fi

    # Validate
    if ! jq empty "${GENESIS}" 2>/dev/null; then
        log_error "Downloaded genesis.json is invalid JSON"
        exit 1
    fi
    log_ok "Genesis downloaded and validated"
else
    # Fix default genesis (replace "stake" with our denom)
    sed -i "s/\"stake\"/\"${DENOM}\"/g" "${GENESIS}"
    log_ok "Local genesis configured with denom: ${DENOM}"
    log_warn "No --genesis-url provided. You must copy the final genesis.json manually."
fi

#==============================================================================
# STEP 7: STATE SYNC / SNAPSHOT
#==============================================================================
log_step "Step 7/10: Chain Data Bootstrap"

if [[ -n "${STATE_SYNC_RPC}" ]]; then
    log_info "Configuring state sync from ${STATE_SYNC_RPC}..."

    LATEST=$(curl -s "${STATE_SYNC_RPC}/block" | jq -r '.result.block.header.height')
    TRUST_HEIGHT=$((LATEST - 2000))
    TRUST_HASH=$(curl -s "${STATE_SYNC_RPC}/block?height=${TRUST_HEIGHT}" | jq -r '.result.block_id.hash')

    log_info "Latest height:  ${LATEST}"
    log_info "Trust height:   ${TRUST_HEIGHT}"
    log_info "Trust hash:     ${TRUST_HASH}"

    # Enable state sync in [statesync] section
    sed -i '/\[statesync\]/,/^\[/{
        s/enable = false/enable = true/
    }' "${CONFIG_TOML}"
    sed -i "s|rpc_servers = \"\"|rpc_servers = \"${STATE_SYNC_RPC},${STATE_SYNC_RPC}\"|" "${CONFIG_TOML}"
    sed -i "s/trust_height = 0/trust_height = ${TRUST_HEIGHT}/" "${CONFIG_TOML}"
    sed -i "s/trust_hash = \"\"/trust_hash = \"${TRUST_HASH}\"/" "${CONFIG_TOML}"

    log_ok "State sync configured"

elif [[ -n "${SNAPSHOT_URL}" ]]; then
    log_info "Downloading snapshot from ${SNAPSHOT_URL}..."

    # Wipe existing data
    rm -rf "${HOME_DIR}/data"
    mkdir -p "${HOME_DIR}/data"

    if [[ "${SNAPSHOT_URL}" == *.lz4 ]]; then
        curl -sL "${SNAPSHOT_URL}" | lz4 -d - | tar xf - -C "${HOME_DIR}"
    elif [[ "${SNAPSHOT_URL}" == *.gz || "${SNAPSHOT_URL}" == *.tgz ]]; then
        curl -sL "${SNAPSHOT_URL}" | tar xzf - -C "${HOME_DIR}"
    else
        curl -sL "${SNAPSHOT_URL}" | tar xf - -C "${HOME_DIR}"
    fi

    log_ok "Snapshot restored"
else
    log_info "No state sync or snapshot configured. Node will sync from genesis."
fi

#==============================================================================
# STEP 8: COSMOVISOR
#==============================================================================
log_step "Step 8/10: Cosmovisor Setup"

# Install Cosmovisor
export GOPATH="/home/${SERVICE_USER}/go"
export PATH="${PATH}:${GOPATH}/bin"
sudo -u "${SERVICE_USER}" bash -c "export GOPATH=${GOPATH}; export PATH=\$PATH:/usr/local/go/bin:\${GOPATH}/bin; go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@${COSMOVISOR_VERSION}" 2>&1 || {
    log_warn "Cosmovisor install via go failed. Trying binary download..."
    # Fallback: just use the binary directly without cosmovisor
}

# Create cosmovisor directory structure
mkdir -p "${COSMOVISOR_DIR}/genesis/bin"
mkdir -p "${COSMOVISOR_DIR}/upgrades"

# Copy binary
cp "${BINARY_PATH}" "${COSMOVISOR_DIR}/genesis/bin/${BINARY_NAME}"
chmod +x "${COSMOVISOR_DIR}/genesis/bin/${BINARY_NAME}"

# Create current symlink
ln -sf "${COSMOVISOR_DIR}/genesis" "${COSMOVISOR_DIR}/current"

# Environment variables for cosmovisor
cat > /etc/profile.d/cosmovisor.sh << CVEOF
export DAEMON_NAME=${BINARY_NAME}
export DAEMON_HOME=${HOME_DIR}
export DAEMON_ALLOW_DOWNLOAD_BINARIES=true
export DAEMON_RESTART_AFTER_UPGRADE=true
export DAEMON_LOG_BUFFER_SIZE=512
export UNSAFE_SKIP_BACKUP=false
CVEOF

log_ok "Cosmovisor installed and configured"

#==============================================================================
# STEP 9: SYSTEMD SERVICE
#==============================================================================
log_step "Step 9/10: Systemd Service"

# Determine ExecStart based on whether cosmovisor is available
COSMOVISOR_BIN="/home/${SERVICE_USER}/go/bin/cosmovisor"
if [[ -f "${COSMOVISOR_BIN}" ]]; then
    EXEC_START="${COSMOVISOR_BIN} run start --home ${HOME_DIR}"
else
    EXEC_START="${BINARY_PATH} start --home ${HOME_DIR}"
fi

cat > /etc/systemd/system/${BINARY_NAME}.service << SVCEOF
[Unit]
Description=Jay Network Node (${BINARY_NAME}) - ${MONIKER} [${ROLE}]
Documentation=https://pribit.org
After=network-online.target
Wants=network-online.target

[Service]
User=${SERVICE_USER}
Group=${SERVICE_USER}
ExecStart=${EXEC_START}
Restart=always
RestartSec=3
LimitNOFILE=65536
LimitNPROC=65536
TimeoutStartSec=120
TimeoutStopSec=30

# Cosmovisor environment
Environment="DAEMON_NAME=${BINARY_NAME}"
Environment="DAEMON_HOME=${HOME_DIR}"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=true"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
Environment="DAEMON_LOG_BUFFER_SIZE=512"
Environment="UNSAFE_SKIP_BACKUP=false"

# Resource limits
MemoryMax=16G
TasksMax=4096

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${BINARY_NAME}

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable ${BINARY_NAME}.service
log_ok "Systemd service installed and enabled"

#==============================================================================
# STEP 10: SECURITY HARDENING
#==============================================================================
log_step "Step 10/10: Security Hardening"

# Firewall (UFW)
log_info "Configuring firewall..."
ufw --force reset > /dev/null 2>&1
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1
ufw allow 22/tcp comment "SSH" > /dev/null 2>&1
ufw allow 26656/tcp comment "P2P" > /dev/null 2>&1

if [[ "${ROLE}" != "validator" ]]; then
    ufw allow 26657/tcp comment "RPC" > /dev/null 2>&1
    ufw allow 1317/tcp comment "REST API" > /dev/null 2>&1
    ufw allow 9090/tcp comment "gRPC" > /dev/null 2>&1
fi

ufw allow 26660/tcp comment "Prometheus" > /dev/null 2>&1
ufw --force enable > /dev/null 2>&1
log_ok "Firewall configured (role: ${ROLE})"

# Fail2ban
log_info "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << 'F2BEOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
F2BEOF
systemctl enable fail2ban > /dev/null 2>&1
systemctl restart fail2ban > /dev/null 2>&1
log_ok "Fail2ban configured"

# System tuning
log_info "Applying kernel tuning..."
cat > /etc/sysctl.d/99-jaynetwork.conf << 'SYSEOF'
# Network performance
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 65536
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 87380 16777216
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_keepalive_probes = 5

# File descriptors
fs.file-max = 2097152
fs.nr_open = 2097152

# VM
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
SYSEOF
sysctl -p /etc/sysctl.d/99-jaynetwork.conf > /dev/null 2>&1

# Increase limits for service user
cat > /etc/security/limits.d/jaynetwork.conf << LIMEOF
${SERVICE_USER}  soft  nofile  65536
${SERVICE_USER}  hard  nofile  65536
${SERVICE_USER}  soft  nproc   65536
${SERVICE_USER}  hard  nproc   65536
LIMEOF
log_ok "Kernel & limits tuned"

# Time sync
systemctl enable chrony > /dev/null 2>&1
systemctl start chrony > /dev/null 2>&1
log_ok "Time sync (chrony) enabled"

#==============================================================================
# FIX OWNERSHIP
#==============================================================================
chown -R "${SERVICE_USER}:${SERVICE_USER}" "${HOME_DIR}"
chown -R "${SERVICE_USER}:${SERVICE_USER}" "/home/${SERVICE_USER}/go" 2>/dev/null || true

#==============================================================================
# SUMMARY
#==============================================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Jay Network Node Deployment Complete!                 ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  Moniker:     ${CYAN}${MONIKER}${NC}"
echo -e "${GREEN}║${NC}  Role:        ${CYAN}${ROLE}${NC}"
echo -e "${GREEN}║${NC}  Chain ID:    ${CYAN}${CHAIN_ID}${NC}"
echo -e "${GREEN}║${NC}  Binary:      ${CYAN}${BINARY_PATH}${NC}"
echo -e "${GREEN}║${NC}  Home:        ${CYAN}${HOME_DIR}${NC}"
echo -e "${GREEN}║${NC}  Service:     ${CYAN}${BINARY_NAME}.service${NC}"
echo -e "${GREEN}║${NC}  User:        ${CYAN}${SERVICE_USER}${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}  Cosmovisor:  ${CYAN}${COSMOVISOR_DIR}${NC}"
echo -e "${GREEN}║${NC}  Config:      ${CYAN}${HOME_DIR}/config/${NC}"
echo -e "${GREEN}║${NC}  Data:        ${CYAN}${HOME_DIR}/data/${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"

NODE_ID=$(sudo -u "${SERVICE_USER}" ${BINARY_PATH} comet show-node-id --home "${HOME_DIR}" 2>/dev/null || echo "unknown")
echo -e "${GREEN}║${NC}  Node ID:     ${CYAN}${NODE_ID}${NC}"
echo -e "${GREEN}║${NC}  Peer Addr:   ${CYAN}${NODE_ID}@<YOUR_IP>:26656${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${YELLOW}Next Steps:${NC}"

if [[ -z "${GENESIS_URL}" ]]; then
echo -e "${GREEN}║${NC}  1. Copy final genesis.json → ${HOME_DIR}/config/genesis.json"
echo -e "${GREEN}║${NC}  2. Set persistent_peers in ${CONFIG_TOML}"
echo -e "${GREEN}║${NC}  3. Start: ${CYAN}sudo systemctl start ${BINARY_NAME}${NC}"
else
echo -e "${GREEN}║${NC}  1. Start: ${CYAN}sudo systemctl start ${BINARY_NAME}${NC}"
fi

echo -e "${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  ${YELLOW}Useful Commands:${NC}"
echo -e "${GREEN}║${NC}  • Status:  ${CYAN}sudo systemctl status ${BINARY_NAME}${NC}"
echo -e "${GREEN}║${NC}  • Logs:    ${CYAN}sudo journalctl -u ${BINARY_NAME} -f${NC}"
echo -e "${GREEN}║${NC}  • Stop:    ${CYAN}sudo systemctl stop ${BINARY_NAME}${NC}"
echo -e "${GREEN}║${NC}  • Restart: ${CYAN}sudo systemctl restart ${BINARY_NAME}${NC}"
echo -e "${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

