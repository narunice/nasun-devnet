# CLAUDE.md

이 파일은 Claude Code가 이 저장소에서 작업할 때 필요한 지침을 제공합니다.

## Claude Persona & Operating Principles

You are operating as a senior-level infrastructure engineer, blockchain protocol specialist,
and DevOps expert supporting this Nasun Devnet repository.

You are expected to think across:

- Network stability and fault tolerance
- Rust/Sui codebase modifications
- Infrastructure automation and monitoring
- Security and adversarial environments

Your default stance is:

- Production-grade quality only
- Security-first, correctness over convenience
- Clarity, explicitness, and determinism over cleverness
- Real failures and incident response, not theoretical examples

---

### Language Rules

- Responses and reasoning: Korean
- Code comments: English
- Commit messages: English (Conventional Commits)
- Date/time format: ISO 8601 or `date.toLocaleString('en-US')`

---

### Engineering Principles

- Read before write: always read files before modifying
- No over-engineering: implement only what is requested
- Prefer editing existing files over creating new ones
- Maintain simplicity: minimal complexity to solve the task
- No backwards-compatibility hacks: if unused, delete completely

Security expectations:

- Security-first mindset is mandatory
- Node configuration changes can expose the network
- Always verify service status after changes
- Never expose private keys or sensitive credentials

---

### Tooling Rules (Claude Code)

- Use dedicated tools (Read, Edit, Write, Glob, Grep) instead of raw Bash
- Run independent tool calls in parallel when possible
- Actively use TodoWrite for planning and progress tracking
- Use Task tool with subagent_type=Explore when exploring the codebase

---

### Git & GitHub Rules

- Do not create commits unless explicitly requested
- Never push without explicit instruction
- Commit messages: Conventional Commits (feat, fix, chore, docs, etc.)
- Example: `docs: update V5 reset documentation`
- Include co-author line:
  `Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>`

---

### Communication Style

- Be concise and CLI-friendly
- Do not use emojis unless explicitly requested
- Avoid emotional language or excessive praise
- Do not estimate time or propose schedules
- Explain reasoning when it affects network stability or security

---

### Blockchain Infrastructure Context

- Assume deep familiarity with:
  - Sui / Move (consensus, validators, fullnodes)
  - Genesis configuration and network parameters
  - systemd service management
  - AWS EC2, Security Groups, SNS alerts
  - Disk management and log rotation
  - zkLogin prover compatibility

- Infrastructure changes are security-critical by default
- Both validators must run identical genesis for consensus
- Single node failure halts the 2-node devnet

---

## Project Overview

**Nasun Devnet**은 개발 및 테스트 목적의 SUI 블록체인 포크 네트워크입니다.

| Spec                 | Value                             |
| -------------------- | --------------------------------- |
| Network Name         | Nasun Devnet                      |
| Chain ID             | `12bf3808` (2026-01-27 V6 리셋)   |
| Native Token         | NSN (최소단위: SOE)               |
| Total Supply         | 10,000,000,000 NSN (100억)        |
| Consensus            | Narwhal/Bullshark (SUI default)   |
| Validators           | 2 nodes (EC2 c6i.xlarge)          |
| RPC Endpoint (HTTPS) | https://rpc.devnet.nasun.io       |
| RPC Endpoint (HTTP)  | http://3.38.127.23:9000           |
| Faucet (HTTPS)       | https://faucet.devnet.nasun.io    |
| Faucet (HTTP)        | http://3.38.127.23:5003           |
| Faucet Amount        | 100 NSN/요청 (20×5개 코인)        |
| Explorer             | https://explorer.devnet.nasun.io  |
| Epoch Duration       | 2시간 (7,200,000ms)               |
| DB Pruning           | 50 epochs (~4일 보관)             |
| Fork Source          | Sui mainnet v1.63.3 (2026-01-27)  |
| zkLogin              | ✅ 지원 (prover-dev 호환)         |
| Auto Recovery        | ✅ CloudWatch 알람 (양 노드)      |
| SNS Alerts           | nasun-devnet-alerts → naru@nasun.io |

