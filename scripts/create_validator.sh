#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Jay Network - Create Validator Script
#
# Two modes:
#   1. Genesis validator: Creates genesis account + gentx (before network launch)
#   2. Live validator:    Creates validator tx on running network
#
# Usage:
#   Genesis mode:  ./create_validator.sh --genesis
#   Live mode:     ./create_validator.sh --live [--key-name mykey]
###############################################################################

BINARY="jaynd"
CHAIN_ID="thejaynetwork-1"
DENOM="ujay"
HOME_DIR="${HOME}/.jayn"
KEYRING="file"
KEY_NAME="validator"
MODE="genesis"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --genesis)     MODE="genesis"; shift ;;
        --live)        MODE="live"; shift ;;
        --key-name)    KEY_NAME="$2"; shift 2 ;;
        --keyring)     KEYRING="$2"; shift 2 ;;
        --home)        HOME_DIR="$2"; shift 2 ;;
        --chain-id)    CHAIN_ID="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--genesis|--live] [--key-name NAME] [--keyring BACKEND] [--home DIR]"
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "============================================"
echo "  Jay Network Validator Setup"
echo "============================================"
echo "  Mode:      ${MODE}"
echo "  Key:       ${KEY_NAME}"
echo "  Chain ID:  ${CHAIN_ID}"
echo "  Keyring:   ${KEYRING}"
echo "  Home:      ${HOME_DIR}"
echo "============================================"
echo ""

if [[ "${MODE}" == "genesis" ]]; then
    ###########################################################################
    # GENESIS VALIDATOR MODE
    ###########################################################################

    # Step 1: Create validator key
    echo "[1/5] Creating validator key..."
    ${BINARY} keys add "${KEY_NAME}" \
        --keyring-backend "${KEYRING}" \
        --home "${HOME_DIR}"

    # Step 2: Get validator address
    ADDR=$(${BINARY} keys show "${KEY_NAME}" -a \
        --keyring-backend "${KEYRING}" \
        --home "${HOME_DIR}")
    echo ""
    echo "Validator address: ${ADDR}"

    # Step 3: Add genesis account (1 trillion ujay = 1M JAY)
    echo ""
    echo "[2/5] Adding genesis account (1,000,000 JAY)..."
    ${BINARY} genesis add-genesis-account "${ADDR}" "1000000000000${DENOM}" \
        --home "${HOME_DIR}"

    # Step 4: Create gentx (stake 500B ujay = 500K JAY)
    echo "[3/5] Creating gentx (staking 500,000 JAY)..."
    ${BINARY} genesis gentx "${KEY_NAME}" "500000000000${DENOM}" \
        --chain-id "${CHAIN_ID}" \
        --keyring-backend "${KEYRING}" \
        --moniker "$(cat ${HOME_DIR}/config/genesis.json | grep -o '"moniker":"[^"]*"' | head -1 | cut -d'"' -f4 || echo 'validator')" \
        --commission-rate "0.05" \
        --commission-max-rate "0.20" \
        --commission-max-change-rate "0.01" \
        --min-self-delegation "1" \
        --home "${HOME_DIR}"

    # Step 5: Collect gentxs
    echo "[4/5] Collecting gentxs..."
    ${BINARY} genesis collect-gentxs --home "${HOME_DIR}"

    # Step 6: Validate genesis
    echo "[5/5] Validating genesis..."
    ${BINARY} genesis validate --home "${HOME_DIR}"

    echo ""
    echo "============================================"
    echo "  Genesis validator created!"
    echo "============================================"
    echo ""
    echo "  Validator address: ${ADDR}"
    echo "  Genesis file:      ${HOME_DIR}/config/genesis.json"
    echo ""
    echo "  IMPORTANT: Distribute genesis.json to ALL nodes before starting."
    echo ""

elif [[ "${MODE}" == "live" ]]; then
    ###########################################################################
    # LIVE VALIDATOR MODE (join running network)
    ###########################################################################

    # Check if key exists
    if ! ${BINARY} keys show "${KEY_NAME}" -a --keyring-backend "${KEYRING}" --home "${HOME_DIR}" &>/dev/null; then
        echo "[1/3] Creating new key: ${KEY_NAME}..."
        ${BINARY} keys add "${KEY_NAME}" \
            --keyring-backend "${KEYRING}" \
            --home "${HOME_DIR}"
    else
        echo "[1/3] Using existing key: ${KEY_NAME}"
    fi

    ADDR=$(${BINARY} keys show "${KEY_NAME}" -a \
        --keyring-backend "${KEYRING}" \
        --home "${HOME_DIR}")
    echo "  Address: ${ADDR}"

    # Check balance
    echo ""
    echo "[2/3] Checking balance..."
    BALANCE=$(${BINARY} query bank balances "${ADDR}" \
        --home "${HOME_DIR}" \
        --output json 2>/dev/null | jq -r ".balances[] | select(.denom==\"${DENOM}\") | .amount" || echo "0")
    echo "  Balance: ${BALANCE} ${DENOM}"

    if [[ "${BALANCE}" == "0" || -z "${BALANCE}" ]]; then
        echo ""
        echo "  ERROR: Insufficient balance. Send tokens to ${ADDR} first."
        echo "  Minimum required: ~1,000,000 ${DENOM} (1 JAY)"
        exit 1
    fi

    # Get moniker from config
    MONIKER=$(cat "${HOME_DIR}/config/config.toml" | grep '^moniker' | cut -d'"' -f2 || echo "validator")

    # Create validator
    echo ""
    echo "[3/3] Creating validator..."
    STAKE_AMOUNT=$((BALANCE / 2))  # Stake half of balance

    ${BINARY} tx staking create-validator \
        --amount "${STAKE_AMOUNT}${DENOM}" \
        --pubkey $(${BINARY} comet show-validator --home "${HOME_DIR}") \
        --moniker "${MONIKER}" \
        --chain-id "${CHAIN_ID}" \
        --from "${KEY_NAME}" \
        --keyring-backend "${KEYRING}" \
        --commission-rate "0.05" \
        --commission-max-rate "0.20" \
        --commission-max-change-rate "0.01" \
        --min-self-delegation "1" \
        --gas "auto" \
        --gas-adjustment "1.5" \
        --gas-prices "${MIN_GAS_PRICE:-0.0025${DENOM}}" \
        --home "${HOME_DIR}" \
        --yes

    echo ""
    echo "============================================"
    echo "  Validator created on live network!"
    echo "============================================"
    echo ""
    echo "  Validator: ${MONIKER}"
    echo "  Address:   ${ADDR}"
    echo "  Staked:    ${STAKE_AMOUNT} ${DENOM}"
    echo ""
    echo "  Check status: ${BINARY} query staking validator \$(${BINARY} keys show ${KEY_NAME} --bech val -a --keyring-backend ${KEYRING} --home ${HOME_DIR}) --home ${HOME_DIR}"
    echo ""
fi
