# The Jay Network - Chain Parameters & Fee Documentation

> Chain ID: `thejaynetwork`
> Native Token: **JAY** (minimal unit: `ujay`, 1 JAY = 1,000,000 ujay)
> Total Supply: 1,000,000 JAY (1,000,000,000,000 ujay)

---

## Transaction Fees

### Gas & Gas Prices

| Parameter | Value | Description |
|-----------|-------|-------------|
| Minimum Gas Price | `0.0025 ujay` | 노드가 수락하는 최소 가스 가격 |
| Default Gas Limit | `200,000` | 기본 트랜잭션 가스 한도 |
| Block Max Gas | unlimited (`-1`) | 블록당 가스 제한 없음 |
| Block Max Bytes | `22,020,096` (21MB) | 블록 최대 크기 |

### Fee Calculation

```
Fee = Gas Used × Gas Price
```

**예시:**
- 일반 전송 (gas ~80,000): `80,000 × 0.0025 = 200 ujay` (0.0002 JAY)
- 스테이킹 위임 (gas ~150,000): `150,000 × 0.0025 = 375 ujay` (0.000375 JAY)
- 스마트 컨트랙트 배포 (gas ~1,500,000+): `1,500,000 × 0.0025 = 3,750 ujay` (0.00375 JAY)
- 스마트 컨트랙트 실행 (gas ~300,000): `300,000 × 0.0025 = 750 ujay` (0.00075 JAY)

### Fee Distribution

| Recipient | Ratio | Description |
|-----------|-------|-------------|
| Validators & Delegators | 98% | 블록 보상 + 수수료 |
| Community Pool | 2% | 커뮤니티 자금 (거버넌스로 사용) |

---

## Auth Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Max Memo Characters | 256 | 메모 최대 길이 |
| TX Signature Limit | 7 | 트랜잭션당 최대 서명 수 |
| TX Size Cost Per Byte | 10 gas | 트랜잭션 크기당 가스 비용 |
| Sig Verify Cost (ed25519) | 590 gas | ed25519 서명 검증 비용 |
| Sig Verify Cost (secp256k1) | 1,000 gas | secp256k1 서명 검증 비용 |

---

## Staking

| Parameter | Value | Description |
|-----------|-------|-------------|
| Bond Denom | `ujay` | 스테이킹 토큰 |
| Max Validators | 100 | 최대 밸리데이터 수 |
| Unbonding Time | 21일 (`1,814,400s`) | 언본딩 기간 |
| Max Entries | 7 | 동시 언본딩/리델리게이션 최대 수 |
| Historical Entries | 10,000 | 저장하는 과거 기록 수 |
| Min Commission Rate | 0% | 밸리데이터 최소 커미션 |

### Genesis Validator (jay-node1)

| Parameter | Value |
|-----------|-------|
| Commission Rate | 5% |
| Max Commission Rate | 20% |
| Max Commission Change Rate | 1% per day |
| Self-Delegation | 500,000 JAY |

---

## Inflation & Minting

| Parameter | Value | Description |
|-----------|-------|-------------|
| Mint Denom | `ujay` | 발행 토큰 |
| Initial Inflation | 3% | 초기 인플레이션 |
| Max Inflation | 3% | 최대 인플레이션 |
| Min Inflation | 2% | 최소 인플레이션 |
| Inflation Rate Change | 1% | 연간 인플레이션 변동폭 |
| Goal Bonded Ratio | 67% | 목표 스테이킹 비율 |
| Blocks Per Year | 6,311,520 | 연간 블록 수 (~5초/블록) |

### Inflation Mechanism

- 스테이킹 비율이 67% **미만**이면 → 인플레이션이 최대 3%까지 증가 (스테이킹 유도)
- 스테이킹 비율이 67% **이상**이면 → 인플레이션이 최소 2%까지 감소
- 연간 변동폭: 최대 1%p

### Annual Reward Estimate

```
Annual Reward Rate ≈ Inflation / Bonded Ratio

예시: Inflation 3%, Bonded Ratio 50%
→ 스테이킹 연 수익률 ≈ 6%

예시: Inflation 2%, Bonded Ratio 67%
→ 스테이킹 연 수익률 ≈ 2.99%
```

---

## Slashing

| Parameter | Value | Description |
|-----------|-------|-------------|
| Signed Blocks Window | 100 blocks | 서명 확인 윈도우 |
| Min Signed Per Window | 50% | 최소 서명률 (50블록/100블록) |
| Downtime Jail Duration | 10분 (`600s`) | 다운타임 감옥 기간 |
| Double Sign Slash | 5% | 이중 서명 시 슬래싱 비율 |
| Downtime Slash | 1% | 다운타임 시 슬래싱 비율 |

### Slashing Scenarios

**다운타임 (Downtime):**
- 100블록 중 50블록 이상 서명 미참여 시 발동
- 스테이킹된 토큰의 **1%** 슬래싱
- 10분간 감옥(jail) 상태 → 이후 unjail 트랜잭션으로 복귀

**이중 서명 (Double Sign):**
- 같은 높이에서 두 개의 다른 블록에 서명 시 발동
- 스테이킹된 토큰의 **5%** 슬래싱
- **영구 감옥(tombstone)** → 복귀 불가

---

## Governance

