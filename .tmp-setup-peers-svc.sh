#!/bin/bash
set -e
H=/home/jaynet/.jayn
CT=$H/config/config.toml
NODE_NUM=$1
PEERS="cea71d779368994c9251824706bf6ff2b66e1a3f@34.69.40.9:26656,e641e8705053ad4b86584a17c502467581301e1a@35.222.85.162:26656,1680c6d2c5b6a03dd09462451b36896342c831f4@34.41.163.143:26656,ca48bdf23d9898aa9017bbc44ac8380a35655ffa@34.67.101.201:26656,9f345d6fa162459bc32e220aabd04e07f99eba04@34.171.203.84:26656"

# Remove self from peers
case $NODE_NUM in
  1) MY_ID="cea71d779368994c9251824706bf6ff2b66e1a3f" ;;
  2) MY_ID="e641e8705053ad4b86584a17c502467581301e1a" ;;
  3) MY_ID="1680c6d2c5b6a03dd09462451b36896342c831f4" ;;
  4) MY_ID="ca48bdf23d9898aa9017bbc44ac8380a35655ffa" ;;
  5) MY_ID="9f345d6fa162459bc32e220aabd04e07f99eba04" ;;
esac
MY_PEERS=$(echo "$PEERS" | sed "s/${MY_ID}@[^,]*,\?//g" | sed 's/,$//')

# Set persistent peers
sed -i "s/persistent_peers = \"\"/persistent_peers = \"${MY_PEERS}\"/" $CT

# Set external address based on node number
case $NODE_NUM in
  1) EXT_IP="34.69.40.9" ;;
  2) EXT_IP="35.222.85.162" ;;
  3) EXT_IP="34.41.163.143" ;;
  4) EXT_IP="34.67.101.201" ;;
  5) EXT_IP="34.171.203.84" ;;
esac
sed -i "s/external_address = \"\"/external_address = \"tcp:\/\/${EXT_IP}:26656\"/" $CT

echo "Peers set for node${NODE_NUM}"

# Setup Cosmovisor
echo "Setting up Cosmovisor..."
go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@latest 2>/dev/null || {
  # Fallback: download cosmovisor binary
  COSMOVISOR_URL="https://github.com/cosmos/cosmos-sdk/releases/download/cosmovisor%2Fv1.7.1/cosmovisor-v1.7.1-linux-amd64.tar.gz"
  cd /tmp
  wget -q $COSMOVISOR_URL -O cosmovisor.tar.gz 2>/dev/null || true
  if [ -f cosmovisor.tar.gz ]; then
    tar xf cosmovisor.tar.gz
    sudo mv cosmovisor /usr/local/bin/
  fi
}

# Setup cosmovisor dirs
sudo -u jaynet mkdir -p $H/cosmovisor/genesis/bin
sudo -u jaynet mkdir -p $H/cosmovisor/upgrades
sudo cp /usr/local/bin/jaynd $H/cosmovisor/genesis/bin/jaynd
sudo chown jaynet:jaynet $H/cosmovisor/genesis/bin/jaynd

# Create systemd service
cat > /tmp/jaynd.service << 'SVCEOF'
[Unit]
Description=Jay Network Node (jaynd via Cosmovisor)
After=network-online.target
Wants=network-online.target

[Service]
User=jaynet
Group=jaynet
ExecStart=/home/jaynet/go/bin/cosmovisor run start --home /home/jaynet/.jayn
Restart=always
RestartSec=3
LimitNOFILE=65536
LimitNPROC=65536

Environment="DAEMON_HOME=/home/jaynet/.jayn"
Environment="DAEMON_NAME=jaynd"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=false"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
Environment="DAEMON_LOG_BUFFER_SIZE=512"
Environment="UNSAFE_SKIP_BACKUP=true"

StandardOutput=journal
StandardError=journal
SyslogIdentifier=jaynd

[Install]
WantedBy=multi-user.target
SVCEOF

sudo cp /tmp/jaynd.service /etc/systemd/system/jaynd.service
sudo systemctl daemon-reload
sudo systemctl enable jaynd

echo "Systemd service created for node${NODE_NUM}"

# Install Go if not present (for cosmovisor)
if ! command -v go &>/dev/null; then
  echo "Installing Go..."
  wget -q https://go.dev/dl/go1.24.1.linux-amd64.tar.gz -O /tmp/go.tar.gz
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
  echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' | sudo tee -a /home/jaynet/.bashrc
  export PATH=$PATH:/usr/local/go/bin:/home/jaynet/go/bin:/root/go/bin
fi

# Install cosmovisor for jaynet user
sudo -u jaynet bash -c 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin; go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@latest 2>&1' || echo "cosmovisor install attempted"

# Update service to use correct path
COSMOVISOR_PATH=$(sudo -u jaynet bash -c 'echo $HOME/go/bin/cosmovisor')
sudo sed -i "s|ExecStart=.*|ExecStart=${COSMOVISOR_PATH} run start --home /home/jaynet/.jayn|" /etc/systemd/system/jaynd.service
sudo systemctl daemon-reload

echo "SETUP COMPLETE for node${NODE_NUM}"

