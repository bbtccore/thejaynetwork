#!/usr/bin/env bash
set -uo pipefail
###############################################################################
#  Jay Network — TMKMS Remote Signer Setup
#  Runs on the signer node (or any dedicated signing host)
#  Usage: sudo bash setup_tmkms.sh \
#           --chain-id thejaynetwork-1 \
#           --val1-ip IP --val1-key /path/to/key1.json \
#           --val2-ip IP --val2-key /path/to/key2.json \
#           --val3-ip IP --val3-key /path/to/key3.json \
#           --tmkms-bin /path/to/tmkms
###############################################################################

CHAIN_ID="thejaynetwork-1"
VAL1_IP="" ; VAL1_KEY=""
VAL2_IP="" ; VAL2_KEY=""
VAL3_IP="" ; VAL3_KEY=""
TMKMS_BIN=""
SERVICE_USER="jaynet"
TMKMS_HOME="/home/${SERVICE_USER}/.tmkms"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --chain-id)  CHAIN_ID="$2"; shift 2 ;;
        --val1-ip)   VAL1_IP="$2"; shift 2 ;;
        --val1-key)  VAL1_KEY="$2"; shift 2 ;;
        --val2-ip)   VAL2_IP="$2"; shift 2 ;;
        --val2-key)  VAL2_KEY="$2"; shift 2 ;;
        --val3-ip)   VAL3_IP="$2"; shift 2 ;;
        --val3-key)  VAL3_KEY="$2"; shift 2 ;;
        --tmkms-bin) TMKMS_BIN="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo "=== TMKMS Setup for Jay Network ==="

# Install TMKMS binary
if [[ -n "${TMKMS_BIN}" ]] && [[ -f "${TMKMS_BIN}" ]]; then
    if [[ "${TMKMS_BIN}" != "/usr/local/bin/tmkms" ]]; then
        cp "${TMKMS_BIN}" /usr/local/bin/tmkms
    fi
    chmod +x /usr/local/bin/tmkms
    echo "[OK] TMKMS binary installed"
elif command -v tmkms &>/dev/null; then
    echo "[OK] TMKMS already available"
else
    echo "[INFO] Compiling TMKMS from source (this takes ~10 min)..."
    apt-get install -y -qq build-essential pkg-config libusb-1.0-0-dev > /dev/null 2>&1
    if ! command -v cargo &>/dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>/dev/null
        source "$HOME/.cargo/env"
    fi
    cargo install tmkms --features=softsign 2>&1 | tail -5
    cp "$HOME/.cargo/bin/tmkms" /usr/local/bin/tmkms
    echo "[OK] TMKMS compiled and installed"
fi

# Create TMKMS user & dirs
if ! id "${SERVICE_USER}" &>/dev/null; then
    useradd -m -s /bin/bash "${SERVICE_USER}"
fi

setup_validator_signer() {
    local NUM="$1"
    local VAL_IP="$2"
    local VAL_KEY="$3"
    local INSTANCE_DIR="${TMKMS_HOME}/val${NUM}"

    echo "[INFO] Setting up TMKMS for validator ${NUM} (${VAL_IP})..."

    mkdir -p "${INSTANCE_DIR}/secrets" "${INSTANCE_DIR}/state"

    # Copy validator key
    cp "${VAL_KEY}" "${INSTANCE_DIR}/secrets/priv_validator_key.json"
    chmod 600 "${INSTANCE_DIR}/secrets/priv_validator_key.json"

    # Initialize softsign key from the priv_validator_key
    # TMKMS uses its own key format - import from the Cosmos key
    if [ ! -f "${INSTANCE_DIR}/secrets/consensus-key.json" ]; then
        # Use the priv_validator_key directly for softsign
        cp "${VAL_KEY}" "${INSTANCE_DIR}/secrets/consensus-key.json"
        chmod 600 "${INSTANCE_DIR}/secrets/consensus-key.json"
    fi

    # Generate connection identity key
    if [ ! -f "${INSTANCE_DIR}/secrets/connection.key" ]; then
        sudo -u "${SERVICE_USER}" tmkms softsign keygen "${INSTANCE_DIR}/secrets/connection.key" 2>/dev/null || {
            # Generate manually if tmkms command fails
            openssl rand -out "${INSTANCE_DIR}/secrets/connection.key" 64
        }
        chmod 600 "${INSTANCE_DIR}/secrets/connection.key"
    fi

    # Initialize state file
    if [ ! -f "${INSTANCE_DIR}/state/priv_validator_state.json" ]; then
        echo '{"height":"0","round":0,"step":0}' > "${INSTANCE_DIR}/state/priv_validator_state.json"
    fi

    # Create TMKMS config
    cat > "${INSTANCE_DIR}/tmkms.toml" << TMKEOF
[[chain]]
id = "${CHAIN_ID}"

[[validator]]
chain_id = "${CHAIN_ID}"
addr = "tcp://${VAL_IP}:26659"
secret_key = "${INSTANCE_DIR}/secrets/connection.key"
protocol_version = "v0.34"
reconnect = true

[[providers.softsign]]
chain_ids = ["${CHAIN_ID}"]
key_type = "consensus"
path = "${INSTANCE_DIR}/secrets/priv_validator_key.json"
TMKEOF

    # Create systemd service
    cat > "/etc/systemd/system/tmkms-val${NUM}.service" << SVCEOF
[Unit]
Description=TMKMS Signer for Validator ${NUM}
After=network-online.target
Wants=network-online.target

[Service]
User=${SERVICE_USER}
ExecStart=/usr/local/bin/tmkms start -c ${INSTANCE_DIR}/tmkms.toml
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SVCEOF

    chown -R "${SERVICE_USER}:${SERVICE_USER}" "${INSTANCE_DIR}"
    echo "[OK] TMKMS val${NUM} configured → ${VAL_IP}:26659"
}

# Setup for each validator
if [[ -n "${VAL1_IP}" ]] && [[ -n "${VAL1_KEY}" ]]; then
    setup_validator_signer 1 "${VAL1_IP}" "${VAL1_KEY}"
fi
if [[ -n "${VAL2_IP}" ]] && [[ -n "${VAL2_KEY}" ]]; then
    setup_validator_signer 2 "${VAL2_IP}" "${VAL2_KEY}"
fi
if [[ -n "${VAL3_IP}" ]] && [[ -n "${VAL3_KEY}" ]]; then
    setup_validator_signer 3 "${VAL3_IP}" "${VAL3_KEY}"
fi

# Reload systemd and enable services
systemctl daemon-reload
for i in 1 2 3; do
    if [ -f "/etc/systemd/system/tmkms-val${i}.service" ]; then
        systemctl enable "tmkms-val${i}" > /dev/null 2>&1
        systemctl start "tmkms-val${i}" 2>/dev/null || true
        echo "[OK] tmkms-val${i} service started"
    fi
done

echo ""
echo "========================================="
echo "  TMKMS setup complete"
echo "  Instances: ${TMKMS_HOME}/val{1,2,3}"
echo "  Services:  tmkms-val{1,2,3}.service"
echo "========================================="
echo ""
echo "IMPORTANT: Now remove priv_validator_key.json from each validator node!"
echo "  ssh validator -> sudo rm /home/jaynet/.jayn/config/priv_validator_key.json"