### 나선 프로젝트 전체 구성

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Nasun Project                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  nasun-website             nasun-devnet           nasun-explorer    │
│  ─────────────────        ─────────────────      ─────────────────  │
│  공식 웹사이트              블록체인 노드           블록 탐색기        │
│  • 리더보드                 • SUI 포크             • TX/Block 조회    │
│  • NFT 이벤트               • 2노드 Validator      • 주소/객체 조회   │
│  • OAuth 인증               • Faucet 서비스        • 네트워크 상태    │
│  • MetaMask 연동            • 스마트 컨트랙트      • 검색 기능        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Repository Structure

```
nasun-devnet/
├── doc/                    # Planning and documentation
│   └── NASUN_DEVNET_SETUP_PLAN.md  # Master setup guide
├── sui/                    # SUI fork code (별도 GitHub 레포)
├── genesis/                # Genesis files
├── configs/                # Node configuration files
└── scripts/                # Automation scripts
```

## SUI Fork GitHub 레포지토리

`sui/` 폴더는 별도의 GitHub 레포지토리로 관리됩니다.

| 항목        | 값                                                          |
| ----------- | ----------------------------------------------------------- |
| GitHub 레포 | https://github.com/narunice/nasun-sui-devnet-fork (Private) |
| origin      | `git@github.com:narunice/nasun-sui-devnet-fork.git`         |
| upstream    | `https://github.com/MystenLabs/sui.git` (원본 SUI)          |
| 브랜치      | `devnet`                                                    |

### sui 폴더 Git 사용법

```bash
cd /home/naru/my_apps/nasun-devnet/sui

# 코드 수정 후 푸시
git add .
git commit -m "변경사항 설명"
git push origin devnet

# 원본 SUI 업데이트 받기
git fetch upstream
git merge upstream/devnet

# remote 확인
git remote -v
# origin    git@github.com:narunice/nasun-sui-devnet-fork.git (fetch/push)
# upstream  https://github.com/MystenLabs/sui.git (fetch/push)
```

**참고**: `nasun-devnet` 레포의 `.gitignore`에서 `sui/` 폴더를 무시하므로, 두 레포는 독립적으로 관리됩니다.

## Claude Code Responsibilities

Claude Code is designated for:

- **Rust code analysis** - Deep analysis of SUI codebase
- **Consensus logic modifications** - Narwhal/Bullshark adjustments
- **Genesis parameter tuning** - Epoch duration, token supply, gas prices
- **Complex type system understanding** - SUI's Rust type system

## Key Files to Modify in SUI Fork

When forking SUI, these files require Nasun branding changes:

| File                                      | Changes                                |
| ----------------------------------------- | -------------------------------------- |
| `crates/sui-config/src/genesis_config.rs` | Chain ID, epoch duration, token supply |
| `crates/sui-types/src/lib.rs`             | Network identifier                     |
| `crates/sui-config/src/node.rs`           | Default path `~/.sui` → `~/.nasun`     |
| `crates/sui/src/client_commands.rs`       | CLI output messages                    |
| `crates/sui-json-rpc/src/lib.rs`          | RPC version info                       |

## Build Commands

```bash
# Check dependencies
cargo check

# Release build (20-40 min)
cargo build --release

# Build artifacts location
target/release/sui
target/release/sui-node
target/release/sui-tool
target/release/sui-faucet
```

## Genesis Parameters (V5 Devnet)

```rust
DEFAULT_EPOCH_DURATION_MS: u64 = 7_200_000;        // 2 hours (V5)
TOTAL_SUPPLY_NSN: u64 = 10_000_000_000_000_000_000;  // 10B NSN
MIN_VALIDATOR_STAKE: u64 = 1_000_000_000;          // 1 NSN
DEFAULT_GAS_PRICE: u64 = 1000;
NUM_EPOCHS_TO_RETAIN: u64 = 50;                    // ~4 days pruning
```

## Local Testing

```bash
# Generate genesis
./target/release/sui genesis --force

# Start single node
./target/release/sui start --network.config ~/.nasun/network.yaml

# Test RPC
curl -X POST http://localhost:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getChainIdentifier","params":[]}'
```

## 배포된 스마트 컨트랙트 (V6)

**배포 Admin 주소**: `0xe1c4c90bd18d22d5d8fbc9ab7994bdcf1ac717714c0f5375528c229d6dfb3d90`

### Devnet Tokens (통합 토큰)

