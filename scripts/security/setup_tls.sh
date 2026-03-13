#!/usr/bin/env bash
set -euo pipefail
###############################################################################
#  Jay Network — TLS Reverse Proxy (nginx) for Sentry / Archive nodes
#  Usage: sudo bash setup_tls.sh [--domain <domain>]
#  Exposes:
#    443   → RPC (HTTPS)    → 127.0.0.1:26657
#    1443  → REST (HTTPS)   → 127.0.0.1:1317
#    9443  → gRPC (TLS)     → 127.0.0.1:9090
#  Includes rate limiting & security headers
###############################################################################

DOMAIN="${1:-jaynetwork.local}"
CERT_DIR="/etc/nginx/ssl"
SERVICE_USER="jaynet"

echo "=== [1/5] Install nginx ==="
apt-get update -qq
apt-get install -y -qq nginx openssl > /dev/null 2>&1
echo "[OK] nginx installed"

echo "=== [2/5] Generate TLS Certificate ==="
mkdir -p "${CERT_DIR}"
if [ ! -f "${CERT_DIR}/jaynet.crt" ]; then
    openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
        -keyout "${CERT_DIR}/jaynet.key" \
        -out "${CERT_DIR}/jaynet.crt" \
        -subj "/C=KR/ST=Seoul/L=Seoul/O=JayNetwork/CN=${DOMAIN}" \
        -addext "subjectAltName=DNS:${DOMAIN},DNS:*.${DOMAIN},IP:$(hostname -I | awk '{print $1}')" \
        2>/dev/null
    chmod 600 "${CERT_DIR}/jaynet.key"
    echo "[OK] Self-signed TLS cert generated (10 years, RSA-4096)"
else
    echo "[OK] TLS cert already exists"
fi

echo "=== [3/5] Configure nginx ==="
# Remove default site
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

cat > /etc/nginx/conf.d/jaynet-rpc.conf << 'NGXEOF'
# Rate limiting zones
limit_req_zone $binary_remote_addr zone=rpc_limit:10m rate=30r/s;
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=20r/s;
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

# === HTTPS RPC (port 443) → 127.0.0.1:26657 ===
server {
    listen 443 ssl http2;
    server_name _;

    ssl_certificate /etc/nginx/ssl/jaynet.crt;
    ssl_certificate_key /etc/nginx/ssl/jaynet.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Rate limiting
    limit_req zone=rpc_limit burst=50 nodelay;
    limit_conn conn_limit 20;
    limit_req_status 429;

    # Request size limit
    client_max_body_size 1m;

    location / {
        proxy_pass http://127.0.0.1:26657;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket for /websocket endpoint
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }

    # Block dangerous RPC methods
    location ~* ^/(unsafe|dial_seeds|dial_peers) {
        return 403;
    }
}

# === HTTPS REST API (port 1443) → 127.0.0.1:1317 ===
server {
    listen 1443 ssl http2;
    server_name _;

    ssl_certificate /etc/nginx/ssl/jaynet.crt;
    ssl_certificate_key /etc/nginx/ssl/jaynet.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;

    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Content-Type-Options "nosniff" always;

    limit_req zone=api_limit burst=30 nodelay;
    limit_conn conn_limit 15;
    limit_req_status 429;
    client_max_body_size 1m;

    location / {
        proxy_pass http://127.0.0.1:1317;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGXEOF

# gRPC TLS via stream module (port 9443 → 127.0.0.1:9090)
cat > /etc/nginx/modules-enabled/99-jaynet-grpc.conf << 'GRPCEOF'
stream {
    upstream grpc_backend {
        server 127.0.0.1:9090;
    }
    server {
        listen 9443 ssl;
        ssl_certificate /etc/nginx/ssl/jaynet.crt;
        ssl_certificate_key /etc/nginx/ssl/jaynet.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        proxy_pass grpc_backend;
    }
}
GRPCEOF

echo "[OK] nginx configured (RPC:443, REST:1443, gRPC:9443)"

echo "=== [4/5] Test & Start nginx ==="
# Check if stream module is available, if not use a workaround
if ! nginx -t 2>&1 | grep -q "test is successful"; then
    echo "[WARN] nginx stream module may not be loaded. Adding to main config..."
    # Remove the stream file if it causes issues
    rm -f /etc/nginx/modules-enabled/99-jaynet-grpc.conf

    # Add stream to main nginx.conf if not present
    if ! grep -q "stream" /etc/nginx/nginx.conf; then
        cat >> /etc/nginx/nginx.conf << 'STEOF'

stream {
    upstream grpc_backend {
        server 127.0.0.1:9090;
    }
    server {
        listen 9443 ssl;
        ssl_certificate /etc/nginx/ssl/jaynet.crt;
        ssl_certificate_key /etc/nginx/ssl/jaynet.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        proxy_pass grpc_backend;
    }
}
STEOF
    fi

    # Test again
    if ! nginx -t 2>&1 | grep -q "test is successful"; then
        echo "[WARN] stream block failed, removing (gRPC TLS disabled)"
        sed -i '/^stream {/,/^}/d' /etc/nginx/nginx.conf
        rm -f /etc/nginx/modules-enabled/99-jaynet-grpc.conf
    fi
fi

nginx -t 2>&1
systemctl enable nginx > /dev/null 2>&1
systemctl restart nginx
echo "[OK] nginx running"

echo "=== [5/5] Verify ==="
echo "  HTTPS RPC:  https://$(hostname -I | awk '{print $1}'):443"
echo "  HTTPS REST: https://$(hostname -I | awk '{print $1}'):1443"
echo "  gRPC TLS:   $(hostname -I | awk '{print $1}'):9443"
echo ""
echo "========================================="
echo "  TLS reverse proxy setup complete"
echo "========================================="

