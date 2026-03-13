#!/usr/bin/env bash
set -uo pipefail
###############################################################################
#  Jay Network — Base Security Hardening (ALL nodes)
#  Usage: sudo bash harden_node.sh --role <validator|sentry|archive> [--signer-ip <IP>]
###############################################################################

ROLE="validator"
SIGNER_IP=""
SERVICE_USER="jaynet"
BINARY="jaynd"
HOME_DIR="/home/${SERVICE_USER}/.jayn"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --role)       ROLE="$2"; shift 2 ;;
        --signer-ip)  SIGNER_IP="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo "=== [1/10] SSH Hardening ==="
# Backup first
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%s)

sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
sed -i 's/^#\?AllowAgentForwarding.*/AllowAgentForwarding no/' /etc/ssh/sshd_config
sed -i 's/^#\?AllowTcpForwarding.*/AllowTcpForwarding no/' /etc/ssh/sshd_config

# Remove duplicate ClientAlive entries and add fresh
sed -i '/^ClientAliveInterval/d' /etc/ssh/sshd_config
sed -i '/^ClientAliveCountMax/d' /etc/ssh/sshd_config
echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config
echo "ClientAliveCountMax 2" >> /etc/ssh/sshd_config

# Protocol hardening
sed -i '/^Protocol/d' /etc/ssh/sshd_config
echo "Protocol 2" >> /etc/ssh/sshd_config

systemctl restart sshd
echo "[OK] SSH hardened"

echo "=== [2/10] Firewall Hardening ==="
ufw --force reset > /dev/null 2>&1
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1

# SSH — always
ufw allow 22/tcp comment "SSH" > /dev/null 2>&1
# P2P — always
ufw allow 26656/tcp comment "CometBFT-P2P" > /dev/null 2>&1
# Prometheus node_exporter — internal
ufw allow 9100/tcp comment "node_exporter" > /dev/null 2>&1
# CometBFT prometheus — internal
ufw allow 26660/tcp comment "CometBFT-Prometheus" > /dev/null 2>&1

if [[ "${ROLE}" == "validator" ]]; then
    # Validators: NO public RPC/REST/gRPC
    # Only TMKMS from signer
    if [[ -n "${SIGNER_IP}" ]]; then
        ufw allow from "${SIGNER_IP}" to any port 26659 proto tcp comment "TMKMS-signer" > /dev/null 2>&1
    fi
elif [[ "${ROLE}" == "sentry" || "${ROLE}" == "archive" ]]; then
    # Public nodes: HTTPS reverse proxy ports only
    ufw allow 443/tcp comment "HTTPS-RPC" > /dev/null 2>&1
    ufw allow 1443/tcp comment "HTTPS-REST" > /dev/null 2>&1
    ufw allow 9443/tcp comment "gRPC-TLS" > /dev/null 2>&1
    # Monitoring ports for sentry
    ufw allow 3000/tcp comment "Grafana" > /dev/null 2>&1
fi

ufw --force enable > /dev/null 2>&1
echo "[OK] Firewall configured (role=${ROLE})"

echo "=== [3/10] Enhanced Fail2ban ==="
apt-get install -y -qq fail2ban > /dev/null 2>&1 || true
mkdir -p /etc/fail2ban
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 86400
findtime = 600
maxretry = 3
banaction = ufw

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 86400
EOF
systemctl enable fail2ban > /dev/null 2>&1
systemctl restart fail2ban > /dev/null 2>&1
echo "[OK] Fail2ban hardened (ban=24h, max=3)"

echo "=== [4/10] Journald Log Limits ==="
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/size-limit.conf << 'EOF'
[Journal]
SystemMaxUse=100M
SystemKeepFree=500M
MaxRetentionSec=7day
ForwardToSyslog=no
Compress=yes
EOF
systemctl restart systemd-journald
echo "[OK] Journald limited to 100MB / 7 days"

echo "=== [5/10] Disk Cleanup Cron ==="
cat > /etc/cron.daily/jaynet-cleanup << 'CRON'
#!/bin/bash
journalctl --vacuum-size=50M 2>/dev/null
apt-get clean 2>/dev/null
find /tmp -mtime +3 -delete 2>/dev/null
find /var/log -name "*.gz" -mtime +7 -delete 2>/dev/null
CRON
chmod +x /etc/cron.daily/jaynet-cleanup
echo "[OK] Daily disk cleanup cron"

echo "=== [6/10] Key Backup Cron ==="
BACKUP_DIR="/home/${SERVICE_USER}/backups"
mkdir -p "${BACKUP_DIR}"
chown "${SERVICE_USER}:${SERVICE_USER}" "${BACKUP_DIR}"
chmod 700 "${BACKUP_DIR}"

cat > /etc/cron.daily/jaynet-backup << BAKCRON
#!/bin/bash
BDIR="${BACKUP_DIR}"
DT=\$(date +%Y%m%d)
mkdir -p \${BDIR}

# Keyring backup
if [ -d "${HOME_DIR}/keyring-file" ]; then
    tar czf \${BDIR}/keyring-\${DT}.tar.gz -C ${HOME_DIR} keyring-file/ 2>/dev/null
    chmod 600 \${BDIR}/keyring-\${DT}.tar.gz
fi

# Validator key backup
if [ -f "${HOME_DIR}/config/priv_validator_key.json" ]; then
    cp ${HOME_DIR}/config/priv_validator_key.json \${BDIR}/priv_validator_key-\${DT}.json
    chmod 600 \${BDIR}/priv_validator_key-\${DT}.json
fi

