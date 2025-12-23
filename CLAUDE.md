# CLAUDE.md

이 파일은 Claude Code가 이 저장소에서 작업할 때 필요한 지침을 제공합니다.

## 언어 설정

**모든 응답과 사고는 한국어로 진행합니다.** 코드 주석, 커밋 메시지, 문서 작성 시에도 한국어를 사용합니다.

## Project Overview

**Nasun Devnet**은 개발 및 테스트 목적의 SUI 블록체인 포크 네트워크입니다.

| Spec | Value |
|------|-------|
| Network Name | Nasun Devnet |
| Chain ID | `33a8f3c5` |
| Native Token | NASUN (최소단위: SOE) |
| Consensus | Narwhal/Bullshark (SUI default) |
| Validators | 2 nodes (EC2 c6i.xlarge) |
| RPC Endpoint (HTTPS) | https://rpc.devnet.nasun.io |
| RPC Endpoint (HTTP) | http://3.38.127.23:9000 |
| Faucet (HTTPS) | https://faucet.devnet.nasun.io |
| Faucet (HTTP) | http://3.38.127.23:5003 |
| Explorer | https://explorer.devnet.nasun.io |
| Epoch Duration | 60초 |

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

| 항목 | 값 |
|------|-----|
| GitHub 레포 | https://github.com/narunice/nasun-sui-devnet-fork (Private) |
| origin | `git@github.com:narunice/nasun-sui-devnet-fork.git` |
| upstream | `https://github.com/MystenLabs/sui.git` (원본 SUI) |
| 브랜치 | `devnet` |

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

| File | Changes |
|------|---------|
| `crates/sui-config/src/genesis_config.rs` | Chain ID, epoch duration, token supply |
| `crates/sui-types/src/lib.rs` | Network identifier |
| `crates/sui-config/src/node.rs` | Default path `~/.sui` → `~/.nasun` |
| `crates/sui/src/client_commands.rs` | CLI output messages |
| `crates/sui-json-rpc/src/lib.rs` | RPC version info |

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

## Genesis Parameters (Devnet Defaults)

```rust
DEFAULT_EPOCH_DURATION_MS: u64 = 60_000;           // 1 minute
TOTAL_SUPPLY_NASUN: u64 = 10_000_000_000_000_000_000;  // 10B NASUN
MIN_VALIDATOR_STAKE: u64 = 1_000_000_000;          // 1 NASUN
DEFAULT_GAS_PRICE: u64 = 1000;
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

## 배포된 스마트 컨트랙트

| 컨트랙트 | Package ID | 설명 |
|---------|------------|------|
| hello_nasun | `0x50023dcd6281f8e3836dcd05482e3df40d1c7f59fb4f00e9a3ca8b7fcb4debda` | 테스트용 Greeting 컨트랙트 |

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

| 노드 | IP | 역할 | 인스턴스 타입 |
|------|-----|------|--------------|
| nasun-node-1 | 3.38.127.23 | Validator + Fullnode (RPC) + Faucet | c6i.xlarge |
| nasun-node-2 | 3.38.76.85 | Validator | c6i.xlarge |

```bash
# Node 1 (주 노드) 접속
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.127.23

# Node 2 접속
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.76.85
```

## systemd 서비스 관리

EC2 서버에서 노드는 systemd 서비스로 관리됩니다.

| 서비스 | 설명 | 포트 |
|--------|------|------|
| `nasun-validator` | Validator 노드 | 8080, 8084 |
| `nasun-fullnode` | Fullnode (RPC 서비스) | 9000 |
| `nasun-faucet` | Faucet 서비스 | 5003 |

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

SUI 노드는 기본적으로 INFO 레벨 로그를 대량 생성합니다 (약 3.4GB/일).
**RUST_LOG=warn** 환경변수로 로그량을 99% 이상 줄일 수 있습니다.

systemd 서비스 설정 (`/etc/systemd/system/nasun-fullnode.service`):

```ini
[Service]
Environment="RUST_LOG=warn"
ExecStart=/home/ubuntu/sui-node --config-path fullnode.yaml
Restart=always
RestartSec=10
```

logrotate 설정 (`/etc/logrotate.d/rsyslog`):
- 일간 로테이션
- 최대 500MB 제한
- 3개 보관

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

| 프로젝트 | 경로/URL | 설명 |
|---------|----------|------|
| nasun-sui-devnet-fork | https://github.com/narunice/nasun-sui-devnet-fork | SUI 포크 코드 (Private) |
| nasun-website | `../nasun-apps/nasun-website` | Nasun 공식 웹사이트 |
| nasun-explorer | `../nasun-explorer` | Nasun 블록 탐색기 |
| nasun-sui-contracts | `../nasun-contracts/nasun-sui-contracts` | Nasun 스마트 컨트랙트 |

### 주요 문서 참조

- [NASUN_DEVNET_SETUP_PLAN.md](doc/NASUN_DEVNET_SETUP_PLAN.md) - Devnet 구축 계획서
- [NASUN_DEVNET_NEXT_STEPS.md](doc/NASUN_DEVNET_NEXT_STEPS.md) - 다음 단계 계획서 (Phase 7-9)
- [NASUN_DEVNET_OPERATIONS.md](doc/NASUN_DEVNET_OPERATIONS.md) - 운영 가이드 (문제 해결 사례 포함)
