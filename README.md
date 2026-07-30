# The Jay Network

A Cosmos SDK Blockchain built for a unified ecosystem of games, DeFi, and social apps, all powered by a single native token.

[![Cosmos SDK](https://img.shields.io/badge/Cosmos%20SDK-Layer%201-6f4bd8?style=for-the-badge&logo=cosmos&logoColor=white)](https://cosmos.network)
[![Go](https://img.shields.io/badge/Go-00ADD8?style=for-the-badge&logo=go&logoColor=white)](https://go.dev)
[![Rust](https://img.shields.io/badge/Rust%20CosmWasm-000000?style=for-the-badge&logo=rust&logoColor=white)](https://cosmwasm.com)
[![Architecture](https://img.shields.io/badge/Arch-arm64-A020F0?style=for-the-badge)](#network-details)
[![Status](https://img.shields.io/badge/Mainnet-Live-2ea44f?style=for-the-badge)](https://jayscan.thejaynetwork.com)

[![Website](https://img.shields.io/badge/Website-thejaynetwork.com-7c3aed?style=flat-square)](https://thejaynetwork.com)
[![Explorer](https://img.shields.io/badge/Explorer-Jayscan-7c3aed?style=flat-square)](https://jayscan.thejaynetwork.com)
[![Wallet](https://img.shields.io/badge/Wallet-JAY%20Wallet-7c3aed?style=flat-square)](https://wallet.thejaynetwork.com)
[![Discord](https://img.shields.io/badge/Discord-Join-5865F2?style=flat-square&logo=discord&logoColor=white)](https://discord.gg/wf5UVtYMFu)
---

## Overview

The Jay Network is a blockchain built with the Cosmos SDK and Tendermint consensus. Instead of a single application, it hosts a full product suite on one chain, so a user holds one asset, JAY, and moves freely across games, prediction markets, a DEX, social apps, and more.

The chain uses CosmWasm for smart contracts and ships validators a verified golden binary set to keep consensus deterministic across the network.

## Ecosystem

| Product | What it is | Link |
| --- | --- | --- |
| JAY Games | Skill and luck mini games with on chain rewards | https://games.thejaynetwork.com |
| PIXTURE | Prediction markets | https://pixture.thejaynetwork.com |
| JAY Wallet | Web wallet with an in app dApp browser | https://wallet.thejaynetwork.com |
| Jayscan | Block explorer | https://jayscan.thejaynetwork.com |
| Meme | Social network with feeds, follows, and NFTs | https://meme.thejaynetwork.com |
| Campaign | Quest and airdrop platform for community growth | https://campaign.thejaynetwork.com |

## Tech Stack

- Consensus and core: Cosmos SDK with Tendermint, written in Go
- Smart contracts: CosmWasm, written in Rust
- Target architecture: arm64

## Network Details

| Field | Value |
| --- | --- |
| Chain ID | `thejaynetwork` |
| Native token | JAY |
| Base denom | `ujay` |
| Denom exponent | 6, so 1 JAY equals 1,000,000 ujay |
| Address prefix | `yjay` |
| Consensus | Tendermint BFT |
| Architecture | arm64 |

> Important: the canonical binaries are built for arm64. Running on x86 leads to app hash divergence and the node cannot join consensus. Always run validators on arm64.

## Public Endpoints

| Service | Endpoint |
| --- | --- |
| Explorer | https://jayscan.thejaynetwork.com |
| RPC | https://rpc-jay.onenov.xyz |
| REST | see the operator docs |

> Confirm the current public RPC and REST endpoints in the operator docs before wiring production services.

## Run a Node

Validator onboarding ships as a self contained bundle called VAL-OPS. It includes a verified golden arm64 binary, `libwasmvm`, the genesis file, config templates, the golden wasm set, and a step by step `SETUP.md`.

High level steps:

1. Provision an arm64 server that meets the recommended hardware profile.
2. Install the golden binary and `libwasmvm` from the bundle.
3. Place the provided `genesis.json` and config templates.
4. Sync with state sync for a fast start.
5. Create a funded operator key with the `file` or `os` keyring, never `test`.
6. Submit a create validator transaction.

> For consensus safety, run only the provided golden binary and golden wasm. Uploading arbitrary code can halt the chain.

See `VAL-OPS/SETUP.md` in releases for the full walkthrough.

## Smart Contracts

Contracts are written in CosmWasm and cover the ecosystem, for example prediction markets, OTC escrow, and reward flows. New code uploads are gated for determinism, so contract changes follow the golden wasm process.

## Security

- Validator keys and mnemonics stay offline. No team member will ever ask for them.
- Keep RPC bound to localhost and expose only what a public node must expose.
- Use a `file` or `os` keyring on any server that holds funds.

To report a vulnerability, reach out through the community channels privately below rather than opening a public issue.

## Community

- Website: https://thejaynetwork.com
- Explorer: https://jayscan.thejaynetwork.com
- Discord: https://discord.gg/wf5UVtYMFu

## License

See the `LICENSE` file for the full terms. If no license file is present yet, treat the code as all rights reserved until one is added.
