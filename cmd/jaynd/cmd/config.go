package cmd

import (
	cmtcfg "github.com/cometbft/cometbft/config"
	serverconfig "github.com/cosmos/cosmos-sdk/server/config"
)

// initCometBFTConfig helps to override default CometBFT Config values.
// return cmtcfg.DefaultConfig if no custom configuration is required for the application.
func initCometBFTConfig() *cmtcfg.Config {
	cfg := cmtcfg.DefaultConfig()

	// Production-tuned P2P settings
	cfg.P2P.MaxNumInboundPeers = 100
	cfg.P2P.MaxNumOutboundPeers = 40
	cfg.P2P.SendRate = 20480000 // 20 MB/s
	cfg.P2P.RecvRate = 20480000 // 20 MB/s

	// Production mempool settings
	cfg.Mempool.Size = 10000
	cfg.Mempool.MaxTxsBytes = 1073741824 // 1 GB
	cfg.Mempool.CacheSize = 10000

	// Consensus timeouts (production)
	cfg.Consensus.TimeoutPropose = cfg.Consensus.TimeoutPropose
	cfg.Consensus.TimeoutCommit = cfg.Consensus.TimeoutCommit

	// Enable Prometheus metrics
	cfg.Instrumentation.Prometheus = true
	cfg.Instrumentation.PrometheusListenAddr = ":26660"

	return cfg
}

// initAppConfig helps to override default appConfig template and configs.
// return "", nil if no custom configuration is required for the application.
func initAppConfig() (string, interface{}) {
	type CustomAppConfig struct {
		serverconfig.Config `mapstructure:",squash"`
	}

	// Optionally allow the chain developer to overwrite the SDK's default
	// server config.
	srvCfg := serverconfig.DefaultConfig()

	// Production minimum gas prices for Jay Network
	srvCfg.MinGasPrices = "0.0025ujay"

	// Enable API for production
	srvCfg.API.Enable = true
	srvCfg.API.Swagger = true
	srvCfg.API.Address = "tcp://0.0.0.0:1317"

	// Enable gRPC for production
	srvCfg.GRPC.Enable = true
	srvCfg.GRPC.Address = "0.0.0.0:9090"

	// Telemetry for production monitoring
	srvCfg.Telemetry.Enabled = true
	srvCfg.Telemetry.EnableHostnameLabel = true
	srvCfg.Telemetry.EnableServiceLabel = true
	srvCfg.Telemetry.PrometheusRetentionTime = 60

	// Pruning for production (keep recent + every 100th)
	srvCfg.Pruning = "custom"
	srvCfg.PruningKeepRecent = "362880"
	srvCfg.PruningInterval = "100"

	// State sync snapshot
	srvCfg.StateSync.SnapshotInterval = 1000
	srvCfg.StateSync.SnapshotKeepRecent = 2

	customAppConfig := CustomAppConfig{
		Config: *srvCfg,
	}

	customAppTemplate := serverconfig.DefaultConfigTemplate

	return customAppTemplate, customAppConfig
}