> 모든 나선 앱 (Pado, Baram 등)에서 공용으로 사용하는 NBTC/NUSDC 토큰 패키지.
> 소스: `nasun-monorepo/packages/devnet-tokens/`

| 항목 | Object ID |
|------|-----------|
| **Package** | `0x10748ed4f5063ca4a564fdfecc289954d14efa1a209e7292dcc18d65b2cb4017` |
| TokenFaucet | `0x04aa41442a9b812d29bb578aa82358d2b9e678240814368e32d82efa79669e14` |
| ClaimRecord | `0x8b9e854509c950d01ccd37190ba967e2de2197908f5c164f7cc193714faac4a8` |
| UpgradeCap | `0x2017d606c566ff13cbaf23bf18b5e413b95bb9bcd333c2f413878e7ddddf2a87` |
| NBTC Type | `0x10748ed4f5063ca4a564fdfecc289954d14efa1a209e7292dcc18d65b2cb4017::nbtc::NBTC` |
| NUSDC Type | `0x10748ed4f5063ca4a564fdfecc289954d14efa1a209e7292dcc18d65b2cb4017::nusdc::NUSDC` |

### DeepBook V3

| 항목 | Object ID |
|------|-----------|
| Token Package | `0xce8405a3c3c07325379f3977b3425c92ffd80bdef3ca83205fb88700541987fd` |
| **DeepBook Package** | `0xaad9b8cfa778a3d4f2e28c6e07073d9627a85a2e7d6dfc33136f527450606253` |
| Registry | `0x2c386b2a2b8b5756ec316a309208d937b6907d97fbacfaa87fd514894aded384` |
| DeepbookAdminCap | `0x413ace0602b7f0ec502d53c84aadd41763e1d79b35bfd382ef3ae9c0e7689262` |

> **주의**: DeepBook V3 패키지 배포 시 약 580 NSN 가스 필요 (가스 코인 사전 병합 필수)

### Prediction Market

| 항목 | Object ID |
|------|-----------|
| **Package** | `0x8c9423b4e64ee673171e46a21f0d41b9d58f67afecda23caf010bca78be05f0b` |
| AdminCap | `0x5bca34f1f7ce08aa1a65aac760d3f50dbc920d71d73f1b2dd04545955968dc0b` |
| GlobalState | `0x80d04dfe103eb168769d0d2a2a14cf06ec4b41aed8b53cff5751d471c742245e` |

### Governance

| 항목 | Object ID |
|------|-----------|
| **Package** | `0x02daf1f825b3eaae3b2f0718e7cbab884dc58d1b740c594f505004607b04e516` |
| Dashboard | `0x3398b1931bc8c418b0e0e1d9c1e04537bfc82c3f85d4dc22e11c97469baee7ae` |
| AdminCap | `0xd96d14baf4422909e6721c5533d981f0a481b947989c95502d3a45f89f607a04` |

## RPC 테스트 명령어

```bash
# Chain ID 확인
curl -X POST http://3.38.127.23:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getChainIdentifier","params":[]}'

# 최신 체크포인트
curl -X POST http://3.38.127.23:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getLatestCheckpointSequenceNumber","params":[]}'

# 총 트랜잭션 수
curl -X POST http://3.38.127.23:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getTotalTransactionBlocks","params":[]}'

# Faucet 토큰 요청
curl -X POST http://3.38.127.23:5003/gas \
  -H "Content-Type: application/json" \
  -d '{"FixedAmountRequest":{"recipient":"<YOUR_ADDRESS>"}}'
```

## CLI 사용법 (nasun alias)

로컬에서 Nasun Devnet CLI를 사용하려면:

```bash
# ~/.bashrc에 alias가 설정된 경우
nasun client gas          # 잔액 확인
nasun client objects      # 소유 객체 확인
nasun client tx-block <TX_DIGEST>  # 트랜잭션 조회

# 환경 전환
nasun client switch --env nasun-devnet

# Chain ID 확인
nasun client chain-identifier
# 출력: 33a8f3c5
```

## SUI Wallet 연동

SUI Wallet에서 Nasun Devnet을 커스텀 네트워크로 추가:

```
Settings → Network → Custom RPC URL
- Network Name: Nasun Devnet
- RPC URL: https://rpc.devnet.nasun.io
```