| Parameter | Value | Description |
|-----------|-------|-------------|
| Min Deposit | 10 JAY (`10,000,000 ujay`) | 제안 최소 보증금 |
| Max Deposit Period | 2일 (`172,800s`) | 보증금 납부 기간 |
| Voting Period | 2일 (`172,800s`) | 투표 기간 |
| Quorum | 33.4% | 최소 투표 참여율 |
| Pass Threshold | 50% | 통과 기준 (Yes 비율) |
| Veto Threshold | 33.4% | 거부권 기준 |

### Expedited Proposals (긴급 제안)

| Parameter | Value |
|-----------|-------|
| Min Deposit | 50 JAY (`50,000,000 ujay`) |
| Voting Period | 1일 (`86,400s`) |
| Pass Threshold | 66.7% |

### Governance Rules

- **Proposal Cancel Ratio:** 50% (제안 취소 시 보증금의 50% 소각)
- **Burn Vote Veto:** Yes (거부권 발동 시 보증금 소각)
- **Min Deposit Ratio:** 1% (초기 입금 시 최소 보증금의 1% 필요)

---

## CosmWasm Smart Contracts

| Parameter | Value | Description |
|-----------|-------|-------------|
| Simulation Gas Limit | Block gas limit | 시뮬레이션 가스 한도 |
| Smart Query Gas Limit | 3,000,000 | 스마트 쿼리 가스 한도 |
| Memory Cache Size | 256 MB | WASM 메모리 캐시 크기 |
| Contract Debug Mode | Disabled | 프로덕션용 디버그 비활성화 |

### Supported Capabilities

```
iterator, staking, stargate,
cosmwasm_1_1, cosmwasm_1_2, cosmwasm_1_3, cosmwasm_1_4,
cosmwasm_2_0, cosmwasm_2_1, cosmwasm_2_2
```

### Smart Contract Operations

| Operation | Estimated Gas | Estimated Fee |
|-----------|--------------|---------------|
| Store Code (배포) | ~1,500,000+ | ~3,750 ujay |
| Instantiate (인스턴스 생성) | ~300,000 | ~750 ujay |
| Execute (실행) | ~200,000~500,000 | ~500~1,250 ujay |
| Query (조회) | 0 (무료) | 0 |

---

## IBC (Inter-Blockchain Communication)

| Parameter | Value | Description |
|-----------|-------|-------------|
| Allowed Clients | `*` (모든 클라이언트) | IBC 클라이언트 허용 |
| Transfer Send | Enabled | IBC 전송 활성화 |
| Transfer Receive | Enabled | IBC 수신 활성화 |
| ICA Controller | Enabled | 인터체인 계정 컨트롤러 |
| ICA Host | Enabled | 인터체인 계정 호스트 |
| ICA Allowed Messages | `*` (모든 메시지) | 허용 메시지 타입 |

---

## Network & Node Configuration

### P2P Settings

| Parameter | Value |
|-----------|-------|
| Max Inbound Peers | 100 |
| Max Outbound Peers | 40 |
| Send Rate | 20 MB/s |
| Receive Rate | 20 MB/s |

### Mempool

| Parameter | Value |
|-----------|-------|
| Max TX Count | 10,000 |
| Max TX Bytes | 1 GB |
| Cache Size | 10,000 |

### API Endpoints

| Service | Address | Status |
|---------|---------|--------|
| REST API | `tcp://0.0.0.0:1317` | Enabled |
| gRPC | `0.0.0.0:9090` | Enabled |
| Prometheus Metrics | `:26660` | Enabled |
| Swagger UI | `/swagger/` | Enabled |

### Pruning (State Management)

| Parameter | Value | Description |
|-----------|-------|-------------|
| Strategy | Custom | 커스텀 프루닝 |
| Keep Recent | 362,880 blocks (~21일) | 최근 블록 보존 |
| Pruning Interval | Every 100 blocks | 프루닝 주기 |
| Snapshot Interval | Every 1,000 blocks | 스냅샷 생성 주기 |
| Snapshot Keep Recent | 2 | 최근 스냅샷 보존 수 |

---

## Evidence

| Parameter | Value | Description |
|-----------|-------|-------------|
| Max Age (Blocks) | 100,000 | 증거 유효 블록 수 |
| Max Age (Duration) | 2일 (`172,800s`) | 증거 유효 기간 |
| Max Evidence Bytes | 1 MB | 증거 최대 크기 |

---

## Epochs

| Identifier | Duration |
|------------|----------|
| minute | 60s |
| hour | 3,600s |
| day | 86,400s |
| week | 604,800s |

---

## Quick Reference: Common Transaction Fees

| Transaction Type | Gas (approx.) | Fee (ujay) | Fee (JAY) |
|-----------------|---------------|------------|-----------|
| Send tokens | 80,000 | 200 | 0.0002 |
| Delegate | 150,000 | 375 | 0.000375 |
| Undelegate | 170,000 | 425 | 0.000425 |
| Redelegate | 200,000 | 500 | 0.0005 |
| Vote on proposal | 100,000 | 250 | 0.00025 |
| Submit proposal | 200,000 | 500 | 0.0005 |
| Claim rewards | 120,000 | 300 | 0.0003 |
| IBC Transfer | 150,000 | 375 | 0.000375 |
| Wasm Store Code | 1,500,000+ | 3,750+ | 0.00375+ |
| Wasm Instantiate | 300,000 | 750 | 0.00075 |
| Wasm Execute | 200,000~500,000 | 500~1,250 | 0.0005~0.00125 |

> **Note:** Gas usage varies by transaction complexity. Above values are estimates based on typical Cosmos SDK transactions. Actual gas may differ.
