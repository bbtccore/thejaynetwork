package app

import (
	"context"
	"path/filepath"

	"cosmossdk.io/core/appmodule"
	storetypes "cosmossdk.io/store/types"
	upgradetypes "cosmossdk.io/x/upgrade/types"
	"github.com/cosmos/cosmos-sdk/client/flags"
	"github.com/cosmos/cosmos-sdk/codec"
	"github.com/cosmos/cosmos-sdk/runtime"
	servertypes "github.com/cosmos/cosmos-sdk/server/types"
	"github.com/cosmos/cosmos-sdk/types/module"
	authtypes "github.com/cosmos/cosmos-sdk/x/auth/types"
	distrkeeper "github.com/cosmos/cosmos-sdk/x/distribution/keeper"
	govtypes "github.com/cosmos/cosmos-sdk/x/gov/types"
	"github.com/spf13/cast"

	wasm "github.com/CosmWasm/wasmd/x/wasm"
	wasmkeeper "github.com/CosmWasm/wasmd/x/wasm/keeper"
	wasmtypes "github.com/CosmWasm/wasmd/x/wasm/types"
)

// AllCapabilities returns all capabilities available with the current wasmvm.
func AllCapabilities() []string {
	return []string{
		"iterator",
		"staking",
		"stargate",
		"cosmwasm_1_1",
		"cosmwasm_1_2",
		"cosmwasm_1_3",
		"cosmwasm_1_4",
		"cosmwasm_2_0",
		"cosmwasm_2_1",
		"cosmwasm_2_2",
	}
}

// registerWasmModule registers the CosmWasm module (not supported via depinject).
func (app *App) registerWasmModule(appOpts servertypes.AppOptions) error {
	// Register store key
	if err := app.RegisterStores(
		storetypes.NewKVStoreKey(wasmtypes.StoreKey),
	); err != nil {
		return err
	}

	// Get governance module address
	govModuleAddr, _ := app.AuthKeeper.AddressCodec().BytesToString(authtypes.NewModuleAddress(govtypes.ModuleName))

	// Get wasm data directory
	homeDir := cast.ToString(appOpts.Get(flags.FlagHome))
	if homeDir == "" {
		homeDir = DefaultNodeHome
	}
	wasmDir := filepath.Join(homeDir, "wasm")

	// WasmVM node config
	gasLimit := uint64(0) // 0 = use block gas limit for simulations
	nodeConfig := wasmtypes.NodeConfig{
		SimulationGasLimit: &gasLimit,
		SmartQueryGasLimit: 3_000_000,
		MemoryCacheSize:    256,
		ContractDebugMode:  false,
	}

	// WasmVM config
	vmConfig := wasmtypes.VMConfig{}

	// Distribution querier implements wasmtypes.DistributionKeeper
	distrQuerier := distrkeeper.NewQuerier(app.DistrKeeper)

	// Create WasmKeeper
	app.WasmKeeper = wasmkeeper.NewKeeper(
		app.appCodec,
		runtime.NewKVStoreService(app.GetKey(wasmtypes.StoreKey)),
		app.AuthKeeper,
		app.BankKeeper,
		app.StakingKeeper,
		distrQuerier,
		app.IBCKeeper.ChannelKeeper, // ICS4Wrapper
		app.IBCKeeper.ChannelKeeper, // ChannelKeeper
		nil,                         // ChannelKeeperV2 (IBC v2 - not needed for basic wasm)
		app.TransferKeeper,
		app.MsgServiceRouter(),
		app.GRPCQueryRouter(),
		wasmDir,
		nodeConfig,
		vmConfig,
		AllCapabilities(),
		govModuleAddr,
	)

	// Register wasm module
	wasmAppModule := wasm.NewAppModule(app.appCodec, &app.WasmKeeper, app.StakingKeeper, app.AuthKeeper, app.BankKeeper, app.MsgServiceRouter(), nil)
	if err := app.RegisterModules(wasmAppModule); err != nil {
		return err
	}

	return nil
}

// RegisterWasm registers wasm module on the client side (for CLI).
// This needs to be removed after wasm supports App Wiring.
func RegisterWasm(cdc codec.Codec) map[string]appmodule.AppModule {
	modules := map[string]appmodule.AppModule{
		wasmtypes.ModuleName: wasm.NewAppModule(cdc, &wasmkeeper.Keeper{}, nil, nil, nil, nil, nil),
	}

	for _, m := range modules {
		if mr, ok := m.(module.AppModuleBasic); ok {
			mr.RegisterInterfaces(cdc.InterfaceRegistry())
		}
	}

	return modules
}

// GetWasmKeeper returns the Wasm keeper.
func (app *App) GetWasmKeeper() *wasmkeeper.Keeper {
	return &app.WasmKeeper
}

// registerUpgradeHandlers registers the upgrade handlers for the app.
func (app *App) registerUpgradeHandlers() {
	// v2-cosmwasm upgrade: adds CosmWasm module
	const upgradeName = "v2-cosmwasm"

	app.UpgradeKeeper.SetUpgradeHandler(
		upgradeName,
		func(ctx context.Context, plan upgradetypes.Plan, fromVM module.VersionMap) (module.VersionMap, error) {
			// Run module migrations - this will trigger InitGenesis for wasm
			// since it's a new module not in the fromVM version map
			return app.ModuleManager.RunMigrations(ctx, app.Configurator(), fromVM)
		},
	)

	// Store upgrades for the new wasm module
	upgradeInfo, err := app.UpgradeKeeper.ReadUpgradeInfoFromDisk()
	if err != nil {
		panic(err)
	}

	if upgradeInfo.Name == upgradeName && !app.UpgradeKeeper.IsSkipHeight(upgradeInfo.Height) {
		storeUpgrades := storetypes.StoreUpgrades{
			Added: []string{wasmtypes.StoreKey},
		}
		app.SetStoreLoader(upgradetypes.UpgradeStoreLoader(upgradeInfo.Height, &storeUpgrades))
	}
}