## EC2 인프라 및 SSH 접속

| 노드         | IP          | 역할                                | 인스턴스 타입 |
| ------------ | ----------- | ----------------------------------- | ------------- |
| nasun-node-1 | 3.38.127.23 | Validator + Fullnode (RPC) + Faucet | c6i.xlarge    |
| nasun-node-2 | 3.38.76.85  | Validator                           | c6i.xlarge    |

```bash
# Node 1 (주 노드) 접속
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.127.23

# Node 2 접속
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.76.85
```

## systemd 서비스 관리

EC2 서버에서 노드는 systemd 서비스로 관리됩니다.

| 서비스            | 설명                  | 포트       |
| ----------------- | --------------------- | ---------- |
| `nasun-validator` | Validator 노드        | 8080, 8084 |
| `nasun-fullnode`  | Fullnode (RPC 서비스) | 9000       |
| `nasun-faucet`    | Faucet 서비스         | 5003       |

```bash
# 서비스 상태 확인
sudo systemctl status nasun-validator nasun-fullnode nasun-faucet

# 서비스 재시작
sudo systemctl restart nasun-validator nasun-fullnode

# 서비스 로그 확인
sudo journalctl -u nasun-fullnode -f
```

**중요**: 노드는 반드시 systemd 서비스로 관리해야 합니다. 수동 실행 시 서비스와 충돌합니다.

## 로그 관리

> ⚠️ **CRITICAL**: 2026-01-04에 RUST_LOG=debug 설정으로 인해 37GB syslog가 생성되어
> 디스크 100% 사용으로 노드가 다운되었습니다. **절대로 debug/trace 레벨로 변경하지 마세요!**

SUI 노드는 기본적으로 INFO 레벨 로그를 대량 생성합니다 (약 3.4GB/일).
**RUST_LOG=warn** 환경변수로 로그량을 99% 이상 줄일 수 있습니다.

**모든 서비스에 RUST_LOG=warn 필수:**

```bash
# 확인
grep RUST_LOG /etc/systemd/system/nasun-*.service
# 모두 warn이어야 함!
```

systemd 서비스 설정 (`/etc/systemd/system/nasun-*.service`):

```ini
[Service]
Environment="RUST_LOG=warn"
ExecStart=/home/ubuntu/sui-node --config-path fullnode.yaml
Restart=always
RestartSec=10
```

logrotate 설정 (`/etc/logrotate.d/rsyslog`):

- 일간 로테이션
- 최대 100MB 제한 (maxsize 100M)
- 3개 보관

디스크 모니터링:

- `~/disk-monitor.sh` (매시간 실행)
- 80% 초과 시 SNS 알림

## 2-Node Consensus Notes

- Minimum viable for Devnet (f=0 Byzantine fault tolerance)
- Both nodes must be running for consensus to proceed
- Single node failure halts the network
- Upgrade to 4+ nodes for production fault tolerance

## nginx CORS 설정

EC2 서버 (3.38.127.23)의 nginx 설정 파일: `/etc/nginx/sites-available/nasun-devnet`

SUI SDK가 사용하는 커스텀 헤더들을 허용하기 위해 CORS 설정이 필요합니다:

```nginx
# RPC 엔드포인트 CORS 설정
proxy_hide_header Access-Control-Allow-Origin;
proxy_hide_header Access-Control-Allow-Methods;
proxy_hide_header Access-Control-Allow-Headers;

add_header Access-Control-Allow-Origin * always;
add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
add_header Access-Control-Allow-Headers "*" always;
```

**주의**: 백엔드(SUI RPC)도 CORS 헤더를 추가하므로 `proxy_hide_header`로 중복을 방지해야 합니다.

## 관련 프로젝트

| 프로젝트              | 경로/URL                                          | 설명                    |
| --------------------- | ------------------------------------------------- | ----------------------- |
| nasun-sui-devnet-fork | https://github.com/narunice/nasun-sui-devnet-fork | SUI 포크 코드 (Private) |
| nasun-website         | `../nasun-apps/nasun-website`                     | Nasun 공식 웹사이트     |
| nasun-explorer        | `../nasun-explorer`                               | Nasun 블록 탐색기       |
| nasun-sui-contracts   | `../nasun-contracts/nasun-sui-contracts`          | Nasun 스마트 컨트랙트   |
| pado                  | `../nasun-apps/pado`                              | Pado 통합 금융 앱 (DEX) |

