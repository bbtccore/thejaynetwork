🔗 Jay Network — Node Operator Guide

■ Chain Info
• Chain ID: thejaynetwork
• Denom: ujay (1 JAY = 1,000,000 ujay)
• Cosmos SDK v0.53.6 / CometBFT v0.38.21 / CosmWasm v2.1.4

■ Public Endpoints
• RPC: 89.58.25.104:26657
• REST API: 89.58.25.104:1317

■ Minimum Server Requirements
• CPU 4 cores / RAM 8GB / SSD 100GB+
• Ubuntu 22.04+ or Debian 12+

■ Installation
1) Install Go 1.24 or higher
2) Build from source:
   git clone https://github.com/thejaynetwork/thejaynetwork.git
   cd thejaynetwork && go build -o jaynd ./cmd/jaynd

3) Initialize node:
   jaynd init <your-moniker> --chain-id thejaynetwork

4) Download genesis file:
   curl -s http://89.58.25.104:26657/genesis | jq '.result.genesis' > ~/.jayn/config/genesis.json

5) Set peers in config.toml:
   persistent_peers = "<nodeID>@152.53.195.74:26656,<nodeID>@89.58.25.104:26656"
   (Get node ID: curl -s http://<IP>:26657/status | jq -r '.result.node_info.id')

6) Start the node:
   jaynd start

■ Validator Registration (after full sync)
jaynd tx staking create-validator \
  --amount <stake-amount>ujay \
  --pubkey $(jaynd tendermint show-validator) \
  --moniker "<your-validator-name>" \
  --chain-id thejaynetwork \
  --commission-rate 0.05 \
  --commission-max-rate 0.20 \
  --commission-max-change-rate 0.01 \
  --min-self-delegation 1 \
  --from <your-key> \
  --fees 5000ujay -y

※ JAY tokens are required for staking to register as a validator.
※ Feel free to ask if you have any questions!
