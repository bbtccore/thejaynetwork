# The Jay Network — Whitepaper

**Just Have Fun.**

> A Layer 1 for GameFi — where playing, creating, and earning live on one fast, open chain.

`Cosmos SDK · CometBFT` · `Proof-of-Stake L1` · `GameFi`

Whitepaper v1.0 · Community Edition · May 2026
thejaynetwork.com · explorer: jayscan.thejaynetwork.com

*For informational purposes only — not investment advice*

---

> **Important Notice**
> This document is provided for general information and community onboarding. It is **not** an offer to sell, a solicitation to buy, financial, legal, or tax advice, or a promise of any return. On-chain parameters reflect the network state following **Governance Proposal #4** (effective 2026-05-24) and may change through future on-chain governance. Please read the full Risk Factors & Legal Disclaimer in Section 10.

---

## Contents

- [Abstract](#abstract)
- [1 · Introduction — The "Just Have Fun" Vision](#1--introduction--the-just-have-fun-vision)
- [2 · The Problem with On-chain Games](#2--the-problem-with-on-chain-games)
- [3 · The Jay Network — Our Solution](#3--the-jay-network--our-solution)
- [4 · Technology & Architecture](#4--technology--architecture)
- [5 · Core Experiences: Play & Predict](#5--core-experiences-play--predict)
- [6 · The JAY Token & Tokenomics](#6--the-jay-token--tokenomics)
- [7 · Governance & Community](#7--governance--community)
- [8 · Joining the Network (Community Onboarding)](#8--joining-the-network-community-onboarding)
- [9 · Roadmap](#9--roadmap)
- [10 · Risk Factors & Legal Disclaimer](#10--risk-factors--legal-disclaimer)
- [11 · Conclusion & Links](#11--conclusion--links)

---

## Abstract

The Jay Network is a purpose-built Layer 1 blockchain that puts **fun first**. Built on the Cosmos SDK and secured by CometBFT proof-of-stake consensus, The Jay Network is designed for high-throughput games and a fun-first on-chain economy.

Most "play-to-earn" ecosystems collapsed because they optimized for speculation over enjoyment. The Jay Network takes the opposite stance, captured in its founding philosophy: **Just Have Fun.** Games and creative work should be genuinely worth your time first; ownership, rewards, and a real economy come as a natural layer on top.

The native token, **JAY**, secures the network through staking, settles every transaction and in-app economy, and grants holders a direct voice in on-chain governance. This whitepaper introduces the vision, the live architecture and on-chain parameters, the role of JAY, and exactly how to join, play, and stake.

---

## 1 · Introduction — The "Just Have Fun" Vision

Crypto promised a world where players truly own their items and value flows to the people who create it. Somewhere along the way, that promise got buried under spreadsheets, yield charts, and tokens nobody enjoyed using.

The Jay Network is a reset. Our entire design philosophy fits in three words — **Just Have Fun** — and it shapes every technical and economic decision we make. A blockchain should fade into the background. What people remember is the match they won, the bet that paid off. JAY is the rail that makes those moments rewarding without ever getting in the way.

### Three beliefs behind the network


| Belief                                  | Description                                                                                                        |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **Fun is the product**                  | If an app isn't fun without a token, no token can save it. We onboard great experiences first, then add ownership. |
| **Speed & low fees are non-negotiable** | Games need fast finality and near-zero fees. A purpose-built L1 delivers what a congested chain cannot.            |
| **Open by default**                     | Open-source modules, a public explorer, and permissionless validation keep the network honest and inspectable.     |


> **In one line:** The Jay Network is the home chain for experiences that are fun to play and fair to own — where having fun and building value are finally the same thing.

---

## 2 · The Problem with On-chain Games

The last cycle proved demand for on-chain games is real — and that most current designs are broken in predictable ways.

### 1. Ponzi-shaped economies

Many GameFi projects paid early users with the deposits of later users. When new entrants slowed, token prices and player counts collapsed together. Fun was never the engine — emissions were.

### 2. The wrong infrastructure

Games demand thousands of cheap, instant interactions. Running them on congested, high-fee general-purpose chains makes everything laggy and expensive, while shared block space lets one popular app price out everyone else.

### 3. Onboarding that scares newcomers away

Seed phrases, gas tokens, bridging, and confusing wallets turn curious people into bounced visitors.

> **The gap:** There is no widely adopted, fun-first Layer 1 that combines game-grade performance with a straightforward user experience. The Jay Network is built to be exactly that.

---

## 3 · The Jay Network — Our Solution

The Jay Network is a sovereign, application-optimized Layer 1 that pairs the proven security of the Cosmos stack with a product layer obsessed with fun.


| ~5s               | Fast finality    | On-chain             |
| ----------------- | ---------------- | -------------------- |
| Block time (live) | CometBFT BFT-PoS | Community governance |


### What makes The Jay Network different


| Pillar                     | What it means for you                                                                                    |
| -------------------------- | -------------------------------------------------------------------------------------------------------- |
| **Game-grade performance** | A dedicated chain means your game or transaction isn't competing for block space with unrelated traffic. |
| **Community governance**   | JAY holders propose and vote on upgrades, treasury spending, and ecosystem grants on-chain.              |
| **Open & verifiable**      | Open-source code, a public block explorer, and permissionless validation keep the network honest.        |


> **Live infrastructure:** The Jay Network is not a concept on paper. The chain runs today with native wallets, a public block explorer (**Jayscan**), a games portal (**JAY Games**), and a prediction platform (**PIXTURE**). The on-chain parameters in Section 6 reflect the live network after Governance Proposal #4.

---

## 4 · Technology & Architecture

The Jay Network is built on the Cosmos SDK — a battle-tested, modular framework powering some of the most reliable independent blockchains in the industry.

### 4.1 Consensus & security

The network uses **CometBFT** (the Tendermint-based BFT engine) for consensus. Participants who stake JAY propose and finalize blocks; honest behavior earns staking rewards, while equivocation or downtime is punished through slashing. This gives the network **fast, deterministic finality** — once a block is committed it is final, with no probabilistic waiting as on proof-of-work chains.

### 4.2 Modular by design

Functionality is delivered as independent modules, so the chain evolves without disruptive rewrites.


| Module                            | Description                                                                               |
| --------------------------------- | ----------------------------------------------------------------------------------------- |
| **Bank & Staking**                | Native JAY transfers, delegation, staking rewards, and slashing logic.                    |
| **Governance**                    | On-chain proposals, deposits, weighted voting, expedited tracks, and automatic execution. |
| **CosmWasm**                      | Smart contract engine for deploying on-chain applications (wasmd v0.61).                  |
| **Distribution & Community Pool** | A 2% community tax funds public-goods and ecosystem spending via governance.              |


### 4.3 Live tooling

- **Jayscan explorer** — public, real-time view of blocks, transactions, and holders.
- **Native wallet** — for holding, staking, and governance voting.
- **Standard Cosmos RPC & APIs** — compatible with standard Cosmos tooling and libraries.

---

## 5 · Core Experiences: Play & Predict

Two live application portals sit on top of the chain, each powered by JAY.

### JAY Games — Play

A web portal of casual and competitive games where players earn JAY rewards based on performance. The goal: games people would play even without rewards — with rewards layered on as a bonus, not bait. The games portal is live at `games.thejaynetwork.com`.

### PIXTURE — Predict

An image-based prediction and wagering platform where users place bets with JAY. Results are transparent and payouts are handled through the network.

> **Responsible play:** Wagering features are for entertainment, are subject to the laws of each user's jurisdiction, and may be restricted or unavailable in certain regions. Nothing here is an inducement to gamble.

### How they work together


| Action                            | What you earn                      | Powered by           |
| --------------------------------- | ---------------------------------- | -------------------- |
| Play games & score high           | JAY rewards                        | JAY Games            |
| Predict & wager (where permitted) | JAY payouts                        | PIXTURE              |
| Stake JAY                         | Network rewards + governance power | Staking & governance |


---

## 6 · The JAY Token & Tokenomics

JAY is the native asset of the network — the security, settlement, and governance layer the entire ecosystem runs on. The parameters below reflect the **live chain** following Governance Proposal #4 (effective 2026-05-24).

### 6.1 Token utility


| Utility                | Description                                                         |
| ---------------------- | ------------------------------------------------------------------- |
| **Network security**   | Staking JAY secures the chain and earns rewards.                    |
| **Fees & settlement**  | Transaction and module fees settle in JAY.                          |
| **Governance**         | Staked JAY is voting power over upgrades, parameters, and treasury. |
| **Ecosystem currency** | The unit of account for games, rewards, and grants.                 |


### 6.2 Token specifications


| Parameter               | Value                           |
| ----------------------- | ------------------------------- |
| Token / display denom   | **JAY**                         |
| Base denom              | `ujay` · 1 JAY = 1,000,000 ujay |
| Chain ID                | `thejaynetwork`                 |
| Address prefix (Bech32) | `yjay`                          |
| Block time              | ~5 seconds                      |
| Blocks per year         | 6,311,520                       |


### 6.3 Monetary policy — inflation & staking rewards

New JAY is issued to reward those who secure the network, following the standard Cosmos dynamic-inflation model. A PI controller moves the inflation rate between a **floor of 7%** and a **cap of 10%**, steering the network toward a **target bonded ratio of 67%**. When the staked share is below target, inflation rises to attract more security; as it approaches target, inflation eases. A 2% community tax is taken from rewards to fund the community pool.


| Parameter                      | Value                |
| ------------------------------ | -------------------- |
| Inflation range                | 7% (min) – 10% (max) |
| Rate-of-change (PI controller) | 1.00                 |
| Target bonded ratio            | 67%                  |
| Community tax                  | 2%                   |
| Proposer reward (base / bonus) | 0% / 0% (disabled)   |


> **APR vs. APY — read this carefully:** Staking yields are quoted as **APR (annual percentage rate, before compounding)**, not APY, and are **variable**. Because the current bonded ratio (1.80%) is far below the 67% target, network inflation is near its 10% cap and rewards are concentrated among relatively few stakers — so the present effective staking APR is unusually elevated and will **normalize downward as more JAY is staked**. Actual rates depend on total stake, fees, and uptime. Staking carries risk including slashing and price volatility. **No yield is guaranteed.**

### 6.4 Staking & security parameters


| Parameter                | Value                                 |
| ------------------------ | ------------------------------------- |
| Unbonding period         | 21 days (1,814,400s)                  |
| Max unbonding entries    | 7                                     |
| Downtime slashing        | 0.01%                                 |
| Double-sign slashing     | 5%                                    |
| Signed-blocks window     | 10,000 blocks (~13.9h), min 5% signed |
| Jail duration (downtime) | 10 minutes                            |


---

## 7 · Governance & Community

The Jay Network is built to progressively decentralize, with the community steering the direction of the chain.

### 7.1 On-chain governance

Anyone holding staked JAY can submit proposals and vote. Governance covers protocol upgrades, network parameters, treasury (community-pool) spending, and ecosystem grants. Voting is weighted by stake, deposits discourage spam, and approved proposals can execute automatically. An expedited track exists for time-sensitive decisions.


| Parameter                 | Value    |
| ------------------------- | -------- |
| Minimum deposit           | 10 JAY   |
| Deposit period            | 48 hours |
| Voting period             | 7 days   |
| Quorum                    | 40%      |
| Pass threshold            | 50%      |
| Veto threshold            | 33.4%    |
| Expedited voting period   | 24 hours |
| Expedited pass threshold  | 66.7%    |
| Expedited minimum deposit | 50 JAY   |


*The parameters in this whitepaper are themselves the product of governance — they reflect the state after Governance Proposal #4.*

### 7.2 Community

The project treats **blockchain education** as a core value, lowering the barrier for newcomers to understand and safely participate.

> **Progressive decentralization:** Early on, core contributors do more of the heavy lifting. Over time, decision-making and treasury control shift increasingly to the community through on-chain governance.

---

## 8 · Joining the Network (Community Onboarding)

Getting in is meant to be quick and genuinely fun. Here's how anyone — first wallet or hundredth — can take part.

### Step 1 · Get a wallet

Set up a Jay-compatible wallet (addresses start with `yjay…`) to hold and stake JAY. **Never share your seed phrase** — no team member will ever ask for it.

### Step 2 · Play & predict

Visit `games.thejaynetwork.com` to play games and earn JAY rewards, or try PIXTURE for image-based predictions.

### Step 3 · Stake JAY & earn

Stake JAY to help secure the chain and earn staking rewards (variable APR — see Section 6.3). You keep ownership while staked; undelegation is subject to the 21-day unbonding period.

### Step 4 · Vote & shape the network

Use staked JAY to vote on proposals — from upgrades to grant funding. The direction of the network is genuinely yours to influence.


| Tip                                                                                                              |
| ---------------------------------------------------------------------------------------------------------------- |
| **Verify everything** — Check live blocks, transactions, and holders yourself on the Jayscan explorer.           |
| **Stay safe** — Bookmark official links, beware impersonators, and never sign transactions you don't understand. |
| **Join the community** — Show up, play, give feedback, and help newcomers find their footing.                    |


---

## 9 · Roadmap

An indicative sequence of priorities. Timelines are directional and adapt to development, security review, and community governance.


| Phase                        | Focus                   | Highlights                                                                             |
| ---------------------------- | ----------------------- | -------------------------------------------------------------------------------------- |
| **Phase 1 — Foundation**     | Live chain & core infra | Mainnet live, native wallet, Jayscan explorer, staking & governance live. *(Achieved)* |
| **Phase 2 — Play & Predict** | Applications            | JAY Games portal and PIXTURE prediction platform live with JAY rewards. *(Achieved)*   |
| **Phase 3 — Grow**           | Ecosystem expansion     | Additional game titles, new validators, IBC integrations with other networks.          |


> **Forward-looking:** Roadmap items are plans, not commitments or guarantees. They may change, be delayed, or be dropped based on technical, legal, market, and governance outcomes.

---

## 10 · Risk Factors & Legal Disclaimer

Please read this section carefully. Participating in any blockchain network and holding digital assets involves significant risk.

### Key risks

- **Market & volatility risk.** The value of JAY may be highly volatile and could fall to zero. Only participate with what you can afford to lose.
- **Early-stage risk.** The network is early, with a low bonded ratio (1.80%). This means reward rates and the level of network security can vary over time.
- **Technology risk.** Smart contracts, modules, and infrastructure may contain bugs or be exploited despite review.
- **Staking & slashing risk.** Staked funds can be slashed for misbehavior (up to 5% for double-signing) or downtime. Yields are variable and not guaranteed.
- **Regulatory risk.** Laws on digital assets, gaming, and wagering vary by jurisdiction and are evolving. Features may be restricted or unavailable in your region.
- **Execution & liquidity risk.** Roadmap items may be delayed or not delivered, and there is no assurance JAY will be listed on, or remain on, any exchange.

### Legal notice

This whitepaper is for general informational and community-onboarding purposes only. It does **not** constitute, and should not be relied upon as, investment, financial, legal, tax, or any other advice, nor an offer or solicitation to buy or sell any token, security, or financial instrument in any jurisdiction. Nothing herein is a prospectus or an inducement to purchase any asset.

On-chain parameters reflect the network state after Governance Proposal #4 (effective 2026-05-24) and are **subject to change through future on-chain governance**. Supply, bonded ratio, and reward rates are dynamic and will differ over time. Statements about future events, performance, features, and timelines are **forward-looking** and inherently uncertain; actual outcomes may differ materially.

Digital assets and certain features (including any wagering functionality) may be regulated, restricted, or prohibited in your jurisdiction. It is your responsibility to ensure your participation is lawful where you are. The project, contributors, and affiliated entities accept no liability, to the maximum extent permitted by law, for any loss arising from use of or reliance on this document. **Always do your own research and consult qualified professionals before participating.**

---

## 11 · Conclusion & Links

The Jay Network exists for one reason: to make the on-chain world genuinely worth showing up for. Fun first, ownership built in, and a community that owns the rails.

Play-to-earn taught the industry what not to do. The Jay Network is the answer — a live, open, community-governed Layer 1 where great games come first and a transparent economy follows. The chain is running, JAY Games and PIXTURE are live, and the network grows stronger with every person who joins.

> **The invitation:** Get a wallet. Play a game. Stake some JAY. Vote on the future. And above all — **Just Have Fun.**

---


| Resource                  | Link / Value                |
| ------------------------- | --------------------------- |
| Website                   | `thejaynetwork.com`         |
| Block explorer (Jayscan)  | `jayscan.thejaynetwork.com` |
| RPC                       | `rpc.thejaynetwork.com`     |
| Chain ID                  | `thejaynetwork`             |
| Native token / base denom | JAY · `ujay`                |
| Games portal              | `games.thejaynetwork.com`   |


---

*© 2026 The Jay Network.*