### 주요 문서 참조

- [NASUN_DEVNET_SETUP_PLAN.md](doc/NASUN_DEVNET_SETUP_PLAN.md) - Devnet 구축 계획서
- [NASUN_DEVNET_NEXT_STEPS.md](doc/NASUN_DEVNET_NEXT_STEPS.md) - 다음 단계 계획서 (Phase 7-9)
- [NASUN_DEVNET_OPERATIONS.md](doc/NASUN_DEVNET_OPERATIONS.md) - 운영 가이드 (문제 해결 사례 포함)

---

## Nasun Devnet V3 리셋 (2025-12-25)

**작업일**: 2025-12-25
**상태**: ✅ 네트워크 운영 중
**Fork 소스**: Sui mainnet v1.63.0 (최신 HEAD)

### 리셋 목적

이전 V2 기반 Devnet에서 발생한 동기화 문제 해결 및 최신 Sui 기능 반영을 위해
완전히 새로운 Genesis로 네트워크를 리셋했습니다.

### 현재 상태

| 항목 | 값 |
|------|-----|
| Chain ID | `6681cdfd` |
| Fork 소스 | Sui mainnet v1.63.0 |
| 노드 상태 | 2노드 합의 정상 |
| RPC | ✅ 정상 (Fullnode) |
| Faucet | ✅ 정상 (100 NASUN/요청) |

### DeepBook 상태

**중요**: 최신 Sui mainnet에서 DeepBook V2가 deprecated 되어 모든 핵심 함수가
`abort 1337`로 비활성화되어 있습니다.

Pado DEX를 위한 옵션:
1. **V2 복원**: pre-deprecation 커밋에서 DeepBook 파일 cherry-pick
2. **V3 배포**: DeepBook V3를 별도 스마트 컨트랙트로 배포

### 현재 운영 상태 확인

```bash
# 네트워크 상태 확인
curl -X POST http://3.38.127.23:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getChainIdentifier","params":[]}'
# 결과: 6681cdfd

# 최신 체크포인트
curl -X POST http://3.38.127.23:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getLatestCheckpointSequenceNumber","params":[]}'

# Faucet 테스트 (100 NASUN 지급)
curl -X POST http://3.38.127.23:5003/gas \
  -H "Content-Type: application/json" \
  -d '{"FixedAmountRequest":{"recipient":"<YOUR_ADDRESS>"}}'
```

### systemd 서비스 (Node 1)

| 서비스 | 설명 | 상태 |
|--------|------|------|
| `nasun-validator` | Validator 노드 | ✅ 실행 중 |
| `nasun-fullnode` | Fullnode (RPC) | ✅ 실행 중 |
| `nasun-faucet` | Faucet 서비스 | ✅ 실행 중 |

### 제네시스 재생성 절차 (참고용)

```bash
# Node 1 (3.38.127.23)에서 실행
sudo systemctl stop nasun-validator nasun-fullnode nasun-faucet
rm -rf ~/authorities_db ~/consensus_db ~/full_node_db ~/.nasun

# 올바른 IP로 genesis 생성
./sui genesis --force --epoch-duration-ms 60000 --committee-size 2 \
  --benchmark-ips 3.38.127.23 3.38.76.85 --with-faucet

# Fullnode config 수정 (0.0.0.0 바인딩)
sed -i 's|network-address: /ip4/127.0.0.1|network-address: /ip4/0.0.0.0|g' ~/.nasun/nasun_config/fullnode.yaml
sed -i 's|listen-address: "127.0.0.1|listen-address: "0.0.0.0|g' ~/.nasun/nasun_config/fullnode.yaml

# Validator config 수정 (EC2 NAT 대응)
sed -i 's|network-address: /ip4/3.38.127.23|network-address: /ip4/0.0.0.0|' ~/.nasun/nasun_config/3.38.127.23-*.yaml

# Node 2로 genesis 및 설정 복사
scp ~/.nasun/nasun_config/genesis.blob ubuntu@3.38.76.85:~/.nasun/nasun_config/
scp ~/.nasun/nasun_config/3.38.76.85-*.yaml ubuntu@3.38.76.85:~/validator.yaml

# 서비스 시작
sudo systemctl start nasun-validator nasun-fullnode nasun-faucet
```

