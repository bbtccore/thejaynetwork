#!/bin/bash
set -e
H=/home/jaynet/.jayn
CT=$H/config/config.toml
AT=$H/config/app.toml
CL=$H/config/client.toml
GN=$H/config/genesis.json

sed -i 's/"stake"/"ujay"/g' $GN
sed -i 's/timeout_propose = "3s"/timeout_propose = "2s"/' $CT
sed -i 's/timeout_commit = "5s"/timeout_commit = "3s"/' $CT
sed -i 's/max_num_inbound_peers = 40/max_num_inbound_peers = 120/' $CT
sed -i 's/max_num_outbound_peers = 10/max_num_outbound_peers = 40/' $CT
sed -i 's/send_rate = 5120000/send_rate = 20480000/' $CT
sed -i 's/recv_rate = 5120000/recv_rate = 20480000/' $CT
sed -i 's/prometheus = false/prometheus = true/' $CT
sed -i 's/size = 5000/size = 10000/' $CT
sed -i 's/minimum-gas-prices = ""/minimum-gas-prices = "0.0025ujay"/' $AT
sed -i 's/minimum-gas-prices = "0stake"/minimum-gas-prices = "0.0025ujay"/' $AT
sed -i '/\[api\]/,/\[/{s/enable = false/enable = true/}' $AT
sed -i 's|swagger = false|swagger = true|g' $AT
sed -i '/\[grpc\]/,/\[/{s/enable = false/enable = true/}' $AT
sed -i 's/snapshot-interval = 0/snapshot-interval = 1000/' $AT
sed -i '/\[telemetry\]/,/\[/{s/enabled = false/enabled = true/}' $AT
sed -i 's/prometheus-retention-time = 0/prometheus-retention-time = 60/' $AT
sed -i 's/chain-id = ""/chain-id = "thejaynetwork-1"/' $CL
echo "CONFIG TUNED"

