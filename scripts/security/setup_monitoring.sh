#!/usr/bin/env bash
set -euo pipefail
###############################################################################
#  Jay Network — Monitoring Stack (Prometheus + Grafana)
#  Runs on the sentry/monitoring node (node4)
#  Usage: sudo bash setup_monitoring.sh --targets "IP1,IP2,IP3,IP4,IP5"
###############################################################################

TARGETS=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --targets) TARGETS="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo "=== [1/4] Install Prometheus ==="
PROM_VER="2.53.0"
if [ ! -f /usr/local/bin/prometheus ]; then
    cd /tmp
    wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROM_VER}/prometheus-${PROM_VER}.linux-amd64.tar.gz" 2>/dev/null || {
        # Fallback to slightly older version
        PROM_VER="2.51.0"
        wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROM_VER}/prometheus-${PROM_VER}.linux-amd64.tar.gz" 2>/dev/null
    }
    tar xzf "prometheus-${PROM_VER}.linux-amd64.tar.gz"
    cp "prometheus-${PROM_VER}.linux-amd64/prometheus" /usr/local/bin/
    cp "prometheus-${PROM_VER}.linux-amd64/promtool" /usr/local/bin/
    rm -rf prometheus-*
fi
echo "[OK] Prometheus ${PROM_VER} installed"

echo "=== [2/4] Configure Prometheus ==="
useradd --system --no-create-home prometheus 2>/dev/null || true
mkdir -p /etc/prometheus /var/lib/prometheus
chown prometheus:prometheus /var/lib/prometheus

# Build scrape targets from comma-separated IPs
IFS=',' read -ra TARGET_IPS <<< "${TARGETS}"
SCRAPE_CONFIGS=""

# Node exporter targets
NE_TARGETS=""
for ip in "${TARGET_IPS[@]}"; do
    ip=$(echo "$ip" | xargs)  # trim whitespace
    if [ -n "${NE_TARGETS}" ]; then
        NE_TARGETS="${NE_TARGETS}, '${ip}:9100'"
    else
        NE_TARGETS="'${ip}:9100'"
    fi
done

# CometBFT metrics targets
CB_TARGETS=""
for ip in "${TARGET_IPS[@]}"; do
    ip=$(echo "$ip" | xargs)
    if [ -n "${CB_TARGETS}" ]; then
        CB_TARGETS="${CB_TARGETS}, '${ip}:26660'"
    else
        CB_TARGETS="'${ip}:26660'"
    fi
done

cat > /etc/prometheus/prometheus.yml << PROMEOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: [${NE_TARGETS}]

  - job_name: 'cometbft'
    static_configs:
      - targets: [${CB_TARGETS}]
    metrics_path: /metrics

  - job_name: 'jaynd_app'
    static_configs:
      - targets: ['localhost:26660']
    metrics_path: /metrics

# Alerting rules (basic)
rule_files:
  - "alerts.yml"
PROMEOF

# Basic alert rules
cat > /etc/prometheus/alerts.yml << 'ALERTEOF'
groups:
  - name: jaynetwork
    rules:
      - alert: NodeDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ $labels.instance }} is down"

      - alert: HighCPU
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
        for: 5m
        labels:
          severity: warning

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Disk space < 15% on {{ $labels.instance }}"

      - alert: MissedBlocks
        expr: increase(cometbft_consensus_validators_power{status="missing"}[5m]) > 0
        for: 2m
        labels:
          severity: critical
ALERTEOF

chown -R prometheus:prometheus /etc/prometheus

cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus Monitoring
After=network.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus \
    --storage.tsdb.retention.time=24h \
    --storage.tsdb.retention.size=500MB \
    --web.listen-address=:9090 \
    --web.enable-lifecycle
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable prometheus > /dev/null 2>&1
systemctl restart prometheus
echo "[OK] Prometheus running on :9090 (retention: 24h / 500MB)"