**주의사항**:
- 두 노드가 완벽히 동일한 `genesis.blob`을 가져야 함 (Split Brain 방지)
- EC2에서는 외부 IP로 바인딩 불가 → 0.0.0.0 사용 필수
- Fullnode와 Validator는 별도 프로세스로 실행
- Faucet은 `SUI_CONFIG_DIR` 환경변수로 설정 디렉토리 지정

---

## Nasun Devnet V4 리셋 (2026-01-02)

**작업일**: 2026-01-02
**상태**: ✅ 네트워크 운영 중
**Fork 소스**: Sui mainnet v1.62.1

### 리셋 목적

zkLogin의 "Invalid signature" 에러 해결:
- prover-dev (Mysten Labs)가 업데이트된 proving key 사용
- 이전 V3 (v1.63.0 커스텀)는 outdated verifying key 사용
- 수학적 불일치로 ZK 증명 검증 실패

### V4 변경 사항

| 항목 | V3 (이전) | V4 (현재) |
|------|-----------|-----------|
| Chain ID | `6681cdfd` | `4c879694` |
| Fork Source | v1.63.0 커스텀 | v1.62.1 mainnet |
| zkLogin | ❌ 불가 | ✅ 정상 |
| Config 경로 | `~/.nasun/nasun_config/` | `~/.sui/sui_config/` (symlink) |

### 배포된 컨트랙트 (V4)

| 컨트랙트 | Object ID |
|----------|-----------|
| pado_tokens Package | `0x7d943e0325ce288eb5faf6c68b35a51227890787762cb2f21072460a34097bfd` |
| TokenFaucet | `0xcef1706aa2907d92c170f052528e9255389da1a8210e25e361c0e810c34ba9f4` |
| ClaimRecord | `0x7a0a164d3b115be35e40604dff322de5eb2468fa6deaec411d990066ac7e4326` |
| NBTC Type | `0x7d943e...::nbtc::NBTC` |
| NUSDC Type | `0x7d943e...::nusdc::NUSDC` |

### V4 Genesis 생성 절차

```bash
# 1. 새 바이너리 빌드 (v1.62.1)
cd /home/naru/my_apps/nasun-devnet/sui
git checkout nasun-v4-mainnet-1.62.1
cargo build --release

# 2. 바이너리 배포
scp target/release/sui-node ubuntu@3.38.127.23:~/
scp target/release/sui-node ubuntu@3.38.76.85:~/
scp target/release/sui ubuntu@3.38.127.23:~/
scp target/release/sui-faucet ubuntu@3.38.127.23:~/

# 3. Genesis 생성 (Node 1에서)
./sui genesis --force --epoch-duration-ms 60000 --committee-size 2 \
  --benchmark-ips 3.38.127.23 3.38.76.85 --with-faucet

# 4. Symlink 생성 (backward compatibility)
mkdir -p ~/.nasun
ln -s ~/.sui/sui_config ~/.nasun/nasun_config

# 5. Config 수정 후 서비스 시작
```

### 리셋 가이드 문서

상세한 리셋 절차: `doc/NASUN_DEVNET_V4_RESET.md`

---

## Nasun Devnet V5 리셋 (2026-01-17)

**작업일**: 2026-01-17
**상태**: ✅ 네트워크 운영 중
**Fork 소스**: Sui mainnet v1.63.3

### 리셋 목적

안정적인 장기 운영을 위한 네트워크 리셋:
- Epoch duration 2시간으로 변경 (DB 증가 속도 120배 감소)
- DB Pruning 50 epochs 설정 (~4일 보관)
- Native Token 브랜딩 변경 (NASUN → NSN)

### V5 변경 사항

| 항목 | V4 (이전) | V5 (현재) |
|------|-----------|-----------|
| Chain ID | `4c879694` | `56c8b101` |
| Fork Source | v1.62.1 | v1.63.3 mainnet |
| Native Token | NASUN | **NSN** |
| Epoch Duration | 1분 | **2시간** |
| DB Pruning | 비활성화 | **50 epochs** |
| zkLogin | ✅ 정상 | ✅ 정상 |

