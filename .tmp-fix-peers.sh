#!/bin/bash
set -e
H=/home/jaynet/.jayn
CT=$H/config/config.toml
NODE_NUM=$1

# All peers with EXTERNAL IPs for cross-network connectivity
ALL_PEERS="cea71d779368994c9251824706bf6ff2b66e1a3f@34.69.40.9:26656,e641e8705053ad4b86584a17c502467581301e1a@35.222.85.162:26656,1680c6d2c5b6a03dd09462451b36896342c831f4@34.41.163.143:26656,ca48bdf23d9898aa9017bbc44ac8380a35655ffa@34.67.101.201:26656,9f345d6fa162459bc32e220aabd04e07f99eba04@34.171.203.84:26656"

# Node IDs
declare -A IDS
IDS[1]="cea71d779368994c9251824706bf6ff2b66e1a3f"
IDS[2]="e641e8705053ad4b86584a17c502467581301e1a"
IDS[3]="1680c6d2c5b6a03dd09462451b36896342c831f4"
IDS[4]="ca48bdf23d9898aa9017bbc44ac8380a35655ffa"
IDS[5]="9f345d6fa162459bc32e220aabd04e07f99eba04"

# External IPs
declare -A EXTIPS
EXTIPS[1]="34.69.40.9"
EXTIPS[2]="35.222.85.162"
EXTIPS[3]="34.41.163.143"
EXTIPS[4]="34.67.101.201"
EXTIPS[5]="34.171.203.84"

# Build peer list excluding self
MY_PEERS=""
for i in 1 2 3 4 5; do
  if [ "$i" != "$NODE_NUM" ]; then
    if [ -n "$MY_PEERS" ]; then
      MY_PEERS="${MY_PEERS},"
    fi
    MY_PEERS="${MY_PEERS}${IDS[$i]}@${EXTIPS[$i]}:26656"
  fi
done

# Replace persistent_peers (regardless of current value)
sed -i "s|^persistent_peers = .*|persistent_peers = \"${MY_PEERS}\"|" $CT

# Set external address
EXT_IP="${EXTIPS[$NODE_NUM]}"
sed -i "s|^external_address = .*|external_address = \"tcp://${EXT_IP}:26656\"|" $CT

echo "node${NODE_NUM} peers: $MY_PEERS"
echo "node${NODE_NUM} external: tcp://${EXT_IP}:26656"

