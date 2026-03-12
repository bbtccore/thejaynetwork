#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Cosmovisor Setup Script for Jay Network (thejaynetwork)
#
# This script installs and configures Cosmovisor for automatic binary upgrades.
#
# Prerequisites:
#   - Go >= 1.22 installed
#   - jaynd binary built and accessible
#
# Usage:
#   chmod +x setup_cosmovisor.sh
#   ./setup_cosmovisor.sh
###############################################################################

CHAIN_BINARY="jaynd"
CHAIN_HOME="${HOME}/.jayn"
COSMOVISOR_HOME="${CHAIN_HOME}/cosmovisor"

echo "=== Jay Network Cosmovisor Setup ==="

# Step 1: Install cosmovisor
echo "[1/5] Installing cosmovisor..."
go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@latest

# Step 2: Create directory structure
echo "[2/5] Creating cosmovisor directory structure..."
mkdir -p "${COSMOVISOR_HOME}/genesis/bin"
mkdir -p "${COSMOVISOR_HOME}/upgrades"

# Step 3: Copy current binary to genesis
echo "[3/5] Copying jaynd binary to cosmovisor genesis..."
BINARY_PATH=$(which ${CHAIN_BINARY} 2>/dev/null || echo "")
if [ -z "${BINARY_PATH}" ]; then
    # Try build directory
    if [ -f "./build/${CHAIN_BINARY}" ]; then
        BINARY_PATH="./build/${CHAIN_BINARY}"
    else
        echo "ERROR: ${CHAIN_BINARY} binary not found. Build it first with 'make build'"
        exit 1
    fi
fi

cp "${BINARY_PATH}" "${COSMOVISOR_HOME}/genesis/bin/${CHAIN_BINARY}"
chmod +x "${COSMOVISOR_HOME}/genesis/bin/${CHAIN_BINARY}"

# Step 4: Create symbolic link
echo "[4/5] Creating cosmovisor current symlink..."
ln -sf "${COSMOVISOR_HOME}/genesis" "${COSMOVISOR_HOME}/current"

# Step 5: Set environment variables
echo "[5/5] Environment variables for cosmovisor:"
cat << 'ENVEOF'

Add these to your ~/.bashrc or ~/.profile:

export DAEMON_NAME=jaynd
export DAEMON_HOME=$HOME/.jayn
export DAEMON_ALLOW_DOWNLOAD_BINARIES=true
export DAEMON_RESTART_AFTER_UPGRADE=true
export DAEMON_LOG_BUFFER_SIZE=512
export UNSAFE_SKIP_BACKUP=false

ENVEOF

echo ""
echo "=== Cosmovisor setup complete ==="
echo ""
echo "Directory structure:"
echo "  ${COSMOVISOR_HOME}/"
echo "  ├── genesis/"
echo "  │   └── bin/"
echo "  │       └── jaynd"
echo "  ├── upgrades/     (future upgrades go here)"
echo "  └── current -> genesis"
echo ""
echo "To start the node with cosmovisor:"
echo "  cosmovisor run start --home ${CHAIN_HOME}"
echo ""
echo "To prepare an upgrade (e.g., v2.0.0):"
echo "  mkdir -p ${COSMOVISOR_HOME}/upgrades/v2.0.0/bin"
echo "  cp /path/to/new/jaynd ${COSMOVISOR_HOME}/upgrades/v2.0.0/bin/jaynd"

