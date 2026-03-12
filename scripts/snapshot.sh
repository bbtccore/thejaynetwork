#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Jay Network Snapshot Script
#
# Creates a compressed snapshot of the chain data for new node bootstrapping.
# Supports both lz4 (fast) and gzip (smaller) compression.
#
# Usage:
#   ./snapshot.sh [OPTIONS]
#
# Options:
#   --output-dir   Output directory (default: ./snapshots)
#   --compress     Compression: lz4 or gzip (default: lz4)
#   --stop-service Stop jaynd before snapshot (default: true)
#   --prune-before Prune data before snapshot (default: false)
###############################################################################

BINARY="jaynd"
HOME_DIR="${HOME}/.jayn"
OUTPUT_DIR="./snapshots"
COMPRESS="lz4"
STOP_SERVICE=true
PRUNE_BEFORE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)    OUTPUT_DIR="$2"; shift 2 ;;
        --compress)      COMPRESS="$2"; shift 2 ;;
        --stop-service)  STOP_SERVICE="$2"; shift 2 ;;
        --prune-before)  PRUNE_BEFORE="$2"; shift 2 ;;
        --home)          HOME_DIR="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--output-dir DIR] [--compress lz4|gzip] [--stop-service true|false]"
            exit 0 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

echo "============================================"
echo "  Jay Network Snapshot"
echo "============================================"
echo "  Home:        ${HOME_DIR}"
echo "  Output:      ${OUTPUT_DIR}"
echo "  Compression: ${COMPRESS}"
echo "============================================"

mkdir -p "${OUTPUT_DIR}"

# Stop service if requested
SERVICE_WAS_RUNNING=false
if [[ "${STOP_SERVICE}" == true ]]; then
    if systemctl is-active --quiet ${BINARY} 2>/dev/null; then
        echo "[1/4] Stopping ${BINARY} service..."
        sudo systemctl stop ${BINARY}
        SERVICE_WAS_RUNNING=true
        sleep 2
    else
        echo "[1/4] Service not running, proceeding..."
    fi
else
    echo "[1/4] Skipping service stop (--stop-service false)"
fi

# Get current block height
echo "[2/4] Getting current block height..."
if [[ -f "${HOME_DIR}/data/priv_validator_state.json" ]]; then
    HEIGHT=$(jq -r '.height' "${HOME_DIR}/data/priv_validator_state.json" 2>/dev/null || echo "unknown")
else
    HEIGHT=$(curl -sf http://localhost:26657/status 2>/dev/null | jq -r '.result.sync_info.latest_block_height' || echo "unknown")
fi
echo "  Block height: ${HEIGHT}"

# Optional pruning
if [[ "${PRUNE_BEFORE}" == true ]]; then
    echo "[2.5/4] Pruning before snapshot..."
    ${BINARY} prune everything --home "${HOME_DIR}" 2>/dev/null || true
fi

# Create snapshot
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "[3/4] Creating snapshot..."
case "${COMPRESS}" in
    lz4)
        SNAPSHOT_FILE="${OUTPUT_DIR}/jay-${HEIGHT}-${TIMESTAMP}.tar.lz4"
        tar cf - -C "${HOME_DIR}" data | lz4 -z -9 - "${SNAPSHOT_FILE}"
        ;;
    gzip|gz)
        SNAPSHOT_FILE="${OUTPUT_DIR}/jay-${HEIGHT}-${TIMESTAMP}.tar.gz"
        tar czf "${SNAPSHOT_FILE}" -C "${HOME_DIR}" data
        ;;
    *)
        echo "ERROR: Unknown compression: ${COMPRESS}. Use 'lz4' or 'gzip'."
        exit 1
        ;;
esac

# Generate checksum
echo "[4/4] Generating checksum..."
sha256sum "${SNAPSHOT_FILE}" > "${SNAPSHOT_FILE}.sha256"

# Restart service
if [[ "${SERVICE_WAS_RUNNING}" == true ]]; then
    echo "Restarting ${BINARY} service..."
    sudo systemctl start ${BINARY}
fi

# Size
SIZE=$(du -sh "${SNAPSHOT_FILE}" | cut -f1)
CHECKSUM=$(cat "${SNAPSHOT_FILE}.sha256" | cut -d' ' -f1)

echo ""
echo "============================================"
echo "  Snapshot Complete!"
echo "============================================"
echo ""
echo "  File:     ${SNAPSHOT_FILE}"
echo "  Size:     ${SIZE}"
echo "  Height:   ${HEIGHT}"
echo "  Checksum: ${CHECKSUM}"
echo ""
echo "To restore on a new node:"
echo "  1. Initialize node: jaynd init <moniker> --chain-id thejaynetwork-1"
echo "  2. Copy genesis.json"
case "${COMPRESS}" in
    lz4)
echo "  3. lz4 -d ${SNAPSHOT_FILE} | tar xf - -C \${HOME}/.jayn"
        ;;
    gzip|gz)
echo "  3. tar xzf ${SNAPSHOT_FILE} -C \${HOME}/.jayn"
        ;;
esac
echo "  4. Start: jaynd start"
echo ""

# Cleanup old snapshots (keep last 3)
echo "Cleaning up old snapshots..."
ls -t "${OUTPUT_DIR}"/jay-*.tar.* 2>/dev/null | grep -v '.sha256' | tail -n +4 | while read old; do
    echo "  Removing: $(basename ${old})"
    rm -f "${old}" "${old}.sha256"
done
echo "Done."
