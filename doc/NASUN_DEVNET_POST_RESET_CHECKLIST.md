# Nasun Devnet Post-Reset Checklist

**Version**: 4.0.0
**Created**: 2026-01-17
**Updated**: 2026-02-04
**Author**: Claude Code
**Purpose**: Devnet 리셋 후 반드시 수행해야 할 작업 목록

> **중요**: Devnet을 리셋하면 모든 온체인 데이터(스마트 컨트랙트, 객체, 상태)가 삭제됩니다.
> 이 문서의 체크리스트를 순서대로 따라 서비스를 복구하세요.

---

## 목차

1. [개요](#1-개요)
2. [스마트 컨트랙트 재배포](#2-스마트-컨트랙트-재배포)
3. [더미 데이터 생성](#3-더미-데이터-생성)
4. [프론트엔드 설정 업데이트](#4-프론트엔드-설정-업데이트)
5. [검증 체크리스트](#5-검증-체크리스트)
6. [빠른 참조](#6-빠른-참조)

---

## 1. 개요

### 1.1 Devnet 리셋이 필요한 경우

- Sui mainnet 새 버전으로 업그레이드 (DB 스키마 변경)
- zkLogin 키 불일치 해결
- 네트워크 성능 문제 (DB 증가, epoch 조정)
- 실행 엔진 장애 (Execution halt, SendError)
- 심각한 버그 발생

### 1.2 현재 노드 아키텍처 (2-Node, V7)

| Node | IP | Role | Services | Instance |
|------|-----|------|----------|----------|
| Node 1 | 3.38.127.23 | Validator + RPC + Faucet | nasun-validator, nasun-fullnode, nasun-faucet, nginx | t3.xlarge (16GB) |
| Node 2 | 3.38.76.85 | Validator | nasun-validator | t3.large (8GB) |

> **참고**: V7에서 Node 1을 t3.xlarge (16GB)로 업그레이드
> HTTPS 엔드포인트: `rpc.devnet.nasun.io`, `faucet.devnet.nasun.io` (Node 1 nginx)

### 1.3 리셋 후 복구가 필요한 항목

| 항목 | 설명 | 영향 받는 앱 |
|------|------|-------------|
| **Devnet Tokens** | 통합 NBTC, NUSDC 토큰 + Faucet | 모든 앱 (Pado, Baram 등) |
| **DeepBook V3** | CLOB 거래 엔진 | Pado |
| **Trading Pools** | NBTC/NUSDC, NSN/NUSDC | Pado |
| **Prediction Market** | 바이너리 예측 마켓 | Pado |
| **Governance** | Proposal (fee-based) + Poll (sponsored) 투표 | Nasun Website |
| **Baram** | AI Settlement Layer | Baram |
| **Baram Executor** | TEE Executor Registry | Baram |
| **Dummy Proposals** | 테스트용 프로포절 | Nasun Website |
| **Dummy Markets** | 테스트용 예측 마켓 | Pado |

---

## 2. 스마트 컨트랙트 재배포

### 2.1 배포 순서 (의존성 순서)

```
1. Devnet Tokens + Faucet  ←  다른 컨트랙트의 토큰 타입 의존 (packages/devnet-tokens)
2. DeepBook V3             ←  Trading Pools의 Pool 생성 의존
3. Trading Pools           ←  (Optional) Pool 생성
4. Prediction Market       ←  Devnet Tokens 의존
5. Governance              ←  독립적
6. Baram                   ←  Devnet Tokens 의존 (NUSDC 결제)
7. Baram Executor          ←  독립적
```

### 2.2 Move.toml 업데이트

**중요**: 배포 전 각 컨트랙트의 `Move.toml`에서 Chain ID를 업데이트해야 합니다.

```bash
# 새 Chain ID 확인
curl -s -X POST https://rpc.devnet.nasun.io \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getChainIdentifier","params":[]}' | jq -r '.result'
```

각 `Move.toml`의 `[environments]` 섹션 업데이트:

```toml
[environments]
devnet = "<NEW_CHAIN_ID>"
nasun-devnet = "<NEW_CHAIN_ID>"
```

### 2.3 Step 1: Devnet Tokens + Faucet

> **통합 토큰 패키지**: `packages/devnet-tokens`는 모든 앱에서 공용으로 사용하는 NBTC/NUSDC 토큰입니다.

```bash
cd /home/naru/my_apps/nasun-monorepo/packages/devnet-tokens

# Move.toml 업데이트 (published-at, devnet_tokens address를 0x0으로 리셋)
# [addresses]
# devnet_tokens = "0x0"
# published-at 줄 삭제 또는 주석 처리

# 빌드
sui move build

# 배포
sui client publish --gas-budget 100000000
```

**기록할 값:**
| 변수명 | 설명 | 예시 |
|--------|------|------|
| `VITE_TOKENS_PACKAGE` | Package ID | `0x10748ed4...` |
| `VITE_TOKEN_FAUCET` | TokenFaucet Shared Object | `0x04aa4144...` |
| `VITE_CLAIM_RECORD` | ClaimRecord Shared Object | `0x8b9e8545...` |
| `VITE_NBTC_TYPE` | NBTC Type | `<PKG>::nbtc::NBTC` |
| `VITE_NUSDC_TYPE` | NUSDC Type | `<PKG>::nusdc::NUSDC` |

**배포 후 Move.toml 업데이트:**
```toml
published-at = "<NEW_PACKAGE_ID>"

[addresses]
pado = "<NEW_PACKAGE_ID>"
```

### 2.4 Step 2: DeepBook V3

> **주의**: DeepBook V3는 매우 큰 패키지입니다. 배포 시 약 **580 NSN** 가스가 필요합니다.
> 배포 전에 가스 코인을 병합하세요: `sui client merge-coin --primary-coin <COIN_ID> --coin-to-merge <OTHER_COIN_ID>`

```bash
# 먼저 DeepBook token 패키지 배포 (DeepBook 전용 토큰)
cd /home/naru/my_apps/nasun-monorepo/apps/pado/deepbookv3/packages/token
sui move build
sui client publish --gas-budget 100000000
# TOKEN_PACKAGE_ID 기록

# 그 다음 deepbook 패키지 배포
cd /home/naru/my_apps/nasun-monorepo/apps/pado/deepbookv3/packages/deepbook

# Move.toml environments 업데이트, token 주소 설정
sui move build
sui client publish --gas 0x<MERGED_COIN_ID> --gas-budget 800000000000
```

**기록할 값:**
| 변수명 | 설명 |
|--------|------|
| `VITE_DEEPBOOK_PACKAGE` | DeepBook Package ID |
| `VITE_DEEPBOOK_REGISTRY` | Registry Shared Object |
| `VITE_DEEPBOOK_ADMIN_CAP` | AdminCap Object |
| `VITE_DEEP_TOKEN` | DEEP Token Treasury Cap |

### 2.5 Step 3: Prediction Market

```bash
cd /home/naru/my_apps/nasun-monorepo/apps/pado/contracts-prediction

# Move.toml 업데이트
# - pado address를 Step 1에서 배포한 패키지 ID로 설정
# - environments 업데이트

sui move build
sui client publish --gas-budget 100000000
```

**기록할 값:**
| 변수명 | 설명 |
|--------|------|
| `VITE_PREDICTION_PACKAGE` | Package ID |
| `VITE_PREDICTION_GLOBAL_STATE` | GlobalState Shared Object |
| `VITE_PREDICTION_ADMIN_CAP` | AdminCap Object |

### 2.6 Step 4: Governance

```bash
cd /home/naru/my_apps/nasun-monorepo/apps/nasun-website/contracts/governance

# Move.toml environments 업데이트
sui move build
sui client publish --gas-budget 100000000
```

**기록할 값:**
| 변수명 | 설명 |
|--------|------|
| `VITE_GOVERNANCE_PACKAGE_ID` | Package ID |
| `VITE_GOVERNANCE_DASHBOARD_ID` | Dashboard Shared Object |
| `VITE_PROPOSAL_TYPE_REGISTRY_ID` | ProposalTypeRegistry Shared Object |
| `NASUN_DEVNET_ADMIN_CAP` | AdminCap Object |
| `NASUN_DEVNET_UPGRADE_CAP` | UpgradeCap Object |

### 2.7 Step 5: Baram (AI Settlement Layer)

> **Note**: Baram 패키지는 devnet_tokens를 의존성으로 사용합니다.
> `--with-unpublished-dependencies` 플래그 사용 시 devnet_tokens 모듈도 함께 배포됩니다.

```bash
cd /home/naru/my_apps/nasun-monorepo/apps/baram/contracts

# Move.toml 업데이트
# - [environments] 섹션에 새 chain ID 추가
# - [addresses]에서 devnet_tokens 주소 설정 (Step 1에서 배포한 ID)

# 이전 Pub 파일 삭제
rm -f Pub.devnet.toml

# 빌드 및 배포
sui client test-publish --build-env devnet --with-unpublished-dependencies --gas-budget 100000000
```

**기록할 값:**
| 변수명 | 설명 |
|--------|------|
| `VITE_BARAM_PACKAGE_ID` | Package ID |
| `VITE_BARAM_REGISTRY_ID` | BaramRegistry Shared Object |
| `VITE_BARAM_UPGRADE_CAP` | UpgradeCap Object |
| `VITE_NUSDC_TYPE` | `<PKG>::nusdc::NUSDC` |

### 2.8 Step 6: Baram Executor Registry

```bash
cd /home/naru/my_apps/nasun-monorepo/apps/baram/contracts-executor

# Move.toml [environments] 섹션 업데이트
rm -f Pub.devnet.toml

# 빌드 및 배포
sui client test-publish --build-env devnet --gas-budget 100000000
```

**기록할 값:**
| 변수명 | 설명 |
|--------|------|
| `VITE_EXECUTOR_PACKAGE_ID` | Package ID |
| `VITE_EXECUTOR_REGISTRY_ID` | ExecutorRegistry Shared Object |
| `VITE_EXECUTOR_ADMIN_CAP` | AdminCap Object |

### 2.9 Step 7: TEE Executor 등록 (Optional)

EC2 Nitro Enclave 인스턴스가 필요합니다. Spot 인스턴스로 비용 절감 가능.

```bash
# Executor 등록 (AdminCap 필요)
sui client call \
  --package <EXECUTOR_PACKAGE_ID> \
  --module executor \
  --function register_executor \
  --args \
    <ADMIN_CAP> \
    <EXECUTOR_REGISTRY> \
    "tee-llama-3.2-3b" \
    "<RSA_PUBLIC_KEY_BASE64>" \
    "<EXECUTOR_WALLET_ADDRESS>" \
  --gas-budget 10000000
```

---

## 3. 더미 데이터 생성

### 3.1 Governance: Proposal 및 Poll 생성

스마트 컨트랙트 배포 후, 프론트엔드에서 표시할 테스트 데이터를 생성합니다.

**투표 유형:**
| 유형 | 설명 | 가스비 |
|------|------|--------|
| **Proposal** | 거버넌스 투표 (중요한 의사결정) | 사용자가 직접 지불 (fee-based) |
| **Poll** | 커뮤니티 설문 (의견 수집) | 스폰서가 지불 (sponsored transaction) |

#### 3.1.1 Proposal 생성 (Fee-based 투표)

```bash
# 예시: NSN Staking Reward Proposal
sui client call \
  --package <GOVERNANCE_PACKAGE> \
  --module proposal \
  --function create \
  --args \
    <ADMIN_CAP> \
    "NSN Staking Reward Adjustment" \
    "Proposal to adjust the NSN staking rewards from 5% to 7% APY to incentivize long-term holding." \
    1771027200000 \
  --gas-budget 10000000

# 결과에서 Proposal ID 기록
```

#### 3.1.2 Poll 생성 (Sponsored 투표)

```bash
# 예시: AI Services Integration Poll
sui client call \
  --package <GOVERNANCE_PACKAGE> \
  --module proposal \
  --function create \
  --args \
    <ADMIN_CAP> \
    "Which AI services should we prioritize?" \
    "Community poll to decide which AI integrations to develop first: ChatGPT API, Claude API, or Gemini API." \
    1771027200000 \
  --gas-budget 10000000

# Proposal ID 기록
```

#### 3.1.3 Proposal Type 설정 (Poll로 변경)

```bash
# Poll로 설정 (type = 1)
sui client call \
  --package <GOVERNANCE_PACKAGE> \
  --module proposal \
  --function set_proposal_type \
  --args \
    <PROPOSAL_TYPE_REGISTRY> \
    <ADMIN_CAP> \
    <PROPOSAL_ID> \
    1 \
  --gas-budget 10000000
```

#### 3.1.4 Dashboard에 Proposal 등록

```bash
sui client call \
  --package <GOVERNANCE_PACKAGE> \
  --module dashboard \
  --function register_proposal \
  --args \
    <DASHBOARD_ID> \
    <ADMIN_CAP> \
    <PROPOSAL_ID> \
  --gas-budget 10000000
```

### 3.2 Prediction Market: 더미 마켓 생성

#### 3.2.1 마켓 생성 예시

```bash
# AI/Technology 마켓
sui client call \
  --package <PREDICTION_PACKAGE> \
  --module prediction_market \
  --function create_market \
  --args \
    <ADMIN_CAP> \
    <GLOBAL_STATE> \
    "Will OpenAI release GPT-5 in Q1 2026?" \
    "Resolves YES if OpenAI officially announces GPT-5 before March 31, 2026." \
    "AI Technology" \
    1769239431000 \
    1769843231000 \
    <RESOLVER_ADDRESS> \
  --gas-budget 10000000

# Crypto 마켓
sui client call \
  --package <PREDICTION_PACKAGE> \
  --module prediction_market \
  --function create_market \
  --args \
    <ADMIN_CAP> \
    <GLOBAL_STATE> \
    "Will BTC reach 200K by 2026?" \
    "Resolves YES if Bitcoin price reaches $200,000 on any major exchange before December 31, 2026." \
    "Crypto" \
    1770448000000 \
    1771052800000 \
    <RESOLVER_ADDRESS> \
  --gas-budget 10000000

# Sports 마켓
sui client call \
  --package <PREDICTION_PACKAGE> \
  --module prediction_market \
  --function create_market \
  --args \
    <ADMIN_CAP> \
    <GLOBAL_STATE> \
    "Will Korea advance to 2026 World Cup semifinals?" \
    "Resolves YES if South Korea reaches the semifinals of the 2026 FIFA World Cup." \
    "Sports" \
    1770448000000 \
    1771052800000 \
    <RESOLVER_ADDRESS> \
  --gas-budget 10000000
```

#### 3.2.2 생성된 마켓 ID 조회

```bash
curl -s -X POST https://rpc.devnet.nasun.io \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"suix_queryEvents","params":[{"MoveEventType":"<PREDICTION_PACKAGE>::prediction_market::MarketCreated"},null,100,false]}' | jq '.result.data[] | {market_id: .parsedJson.market_id, question: .parsedJson.question}'
```

---

## 4. 프론트엔드 설정 업데이트

### 4.0 중앙화된 ID 관리 (권장)

**V6부터 `@nasun/devnet-config` 패키지를 통한 중앙화된 ID 관리를 사용합니다.**

대부분의 앱이 이미 이 패키지를 사용하도록 마이그레이션되었으므로,
devnet 리셋 후에는 다음 단계만 수행하면 됩니다:

```bash
cd /home/naru/my_apps/nasun-monorepo

# 1. devnet-ids.json 업데이트 (배포된 컨트랙트 ID 기록)
vi packages/devnet-config/devnet-ids.json

# 2. .env 파일 자동 동기화
pnpm devnet:sync

# 3. 커밋
git add . && git commit -m "chore: update devnet IDs for V7"
```

**devnet-ids.json 업데이트 항목:**
| 섹션 | 업데이트 내용 |
|------|-------------|
| `version` | 버전 번호 (V6, V7 등) |
| `lastUpdated` | 업데이트 날짜 |
| `network.chainId` | 새 Chain ID |
| `tokens.*` | Devnet Tokens Package ID, TokenFaucet ID 등 |
| `deepbook.*` | DeepBook V3 Package ID, Registry ID 등 |
| `prediction.*` | Prediction Market Package ID, GlobalState ID 등 |
| `lottery.*` | Lottery Package ID, LotteryPool ID 등 |
| `governance.*` | Governance Package ID, Dashboard ID 등 |
| `baram.*` | Baram Package ID, Registry ID 등 |

**Move.toml 수동 업데이트 필요:**
> devnet-ids.json 외에 다음 Move.toml 파일들도 수동 업데이트 필요

| 파일 | 업데이트 내용 |
|------|-------------|
| `packages/devnet-tokens/Move.toml` | published-at, devnet_tokens 주소 |
| `apps/pado/contracts/Move.toml` | published-at, pado 주소 |
| `apps/pado/contracts-prediction/Move.toml` | pado 주소, environments |
| `apps/baram/contracts/Move.toml` | environments, addresses |
| `apps/baram/contracts-executor/Move.toml` | environments |
| `apps/baram/contracts-compliance/Move.toml` | environments |
| `apps/baram/contracts-attestation/Move.toml` | environments |
| `apps/nasun-website/contracts/governance/Move.toml` | environments |

**Sui 프레임워크 Move.toml (중요):**

> 리셋 시 Sui 바이너리를 리빌드하면 프레임워크의 `[environments]` chain ID가
> Sui upstream 기본값으로 초기화될 수 있다. 이 경우 `sui move build`가
> "Your active environment is not present in Move.toml" 에러로 실패한다.
> 아래 두 파일의 chain ID를 Nasun devnet chain ID와 일치시켜야 한다.

| 파일 | 업데이트 내용 |
|------|-------------|
| `nasun-devnet/sui/crates/sui-framework/packages/sui-framework/Move.toml` | `[environments]` chain ID |
| `nasun-devnet/sui/crates/sui-framework/packages/move-stdlib/Move.toml` | `[environments]` chain ID |

**자동으로 마이그레이션된 파일들** (더 이상 수동 업데이트 불필요):
- `packages/wallet/src/config/tokens.ts` → @nasun/devnet-config 사용
- `packages/wallet/src/sui/tokenFaucet.ts` → @nasun/devnet-config 사용
- `apps/pado/frontend/src/features/prediction/constants.ts` → @nasun/devnet-config 사용
- `apps/pado/frontend/src/features/lottery/constants.ts` → @nasun/devnet-config 사용
- `apps/baram/frontend/src/config/network.ts` → @nasun/devnet-config 사용
- `apps/nasun-website/frontend/src/constants/suiPackageConstants.ts` → @nasun/devnet-config 사용

> **참고**: 아래 4.1 ~ 4.3 섹션은 레거시 참조용입니다.
> 새로운 워크플로우에서는 `devnet-ids.json`만 업데이트하면 됩니다.

### 4.1 (레거시) 업데이트 필요한 파일 목록

> **주의**: 대부분의 파일은 이미 `@nasun/devnet-config`를 사용하도록 마이그레이션되었습니다.
> `.env` 파일과 `Move.toml` 파일만 수동 업데이트가 필요할 수 있습니다.

#### Pado 앱 (apps/pado)

| 파일 | 업데이트 내용 | 상태 |
|------|-------------|------|
| `.env.development` | 모든 VITE_* 환경변수 | `pnpm devnet:sync`로 자동화 |
| `.env.staging` | 모든 VITE_* 환경변수 | `pnpm devnet:sync`로 자동화 |
| `.env.local` | 모든 VITE_* 환경변수 | `pnpm devnet:sync`로 자동화 |
| `frontend/src/features/prediction/constants.ts` | Package ID, Market IDs | ✅ 마이그레이션 완료 |
| `frontend/src/lib/unified-margin.ts` | DEVNET_TOKENS_PACKAGE | 검토 필요 |
| `frontend/src/features/lottery/constants.ts` | NUSDC_TYPE | ✅ 마이그레이션 완료 |
| `contracts/Move.toml` | published-at, pado address | 수동 업데이트 필요 |
| `contracts-prediction/Move.toml` | pado address, environments | 수동 업데이트 필요 |

#### Baram 앱 (apps/baram)

| 파일 | 업데이트 내용 | 상태 |
|------|-------------|------|
| `.env` | 모든 VITE_* 환경변수 | `pnpm devnet:sync`로 자동화 |
| `frontend/.env` | 모든 VITE_* 환경변수 | `pnpm devnet:sync`로 자동화 |
| `frontend/src/config/network.ts` | fallback 값 | ✅ 마이그레이션 완료 |
| `contracts/Move.toml` | environments, addresses | 수동 업데이트 필요 |
| `contracts-executor/Move.toml` | environments | 수동 업데이트 필요 |

#### Nasun Website (apps/nasun-website)

| 파일 | 업데이트 내용 | 상태 |
|------|-------------|------|
| `frontend/.env.development` | Governance 환경변수 | `pnpm devnet:sync`로 자동화 |
| `frontend/.env.local` | Governance 환경변수 | `pnpm devnet:sync`로 자동화 |
| `frontend/src/constants/suiPackageConstants.ts` | NASUN_DEVNET_* 상수 | ✅ 마이그레이션 완료 |
| `contracts/governance/Move.toml` | environments | 수동 업데이트 필요 |

### 4.2 (레거시) 환경변수 상세

> **참고**: `pnpm devnet:sync` 명령으로 자동 생성됩니다.

#### Pado .env 파일

```bash
# Network
VITE_RPC_URL=https://rpc.devnet.nasun.io
VITE_FAUCET_URL=https://faucet.devnet.nasun.io
VITE_CHAIN_ID=<NEW_CHAIN_ID>

# DeepBook V3 Package
VITE_DEEPBOOK_PACKAGE=<DEEPBOOK_PACKAGE_ID>
VITE_DEEPBOOK_REGISTRY=<REGISTRY_ID>
VITE_DEEPBOOK_ADMIN_CAP=<ADMIN_CAP_ID>
VITE_DEEP_TOKEN=<DEEP_TOKEN_ID>

# Devnet Tokens Package (통합 토큰)
VITE_TOKENS_PACKAGE=<TOKENS_PACKAGE_ID>

# Token Types
VITE_NBTC_TYPE=<TOKENS_PACKAGE_ID>::nbtc::NBTC
VITE_NUSDC_TYPE=<TOKENS_PACKAGE_ID>::nusdc::NUSDC

# Trading Pools (생성 후 업데이트)
VITE_POOL_NBTC_NUSDC=<POOL_ID>
VITE_POOL_NASUN_NUSDC=<POOL_ID>

# Token Faucet
VITE_FAUCET_PACKAGE=<TOKENS_PACKAGE_ID>
VITE_TOKEN_FAUCET=<TOKEN_FAUCET_ID>
VITE_CLAIM_RECORD=<CLAIM_RECORD_ID>

# Prediction Market
VITE_PREDICTION_PACKAGE=<PREDICTION_PACKAGE_ID>
VITE_PREDICTION_GLOBAL_STATE=<GLOBAL_STATE_ID>
VITE_PREDICTION_ADMIN_CAP=<ADMIN_CAP_ID>
VITE_PREDICTION_RESOLVER_ADDRESS=<RESOLVER_ADDRESS>

# zkLogin
VITE_GOOGLE_CLIENT_ID=869935693878-o7ln8iu737ia6a6ujsfrjineh94k5ubh.apps.googleusercontent.com
VITE_ZKLOGIN_SALT_API_URL=https://ar4sxrde2c.execute-api.ap-northeast-2.amazonaws.com/prod/auth/zklogin/salt
VITE_ZKLOGIN_PROVER_URL=https://prover-dev.mystenlabs.com/v1
```

#### Nasun Website .env 파일

```bash
# Governance System
VITE_GOVERNANCE_API_URL=https://3n52syk380.execute-api.ap-northeast-2.amazonaws.com/prod
VITE_GOVERNANCE_PACKAGE_ID=<GOVERNANCE_PACKAGE_ID>
VITE_GOVERNANCE_DASHBOARD_ID=<DASHBOARD_ID>
VITE_PROPOSAL_TYPE_REGISTRY_ID=<TYPE_REGISTRY_ID>
VITE_SUI_RPC_URL=https://rpc.devnet.nasun.io

# Multi-token support
VITE_NBTC_TYPE=<TOKENS_PACKAGE_ID>::nbtc::NBTC
VITE_NUSDC_TYPE=<TOKENS_PACKAGE_ID>::nusdc::NUSDC
```

### 4.3 (레거시) 하드코딩된 상수 파일 업데이트

> **참고**: 이 파일들은 이미 `@nasun/devnet-config`를 사용하도록 마이그레이션되었습니다.
> 아래 내용은 참조용입니다.

#### prediction/constants.ts

```typescript
// 배포된 주소로 업데이트
export const PREDICTION_PACKAGE_ID = '<NEW_PACKAGE_ID>';
export const PREDICTION_ADMIN_CAP = '<NEW_ADMIN_CAP>';
export const PREDICTION_GLOBAL_STATE = '<NEW_GLOBAL_STATE>';
export const NUSDC_TYPE = '<NEW_TOKENS_PACKAGE>::nusdc::NUSDC';

// 생성된 마켓 ID로 업데이트
export const TEST_MARKETS: string[] = [
  '<MARKET_1_ID>',  // AI Market
  '<MARKET_2_ID>',  // Crypto Market
  '<MARKET_3_ID>',  // Sports Market
];
```

#### suiPackageConstants.ts

```typescript
export const NASUN_DEVNET_PACKAGE_ID = '<NEW_GOVERNANCE_PACKAGE>';
export const NASUN_DEVNET_DASHBOARD_ID = '<NEW_DASHBOARD_ID>';
export const NASUN_DEVNET_ADMIN_CAP = '<NEW_ADMIN_CAP>';
export const NASUN_DEVNET_UPGRADE_CAP = '<NEW_UPGRADE_CAP>';
export const NASUN_DEVNET_DELEGATION_REGISTRY_ID = '';  // TODO: 배포 필요시
```

---

## 5. 검증 체크리스트

### 5.1 네트워크 검증

- [ ] 2개 노드 모두 실행 중 (Node 1 validator+fullnode+faucet, Node 2 validator)
- [ ] Chain ID 확인 (`12bf3808` - V6)
- [ ] 체크포인트 진행 확인 (Node 1 RPC)
- [ ] HTTPS 엔드포인트 작동 (rpc.devnet.nasun.io, faucet.devnet.nasun.io)
- [ ] Faucet 작동 확인 (100 NSN 토큰)
- [ ] zkLogin 작동 확인

### 5.2 스마트 컨트랙트 검증

- [ ] Devnet Tokens 배포 완료 (packages/devnet-tokens)
- [ ] Token Faucet 작동 (NBTC, NUSDC 수령)
- [ ] DeepBook V3 배포 완료
- [ ] Prediction Market 배포 완료
- [ ] Governance 배포 완료
- [ ] Baram 배포 완료 (BaramRegistry)
- [ ] Baram Executor 배포 완료 (ExecutorRegistry)
- [ ] TEE Executor 등록 완료 (Optional - EC2 enclave 필요)

### 5.3 더미 데이터 검증

- [ ] Proposal 2개 이상 생성 (fee-based)
- [ ] Poll 2개 이상 생성 (sponsored)
- [ ] Dashboard에 모든 프로포절 등록
- [ ] Prediction Market 3개 이상 생성

### 5.4 Node 1 검증 (RPC/Faucet)

- [ ] nginx 정상 작동 (SSL/HTTPS)
- [ ] Fullnode가 validator와 동기화 완료
- [ ] Faucet 정상 작동 (`SUI_CONFIG_DIR` 및 keystore 경로 확인)

### 5.5 인프라 검증

- [ ] DB Pruning 설정 확인: `num-epochs-to-retain: 50` (양쪽 노드 validator.yaml + fullnode.yaml)
- [ ] Validator 시작 로그에서 pruning 동작 확인 (aggressive로 override 되는지)
- [ ] 디스크 모니터링 스크립트 정상 (`~/disk-monitor.sh`, 70/80/90% 단계별 알림)
- [ ] EBS 볼륨 크기 충분 (최소 100GB 권장, Validator+Fullnode 동시 운영 시)
- [ ] Security Group SSH IP 규칙 현재 IP 포함 확인
- [ ] `RUST_LOG=warn` 설정 확인 (모든 서비스)

### 5.6 프론트엔드 검증

- [ ] Pado 앱 개발 서버 실행 확인
- [ ] Nasun Website 개발 서버 실행 확인
- [ ] Baram 앱 개발 서버 실행 확인
- [ ] Prediction Market 목록 표시 확인
- [ ] Governance 프로포절 목록 표시 확인
- [ ] Baram Executor 목록 표시 확인 (TEE 등록 후)
- [ ] zkLogin 로그인 작동 확인

---

## 6. 빠른 참조

### 6.1 자주 사용하는 RPC 명령어

```bash
# Chain ID 확인
curl -s -X POST https://rpc.devnet.nasun.io \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getChainIdentifier","params":[]}' | jq -r '.result'

# 최신 체크포인트
curl -s -X POST https://rpc.devnet.nasun.io \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getLatestCheckpointSequenceNumber","params":[]}' | jq

# 객체 조회
curl -s -X POST https://rpc.devnet.nasun.io \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getObject","params":["<OBJECT_ID>",{"showContent":true}]}' | jq
```

### 6.2 트러블슈팅

| 문제 | 원인 | 해결 |
|------|------|------|
| 프론트엔드에서 데이터 안보임 | 환경변수 미업데이트 | .env 파일과 constants.ts 확인 |
| "Invalid Package" 에러 | Move.toml 미업데이트 | published-at, pado address 확인 |
| 마켓/프로포절 조회 실패 | Dashboard 미등록 | register_proposal 호출 확인 |
| zkLogin 실패 | Chain ID 불일치 | VITE_CHAIN_ID 확인 |
| Faucet "No managed addresses" | keystore 경로 불일치 | Node 1에서 SUI_CONFIG_DIR 확인 (6.3 참조) |
| Fullnode 동기화 안됨 | 설정 문제 | fullnode.yaml의 db-path 및 genesis 경로 확인 |
| 디스크 100% / 서비스 ABRT | DB 무제한 성장 | full_node_db 삭제 → 서비스 재시작 → EBS 확장 (OPERATIONS 5.10 참조) |
| Faucet "Failed to execute transaction" | Fullnode state 미동기화 | Fullnode 완전 동기화 대기 후 faucet 재시작 |
| `sui move build` "not present in Move.toml" | Sui 프레임워크 chain ID 불일치 | 아래 6.4 참조 |

### 6.3 Node 1 Faucet 설정 참고

Faucet은 `SUI_CONFIG_DIR` 환경변수로 설정 디렉토리를 찾습니다.
`client.yaml` 내부의 keystore 경로가 실제 파일과 일치해야 합니다.

```bash
# Node 1에서 확인 (SSH: ssh ubuntu@3.38.127.23)
cat ~/.sui/sui_config/client.yaml | grep keystore
# keystore 경로가 ~/.sui/sui_config/sui.keystore인지 확인
```

### 6.4 Sui 프레임워크 Chain ID 불일치 문제

**증상**: `sui move build`가 다음 에러로 실패:
```
Your active environment `devnet` is not present in `Move.toml`, so you cannot publish to `devnet`.
```

패키지 Move.toml에 `[environments] devnet = "<CHAIN_ID>"`가 올바르게 설정되어 있어도 발생한다.

**원인**: Sui CLI v1.63+ 부터 새로운 패키지 관리 시스템(`move-package-alt`)이 도입되었다.
이 시스템은 Move.toml을 `ParsedManifest` 스키마로 파싱하는데, old-style Move.toml
(`[addresses]`, `[dev-dependencies]` 등 포함)은 `deny_unknown_fields` 제약으로 인해
파싱이 실패한다. 실패 시 환경 정보가 로드되지 않아 위 에러가 발생한다.

추가로, Sui 바이너리를 리빌드하면 프레임워크의 `[environments]` chain ID가
upstream 기본값으로 초기화되어 Nasun devnet chain ID와 불일치할 수 있다.

**해결 방법**:

1. **프레임워크 Move.toml chain ID 수정** (리빌드 후 필수):
```bash
# 현재 chain ID 확인
sui client chain-identifier

# 프레임워크 Move.toml 업데이트
# sui-framework/Move.toml과 move-stdlib/Move.toml의 [environments] 섹션을
# Nasun devnet chain ID로 수정
vi nasun-devnet/sui/crates/sui-framework/packages/sui-framework/Move.toml
vi nasun-devnet/sui/crates/sui-framework/packages/move-stdlib/Move.toml
```

2. **빌드 시 `test-publish --build-env` 사용** (워크어라운드):
```bash
# sui move build 대신 사용
sui client test-publish <PACKAGE_PATH> \
  --build-env devnet \
  --gas-budget 100000000 \
  --dry-run

# 실제 배포 시
sui client test-publish <PACKAGE_PATH> \
  --build-env devnet \
  --gas-budget 100000000
```

**참고**: 향후 Sui CLI가 new-style Move.toml 포맷으로 완전히 전환되면
old-style `[addresses]` 섹션을 사용하는 기존 컨트랙트들의 마이그레이션이 필요하다.

### 6.5 관련 문서

- [NASUN_DEVNET_RESET_GUIDE.md](./NASUN_DEVNET_RESET_GUIDE.md) - Genesis 리셋 절차
- [NASUN_DEVNET_OPERATIONS.md](./NASUN_DEVNET_OPERATIONS.md) - 운영 가이드
- [EXECUTION_COMPLIANCE_RECORD.md](../../my_apps/nasun-monorepo/apps/baram/docs/EXECUTION_COMPLIANCE_RECORD.md) - Baram ECR 설계

---

**Document Version**: 3.1.0
**Last Updated**: 2026-01-27
