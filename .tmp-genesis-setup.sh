#!/bin/bash
set -e
H=/home/jaynet/.jayn
CHAIN_ID="thejaynetwork-1"
DENOM="ujay"

# Create validator key on this node
sudo -u jaynet jaynd keys add validator --keyring-backend test --home $H 2>/dev/null || true
VAL_ADDR=$(sudo -u jaynet jaynd keys show validator -a --keyring-backend test --home $H)
echo "Validator address: $VAL_ADDR"

# Add genesis accounts
# Genesis wallet: 500 billion ujay (500,000 JAY)
sudo -u jaynet jaynd genesis add-genesis-account yjay1xl52dza38wq9fg283f2ys073gjjcr3rq6a5sfa 500000000000000${DENOM} --home $H
# This validator: 100 billion ujay (100,000 JAY)
sudo -u jaynet jaynd genesis add-genesis-account $VAL_ADDR 100000000000000${DENOM} --home $H

echo "Genesis accounts added"