# Node key backup
if [ -f "${HOME_DIR}/config/node_key.json" ]; then
    cp ${HOME_DIR}/config/node_key.json \${BDIR}/node_key-\${DT}.json
    chmod 600 \${BDIR}/node_key-\${DT}.json
fi

# Keep only 7 days
find \${BDIR} -mtime +7 -delete 2>/dev/null
chown -R ${SERVICE_USER}:${SERVICE_USER} \${BDIR}
BAKCRON
chmod +x /etc/cron.daily/jaynet-backup
echo "[OK] Daily key backup cron"

echo "=== [7/10] node_exporter ==="
if ! command -v node_exporter &>/dev/null && [ ! -f /usr/local/bin/node_exporter ]; then
    cd /tmp
    wget -q https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz 2>/dev/null || true
    if [ -f node_exporter-1.8.2.linux-amd64.tar.gz ]; then
        tar xzf node_exporter-1.8.2.linux-amd64.tar.gz
        cp node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
        rm -rf node_exporter-*
    fi
fi

if [ -f /usr/local/bin/node_exporter ]; then
    cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=nobody
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9100
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable node_exporter > /dev/null 2>&1
    systemctl restart node_exporter
    echo "[OK] node_exporter running on :9100"
else
    echo "[WARN] node_exporter download failed, skipping"
fi

echo "=== [8/10] Automatic Security Updates ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unattended-upgrades > /dev/null 2>&1
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
echo "[OK] Unattended security updates enabled"

echo "=== [9/10] File Permissions ==="
chmod 700 "${HOME_DIR}"
chmod 600 "${HOME_DIR}/config/node_key.json" 2>/dev/null || true
chmod 600 "${HOME_DIR}/config/priv_validator_key.json" 2>/dev/null || true
chmod 600 "${HOME_DIR}/config/config.toml" 2>/dev/null || true
chmod 600 "${HOME_DIR}/config/app.toml" 2>/dev/null || true
chmod 600 "${HOME_DIR}/config/client.toml" 2>/dev/null || true
chown -R "${SERVICE_USER}:${SERVICE_USER}" "${HOME_DIR}"
echo "[OK] Strict file permissions set (600/700)"

echo "=== [10/10] RPC Binding & Pruning ==="
CONFIG="${HOME_DIR}/config/config.toml"
APP="${HOME_DIR}/config/app.toml"

if [[ "${ROLE}" == "validator" ]]; then
    # Validator: RPC localhost only
    sed -i 's|laddr = "tcp://0.0.0.0:26657"|laddr = "tcp://127.0.0.1:26657"|' "${CONFIG}"
    sed -i 's|laddr = "tcp://[^"]*:26657"|laddr = "tcp://127.0.0.1:26657"|' "${CONFIG}"
    # Enable TMKMS remote signer port
    if [[ -n "${SIGNER_IP}" ]]; then
        sed -i 's|priv_validator_laddr = ""|priv_validator_laddr = "tcp://0.0.0.0:26659"|' "${CONFIG}"
    fi
    # Aggressive pruning for validators
    sed -i 's|pruning = ".*"|pruning = "custom"|' "${APP}"
    sed -i 's|pruning-keep-recent = ".*"|pruning-keep-recent = "100"|' "${APP}"
    sed -i 's|pruning-interval = ".*"|pruning-interval = "17"|' "${APP}"
elif [[ "${ROLE}" == "sentry" ]]; then
    # Sentry: RPC localhost only (nginx handles public)
    sed -i 's|laddr = "tcp://0.0.0.0:26657"|laddr = "tcp://127.0.0.1:26657"|' "${CONFIG}"
    # Moderate pruning
    sed -i 's|pruning = ".*"|pruning = "custom"|' "${APP}"
    sed -i 's|pruning-keep-recent = ".*"|pruning-keep-recent = "200"|' "${APP}"
    sed -i 's|pruning-interval = ".*"|pruning-interval = "19"|' "${APP}"
elif [[ "${ROLE}" == "archive" ]]; then
    # Archive: RPC localhost only (nginx handles public)
    sed -i 's|laddr = "tcp://0.0.0.0:26657"|laddr = "tcp://127.0.0.1:26657"|' "${CONFIG}"
    # Custom pruning (not "nothing" to save disk)
    sed -i 's|pruning = ".*"|pruning = "custom"|' "${APP}"
    sed -i 's|pruning-keep-recent = ".*"|pruning-keep-recent = "500"|' "${APP}"
    sed -i 's|pruning-interval = ".*"|pruning-interval = "19"|' "${APP}"
fi

# REST/gRPC bind to localhost
sed -i 's|address = "0.0.0.0:1317"|address = "127.0.0.1:1317"|' "${APP}"
sed -i 's|address = "localhost:1317"|address = "127.0.0.1:1317"|' "${APP}"
sed -i 's|address = "0.0.0.0:9090"|address = "127.0.0.1:9090"|' "${APP}"
sed -i 's|address = "localhost:9090"|address = "127.0.0.1:9090"|' "${APP}"

# Keyring backend to file
CLIENT="${HOME_DIR}/config/client.toml"
sed -i 's|keyring-backend = "test"|keyring-backend = "file"|' "${CLIENT}" 2>/dev/null || true
sed -i 's|keyring-backend = "os"|keyring-backend = "file"|' "${CLIENT}" 2>/dev/null || true

chown -R "${SERVICE_USER}:${SERVICE_USER}" "${HOME_DIR}"
echo "[OK] RPC bound to localhost, pruning optimized"

echo ""
echo "========================================="
echo "  Base hardening complete (role=${ROLE})"
echo "========================================="