echo "=== [3/4] Install Grafana ==="
if ! command -v grafana-server &>/dev/null; then
    apt-get install -y -qq apt-transport-https software-properties-common > /dev/null 2>&1
    mkdir -p /etc/apt/keyrings/
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor > /etc/apt/keyrings/grafana.gpg 2>/dev/null || true
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list
    apt-get update -qq 2>/dev/null
    apt-get install -y -qq grafana > /dev/null 2>&1 || {
        echo "[WARN] Grafana install from repo failed. Trying direct download..."
        GRAFANA_VER="11.1.0"
        wget -q "https://dl.grafana.com/oss/release/grafana_${GRAFANA_VER}_amd64.deb" -O /tmp/grafana.deb 2>/dev/null
        dpkg -i /tmp/grafana.deb 2>/dev/null || apt-get install -f -y -qq > /dev/null 2>&1
        rm -f /tmp/grafana.deb
    }
fi

# Configure Grafana - minimal disk usage
mkdir -p /etc/grafana
if [ -f /etc/grafana/grafana.ini ]; then
    sed -i 's/;http_port = 3000/http_port = 3000/' /etc/grafana/grafana.ini
fi

systemctl daemon-reload
systemctl enable grafana-server > /dev/null 2>&1
systemctl start grafana-server 2>/dev/null || true
echo "[OK] Grafana running on :3000 (admin/admin)"

echo "=== [4/4] Add Prometheus datasource to Grafana ==="
sleep 5
# Auto-provision Prometheus datasource
mkdir -p /etc/grafana/provisioning/datasources
cat > /etc/grafana/provisioning/datasources/prometheus.yaml << 'DSEOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
DSEOF

# Auto-provision Cosmos node dashboard
mkdir -p /etc/grafana/provisioning/dashboards
cat > /etc/grafana/provisioning/dashboards/default.yaml << 'DBEOF'
apiVersion: 1
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    options:
      path: /var/lib/grafana/dashboards
DBEOF

mkdir -p /var/lib/grafana/dashboards
cat > /var/lib/grafana/dashboards/jaynet-overview.json << 'DJEOF'
{
  "annotations": { "list": [] },
  "title": "Jay Network Overview",
  "uid": "jaynet-overview",
  "panels": [
    {
      "title": "Block Height",
      "type": "stat",
      "gridPos": { "h": 4, "w": 6, "x": 0, "y": 0 },
      "targets": [{ "expr": "cometbft_consensus_latest_block_height", "legendFormat": "{{instance}}" }],
      "datasource": "Prometheus"
    },
    {
      "title": "Connected Peers",
      "type": "stat",
      "gridPos": { "h": 4, "w": 6, "x": 6, "y": 0 },
      "targets": [{ "expr": "cometbft_p2p_peers", "legendFormat": "{{instance}}" }],
      "datasource": "Prometheus"
    },
    {
      "title": "CPU Usage %",
      "type": "timeseries",
      "gridPos": { "h": 8, "w": 12, "x": 0, "y": 4 },
      "targets": [{ "expr": "100 - (avg by(instance)(rate(node_cpu_seconds_total{mode='idle'}[5m])) * 100)", "legendFormat": "{{instance}}" }],
      "datasource": "Prometheus"
    },
    {
      "title": "Disk Usage %",
      "type": "gauge",
      "gridPos": { "h": 8, "w": 12, "x": 12, "y": 4 },
      "targets": [{ "expr": "100 - ((node_filesystem_avail_bytes{mountpoint='/'} / node_filesystem_size_bytes{mountpoint='/'}) * 100)", "legendFormat": "{{instance}}" }],
      "datasource": "Prometheus"
    },
    {
      "title": "Memory Usage",
      "type": "timeseries",
      "gridPos": { "h": 8, "w": 12, "x": 0, "y": 12 },
      "targets": [{ "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100", "legendFormat": "{{instance}}" }],
      "datasource": "Prometheus"
    }
  ],
  "time": { "from": "now-1h", "to": "now" },
  "refresh": "10s",
  "schemaVersion": 38
}
DJEOF

chown -R grafana:grafana /var/lib/grafana/dashboards /etc/grafana/provisioning
systemctl restart grafana-server 2>/dev/null || true

echo ""
echo "========================================="
echo "  Monitoring stack deployed"
echo "  Prometheus: http://localhost:9090"
echo "  Grafana:    http://localhost:3000"
echo "              (admin / admin)"
echo "========================================="