### 배포된 컨트랙트 (V5)

| 컨트랙트 | Object ID |
|----------|-----------|
| **Pado Tokens Package** | `0xc84727af62147f35ccf070f521e441f48be9325ab0a1b56225f361f0bc266bb8` |
| TokenFaucet | `0xd8722be320d057f7f47aa562f3d54f2e4bc51ea6a53cc05972940640d4f81708` |
| ClaimRecord | `0x563fc1bb0e65babac3e34b698676c207b1f2b59c2b3e8feb5c230dab1809e689` |
| NBTC Type | `0xc84727af...::nbtc::NBTC` |
| NUSDC Type | `0xc84727af...::nusdc::NUSDC` |
| **DeepBook V3 Package** | `0x379b630c75bada9c10e5f0f0abc76d0462a57ce121430359ecd0c5dc34a01056` |
| Registry | `0xf2126547e61cccb012fa6f172ec81cc5278954492bc1c474848202f262953042` |
| DeepbookAdminCap | `0x1510af43a65685d53c66a835d1e53cc6e641fe568c39cce0b6f0d08ca012bf4b` |
| **Governance Package** | `0xa4636c566d7d06bcb3802e248390007a09fb78837349bce3cb71eadd905937cf` |
| Dashboard | `0x542142dcf283834783cbf75e4b2e5bd32458a02171232738638b86de386acd0d` |
| AdminCap | `0xbce95269bbf47f09a2980fd46ee40185c812b6f4088caf9ca70cbe2e5f9f76e2` |
| ProposalTypeRegistry | `0x4da0ef1eb2cfd06970ceebcc9524d3819b0c5174eca18af1090338b25d4de756` |
| Dummy Proposal | `0x464be9dc8261414b32681cf4944cae1a6f14ff38094340a5a0967885e5f76f61` |

### V5 Genesis 생성 절차

```bash
# 1. 새 바이너리 빌드 (v1.63.3)
cd /home/naru/my_apps/nasun-devnet/sui
git fetch upstream --tags
git checkout -b nasun-v5-mainnet-1.63.3 mainnet-v1.63.3
cargo build --release

# 2. Genesis 생성 (2시간 epoch)
./sui genesis --force --epoch-duration-ms 7200000 --committee-size 2 \
  --benchmark-ips 3.38.127.23 3.38.76.85 --with-faucet

# 3. Pruning 설정 추가 (fullnode.yaml, validator.yaml)
# authority-store-pruning-config:
#   num-epochs-to-retain: 50

# 4. Config 수정 및 서비스 시작
```

### 리셋 가이드 문서

상세한 리셋 절차: `doc/NASUN_DEVNET_V5_RESET.md` (참조: `.claude/plans/lively-swimming-shell.md`)

---

## Nasun Devnet V6 리셋 (2026-01-27)

**작업일**: 2026-01-27
**상태**: ✅ 네트워크 운영 중
**Fork 소스**: Sui mainnet v1.63.3

### 리셋 목적

2-node 아키텍처로 전환하여 비용 절감 및 안정성 확보:
- Node 3 (Fullnode 전용) 제거하고 Node 1에서 Fullnode 운영
- 월 비용 $180 → $120 절감
- 이전 네트워크 합의 오류로 인한 완전 리셋

### V6 변경 사항

| 항목 | V5 (이전) | V6 (현재) |
|------|-----------|-----------|
| Chain ID | `56c8b101` | `12bf3808` |
| 아키텍처 | 3-node | **2-node** |
| Node 1 역할 | Validator | **Validator + Fullnode + Faucet** |
| Node 3 | Fullnode + Faucet | **제거** |
| 월 비용 | ~$180 | **~$120** |

### 배포된 컨트랙트 (V6)

| 컨트랙트 | 상태 |
|----------|------|
| Pado Tokens | 재배포 필요 |
| DeepBook V3 | 재배포 필요 |
| Governance | 재배포 필요 |

### 아키텍처 (2-node)

| 노드 | IP | 역할 |
|------|-----|------|
| nasun-node-1 | 3.38.127.23 | Validator + Fullnode + Faucet + nginx |
| nasun-node-2 | 3.38.76.85 | Validator |
