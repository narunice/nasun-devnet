# Nasun Devnet 다음 단계 계획서

**Version**: 1.2.0
**Created**: 2025-12-13
**Updated**: 2025-12-14
**Author**: Claude Code
**Status**: Phase 7-8 완료, Phase 9 진행 예정
**Prerequisites**: Nasun Devnet 운영 중 (Phase 1-6 완료)

---

## 목차

1. [개요](#1-개요)
2. [Phase 7: 토큰 전송 테스트](#2-phase-7-토큰-전송-테스트)
3. [Phase 8: Faucet 구축](#3-phase-8-faucet-구축)
4. [Phase 9: 스마트 컨트랙트 배포](#4-phase-9-스마트-컨트랙트-배포)
5. [체크리스트](#5-체크리스트)

---

## 1. 개요

### 1.1 현재 상태

| 항목 | 값 |
|------|-----|
| **Network** | Nasun Devnet |
| **Chain ID** | `33a8f3c5` |
| **RPC Endpoint** | `http://3.38.127.23:9000` |
| **Native Token** | NASUN (최소단위: SOE) |
| **Status** | ✅ 운영 중 |

### 1.2 다음 단계 목표

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        다음 단계 로드맵                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Phase 7 ✅              Phase 8 ✅               Phase 9              │
│  ─────────────────       ─────────────────        ─────────────────     │
│  토큰 전송 테스트         Faucet 구축              스마트 컨트랙트        │
│  (완료)                   (완료)                                        │
│  • CLI 환경 설정 ✅       • sui-faucet 배포 ✅     • Move 환경 설정      │
│  • 지갑 생성 ✅           • 서비스 설정 ✅         • 컨트랙트 작성       │
│  • 토큰 전송 ✅           • API 테스트 ✅          • 배포 및 테스트      │
│  • 트랜잭션 확인 ✅                                                     │
│                                                                         │
│  난이도: ⭐               난이도: ⭐⭐              난이도: ⭐⭐⭐         │
│  소요 시간: 완료          소요 시간: 완료           예상 시간: 2시간      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Phase 7: 토큰 전송 테스트 ✅ 완료

### 2.0 테스트 결과 요약 (2025-12-13)

| 시나리오 | 설명 | TX Digest | 결과 |
|---------|------|-----------|------|
| 1 | 기본 전송 (1,000 NASUN) | `H89XeZZ...` | ✅ 성공 |
| 2 | 소액 전송 (0.001 NASUN) | `Az7cdzv...` | ✅ 성공 |
| 3 | 대량 전송 (10M NASUN) | `9EJU8Sp...` | ✅ 성공 |
| 4 | PTB 다중 전송 (3명, 600 NASUN) | `3b5cGFS...` | ✅ 성공 |
| 5 | 에러 케이스 (4개) | - | ✅ 정상 에러 처리 |

**Genesis 토큰 현황:**
- benchmark1: ~240M NASUN (5개 coin)
- benchmark2: 250M NASUN (5개 coin)

**CLI Alias 설정:**
```bash
# ~/.bashrc에 추가됨
alias nasun="/home/naru/my_apps/nasun-devnet/sui/target/release/sui"

# 사용법
nasun client gas      # Nasun Devnet
sui client gas        # 공식 SUI 네트워크
```

### 2.1 목표

- Nasun Devnet에서 실제 토큰 전송이 가능한지 검증
- CLI를 통한 지갑 생성 및 관리
- 트랜잭션 생성 및 확인

### 2.2 CLI 환경 설정

```bash
# 1. SUI CLI 위치 확인 (로컬 빌드)
cd /home/naru/my_apps/nasun-devnet/sui
ls target/release/sui

# 2. Nasun Devnet 환경 추가
./target/release/sui client new-env \
  --alias nasun-devnet \
  --rpc http://3.38.127.23:9000

# 3. 환경 전환
./target/release/sui client switch --env nasun-devnet

# 4. 현재 환경 확인
./target/release/sui client active-env
# 예상 출력: nasun-devnet

# 5. Chain ID 확인
./target/release/sui client chain-identifier
# 예상 출력: 33a8f3c5
```

### 2.3 지갑 생성

```bash
# 1. 새 지갑 생성 (ED25519)
./target/release/sui client new-address ed25519

# 예상 출력:
# Created new keypair for address: 0x1234...abcd
# Secret Recovery Phrase: [12개 단어...]

# 2. 현재 주소 확인
./target/release/sui client active-address

# 3. 모든 주소 목록
./target/release/sui client addresses

# 4. 주소 전환 (필요 시)
./target/release/sui client switch --address 0x1234...abcd
```

### 2.4 Genesis 토큰 확인

벤치마크 모드로 생성된 Genesis에는 기본 주소에 토큰이 할당되어 있습니다.

```bash
# 1. Genesis 설정에서 주소 확인
cat /home/naru/my_apps/nasun-devnet/genesis/benchmark.aliases
cat /home/naru/my_apps/nasun-devnet/genesis/client.yaml

# 2. 잔액 확인 (Gas 객체)
./target/release/sui client gas

# 예상 출력:
# ╭────────────────────────────────────────────────────────────────────╮
# │ gasCoinId                                    │ soeBalance (SOE)    │
# ├────────────────────────────────────────────────────────────────────┤
# │ 0xabcd...1234                                │ 1000000000          │
# ╰────────────────────────────────────────────────────────────────────╯

# 3. 특정 주소 잔액 확인
./target/release/sui client balance
```

### 2.5 토큰 전송 테스트

```bash
# 1. 두 번째 주소 생성 (수신자)
./target/release/sui client new-address ed25519
# 출력된 주소 기록: 0x5678...efgh

# 2. 토큰 전송 (송신자 → 수신자)
./target/release/sui client pay-sui \
  --input-coins <GAS_COIN_ID> \
  --amounts 1000000000 \
  --recipients 0x5678...efgh \
  --gas-budget 10000000

# 3. 전송 결과 확인
./target/release/sui client balance --address 0x5678...efgh

# 4. 트랜잭션 상세 확인
./target/release/sui client tx-block <TX_DIGEST>
```

### 2.6 RPC로 트랜잭션 확인

```bash
# 트랜잭션 조회
curl -X POST http://3.38.127.23:9000 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "sui_getTransactionBlock",
    "params": ["<TX_DIGEST>", {"showInput": true, "showEffects": true}]
  }'
```

### 2.7 예상 결과

- ✅ CLI로 Nasun Devnet 연결 성공
- ✅ 지갑 생성 및 주소 관리
- ✅ Genesis 토큰 확인
- ✅ 토큰 전송 트랜잭션 성공
- ✅ 체크포인트에 트랜잭션 포함 확인

---

## 3. Phase 8: Faucet 구축 ✅ 완료

### 3.0 구축 결과 요약 (2025-12-14)

| 항목 | 값 |
|------|-----|
| **Faucet Endpoint** | `http://3.38.127.23:5003` |
| **요청당 지급량** | 5 NASUN (5 coins × 1 NASUN) |
| **서비스 상태** | ✅ Running (systemd) |

**테스트 결과:**
```json
{
  "status": "Success",
  "coins_sent": [
    {"amount": 1000000000, "id": "0x58df..."},
    {"amount": 1000000000, "id": "0x6afe..."},
    {"amount": 1000000000, "id": "0x9bff..."},
    {"amount": 1000000000, "id": "0xb75b..."},
    {"amount": 1000000000, "id": "0xf495..."}
  ]
}
```

**사용법:**
```bash
# 토큰 요청
curl -X POST http://3.38.127.23:5003/gas \
  -H "Content-Type: application/json" \
  -d '{"FixedAmountRequest":{"recipient":"<YOUR_ADDRESS>"}}'
```

### 3.1 목표

- 테스트용 토큰을 쉽게 받을 수 있는 HTTP API 서비스 구축
- 개발팀이 별도의 Genesis 키 없이 테스트 가능

### 3.2 아키텍처

```
┌─────────────────────┐
│   개발자 / 테스터   │
└──────────┬──────────┘
           │ HTTP POST
           ▼
┌─────────────────────┐
│   Faucet Service    │
│   :5003             │
│                     │
│   sui-faucet        │
└──────────┬──────────┘
           │ RPC
           ▼
┌─────────────────────┐
│   Nasun Devnet      │
│   :9000             │
└─────────────────────┘
```

### 3.3 Faucet 바이너리 배포

```bash
# 1. Node 1에 SSH 접속
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.127.23

# 2. sui-faucet 바이너리 확인
ls ~/sui-faucet

# 바이너리가 없으면 로컬에서 전송:
# (로컬에서 실행)
scp -i ~/.ssh/.awskey/nasun-devnet-key.pem \
  /home/naru/my_apps/nasun-devnet/binaries/sui-faucet \
  ubuntu@3.38.127.23:~/

# 3. 실행 권한 부여
chmod +x ~/sui-faucet
```

### 3.4 Faucet 키 설정

Faucet이 토큰을 보내려면 충분한 잔액이 있는 키가 필요합니다.

```bash
# 1. Faucet용 키스토어 디렉토리 생성
mkdir -p ~/faucet-config

# 2. Genesis의 벤치마크 키스토어 복사
cp /home/ubuntu/genesis/benchmark.keystore ~/faucet-config/sui.keystore

# 3. Faucet 설정 파일 생성
cat > ~/faucet-config/faucet.yaml << 'EOF'
host: 0.0.0.0
port: 5003
amount: 1000000000
num-coins: 5
request-buffer-size: 10
max-request-per-second: 10
wal-dir: /home/ubuntu/faucet-wal
sui-config-path: /home/ubuntu/faucet-config
fullnode-url: http://127.0.0.1:9000
EOF
```

### 3.5 Faucet 서비스 등록

```bash
# Systemd 서비스 파일 생성
sudo tee /etc/systemd/system/nasun-faucet.service > /dev/null << 'EOF'
[Unit]
Description=Nasun Devnet Faucet Service
After=network.target nasun-fullnode.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu
ExecStart=/home/ubuntu/sui-faucet \
  --host 0.0.0.0 \
  --port 5003 \
  --sui-config-path /home/ubuntu/faucet-config \
  --wal-dir /home/ubuntu/faucet-wal
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# 서비스 활성화 및 시작
sudo systemctl daemon-reload
sudo systemctl enable nasun-faucet
sudo systemctl start nasun-faucet

# 상태 확인
sudo systemctl status nasun-faucet
```

### 3.6 Security Group 업데이트

```bash
# AWS CLI로 포트 5003 열기 (로컬에서 실행)
aws ec2 authorize-security-group-ingress \
  --group-id <SECURITY_GROUP_ID> \
  --protocol tcp \
  --port 5003 \
  --cidr 0.0.0.0/0 \
  --profile nasun-devnet
```

### 3.7 Faucet API 테스트

```bash
# 1. 상태 확인
curl http://3.38.127.23:5003/

# 2. 토큰 요청
curl -X POST http://3.38.127.23:5003/gas \
  -H "Content-Type: application/json" \
  -d '{
    "FixedAmountRequest": {
      "recipient": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    }
  }'

# 예상 응답:
# {
#   "transferredGasObjects": [
#     {"amount": 1000000000, "id": "0x...", "transferTxDigest": "..."}
#   ],
#   "error": null
# }

# 3. 잔액 확인
curl -X POST http://3.38.127.23:9000 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "suix_getBalance",
    "params": ["0x1234..."]
  }'
```

### 3.8 Faucet 엔드포인트 정리

| 엔드포인트 | 메서드 | 설명 |
|-----------|--------|------|
| `http://3.38.127.23:5003/` | GET | 상태 확인 |
| `http://3.38.127.23:5003/gas` | POST | 토큰 요청 |

---

## 4. Phase 9: 스마트 컨트랙트 배포

### 4.1 목표

- Move 언어로 간단한 스마트 컨트랙트 작성
- Nasun Devnet에 배포
- 컨트랙트 함수 호출 테스트

### 4.2 Move 개발 환경

```bash
# 1. 프로젝트 디렉토리 생성
mkdir -p /home/naru/my_apps/nasun-devnet/contracts
cd /home/naru/my_apps/nasun-devnet/contracts

# 2. 새 Move 패키지 생성
/home/naru/my_apps/nasun-devnet/sui/target/release/sui move new hello_nasun

# 3. 디렉토리 구조 확인
tree hello_nasun/
# hello_nasun/
# ├── Move.toml
# └── sources/
```

### 4.3 샘플 컨트랙트: Hello Nasun

```bash
# Move.toml 수정
cat > hello_nasun/Move.toml << 'EOF'
[package]
name = "hello_nasun"
version = "1.0.0"

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/devnet" }

[addresses]
hello_nasun = "0x0"
EOF
```

```move
// hello_nasun/sources/hello.move
module hello_nasun::hello {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::string::{Self, String};

    /// Greeting 객체 - 누구나 소유 가능
    public struct Greeting has key, store {
        id: UID,
        message: String,
        created_by: address,
    }

    /// 새로운 Greeting 객체 생성
    public entry fun create_greeting(
        message: vector<u8>,
        ctx: &mut TxContext
    ) {
        let greeting = Greeting {
            id: object::new(ctx),
            message: string::utf8(message),
            created_by: tx_context::sender(ctx),
        };
        transfer::public_transfer(greeting, tx_context::sender(ctx));
    }

    /// Greeting 메시지 업데이트
    public entry fun update_greeting(
        greeting: &mut Greeting,
        new_message: vector<u8>,
    ) {
        greeting.message = string::utf8(new_message);
    }

    /// Greeting 메시지 읽기
    public fun get_message(greeting: &Greeting): &String {
        &greeting.message
    }
}
```

### 4.4 컨트랙트 컴파일

```bash
cd /home/naru/my_apps/nasun-devnet/contracts/hello_nasun

# 컴파일
/home/naru/my_apps/nasun-devnet/sui/target/release/sui move build

# 예상 출력:
# BUILDING hello_nasun
# Successfully verified dependencies on-chain against source.
# Build Successful

# 컴파일 결과 확인
ls build/hello_nasun/
```

### 4.5 컨트랙트 배포

```bash
# 1. Nasun Devnet 환경 확인
/home/naru/my_apps/nasun-devnet/sui/target/release/sui client active-env
# 출력: nasun-devnet

# 2. 컨트랙트 배포
/home/naru/my_apps/nasun-devnet/sui/target/release/sui client publish \
  --gas-budget 100000000

# 예상 출력:
# ----- Transaction Digest ----
# <TX_DIGEST>
# ----- Transaction Data ----
# ...
# ----- Object Changes ----
# Created Objects:
#   - Package ID: 0x...
#   - ...

# 3. Package ID 기록
# PACKAGE_ID=0x...
```

### 4.6 컨트랙트 호출 테스트

```bash
# 1. Greeting 생성
/home/naru/my_apps/nasun-devnet/sui/target/release/sui client call \
  --package <PACKAGE_ID> \
  --module hello \
  --function create_greeting \
  --args "Hello from Nasun Devnet!" \
  --gas-budget 10000000

# 2. 생성된 Greeting 객체 확인
/home/naru/my_apps/nasun-devnet/sui/target/release/sui client objects

# 3. Greeting 메시지 업데이트
/home/naru/my_apps/nasun-devnet/sui/target/release/sui client call \
  --package <PACKAGE_ID> \
  --module hello \
  --function update_greeting \
  --args <GREETING_OBJECT_ID> "Updated: Welcome to Nasun!" \
  --gas-budget 10000000

# 4. 객체 상세 조회
/home/naru/my_apps/nasun-devnet/sui/target/release/sui client object <GREETING_OBJECT_ID>
```

### 4.7 RPC로 컨트랙트 조회

```bash
# 패키지 정보 조회
curl -X POST http://3.38.127.23:9000 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "sui_getObject",
    "params": ["<PACKAGE_ID>", {"showContent": true}]
  }'

# 객체 정보 조회
curl -X POST http://3.38.127.23:9000 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "sui_getObject",
    "params": ["<GREETING_OBJECT_ID>", {"showContent": true}]
  }'
```

### 4.8 예상 결과

- ✅ Move 프로젝트 생성 및 컴파일
- ✅ Nasun Devnet에 컨트랙트 배포
- ✅ 컨트랙트 함수 호출 (create, update)
- ✅ 객체 상태 변경 확인

---

## 5. 체크리스트

### Phase 7: 토큰 전송 테스트 ✅ 완료 (2025-12-13)
- [x] CLI 환경에 Nasun Devnet 추가
- [x] 환경 전환 및 Chain ID 확인 (`33a8f3c5`)
- [x] 새 지갑 주소 생성 (test-wallet-1, 2, 3, multi-receiver-1, 2)
- [x] Genesis 토큰 잔액 확인 (benchmark1: 250M, benchmark2: 250M)
- [x] 기본 토큰 전송 테스트 (1,000 NASUN)
- [x] 소액 전송 테스트 (0.001 NASUN)
- [x] 대량 전송 테스트 (10M NASUN)
- [x] PTB 다중 수신자 전송 테스트 (3명에게 동시 전송)
- [x] 에러 케이스 테스트 (잔액 부족, 잘못된 주소, 없는 객체, 가스 부족)
- [x] `nasun` CLI alias 설정 (`~/.bashrc`)

### Phase 8: Faucet 구축 ✅ 완료 (2025-12-14)

#### 8.1 사전 준비
- [x] sui-faucet 바이너리 존재 확인 (로컬) - 12.8MB
- [x] 로컬 sui-faucet 바이너리 경로 확인
  ```bash
  ls /home/naru/my_apps/nasun-devnet/binaries/sui-faucet
  ```

#### 8.2 바이너리 배포 (Node 1: 3.38.127.23)
- [x] Node 1에 SSH 접속
  ```bash
  ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.127.23
  ```
- [x] sui-faucet 바이너리 전송
  ```bash
  scp -i ~/.ssh/.awskey/nasun-devnet-key.pem \
    /home/naru/my_apps/nasun-devnet/binaries/sui-faucet \
    ubuntu@3.38.127.23:~/
  ```
- [x] 바이너리 실행 권한 부여
  ```bash
  chmod +x ~/sui-faucet
  ```
- [x] 바이너리 동작 확인 (--help로 확인, --version은 미지원)
  ```bash
  ./sui-faucet --help
  ```

#### 8.3 Faucet 설정
- [x] Faucet 설정 디렉토리 생성
  ```bash
  mkdir -p ~/faucet-config
  ```
- [x] Faucet용 keystore 설정 (benchmark 키 사용)
  ```bash
  # 로컬에서 benchmark.keystore 전송
  scp benchmark.keystore ubuntu@3.38.127.23:~/faucet-config/sui.keystore
  ```
- [x] Faucet용 client.yaml 생성
  ```bash
  cat > ~/faucet-config/client.yaml << 'EOF'
  ---
  keystore:
    File: "/home/ubuntu/faucet-config/sui.keystore"
  envs:
    - alias: nasun-devnet
      rpc: "http://127.0.0.1:9000"
  active_env: nasun-devnet
  active_address: "0x71cd8de3b11ee5f60369008870282ff399997431cfe13c3af3b6879cdfc3528b"
  EOF
  ```
- [x] SUI_CONFIG_DIR 환경변수로 설정 디렉토리 지정

#### 8.4 Faucet 서비스 등록
- [x] Systemd 서비스 파일 생성 (--write-ahead-log 옵션 미지원으로 제외)
  ```bash
  sudo tee /etc/systemd/system/nasun-faucet.service > /dev/null << 'EOF'
  [Unit]
  Description=Nasun Devnet Faucet Service
  After=network.target nasun-fullnode.service
  Wants=nasun-fullnode.service

  [Service]
  Type=simple
  User=ubuntu
  WorkingDirectory=/home/ubuntu
  Environment="RUST_LOG=info"
  Environment="SUI_CONFIG_DIR=/home/ubuntu/faucet-config"
  ExecStart=/home/ubuntu/sui-faucet \
    --host-ip 0.0.0.0 \
    --port 5003 \
    --num-coins 5 \
    --amount 1000000000
  Restart=on-failure
  RestartSec=10
  LimitNOFILE=65535

  [Install]
  WantedBy=multi-user.target
  EOF
  ```
- [x] Systemd 데몬 리로드
  ```bash
  sudo systemctl daemon-reload
  ```
- [x] Faucet 서비스 활성화
  ```bash
  sudo systemctl enable nasun-faucet
  ```
- [x] Faucet 서비스 시작
  ```bash
  sudo systemctl start nasun-faucet
  ```
- [x] Faucet 서비스 상태 확인 (Active: running)
  ```bash
  sudo systemctl status nasun-faucet
  ```
- [x] Faucet 로그 확인
  ```bash
  sudo journalctl -u nasun-faucet -f
  ```

#### 8.5 AWS Security Group 설정
- [x] Security Group ID 확인: `sg-03fbfb49200cce461`
  ```bash
  aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=*nasun*" \
    --query "SecurityGroups[*].[GroupId,GroupName]" \
    --profile nasun-devnet \
    --output table
  ```
- [x] 포트 5003 인바운드 규칙 추가
  ```bash
  aws ec2 authorize-security-group-ingress \
    --group-id sg-03fbfb49200cce461 \
    --protocol tcp \
    --port 5003 \
    --cidr 0.0.0.0/0 \
    --profile nasun-devnet
  ```
- [x] 규칙 추가 확인 완료

#### 8.6 Faucet API 테스트
- [x] Faucet 상태 확인 (Health Check)
  ```bash
  curl http://3.38.127.23:5003/
  ```
- [x] 새 테스트 주소 생성 (로컬): `faucet-test`
  ```bash
  nasun client new-address ed25519 faucet-test
  # 주소: 0x374345304db69fedcdff5170cf295c5a2b4c7d4680956032255010cb8a1dfbfb
  ```
- [x] Faucet으로 토큰 요청 - 성공
  ```bash
  curl -X POST http://3.38.127.23:5003/gas \
    -H "Content-Type: application/json" \
    -d '{
      "FixedAmountRequest": {
        "recipient": "0x374345304db69fedcdff5170cf295c5a2b4c7d4680956032255010cb8a1dfbfb"
      }
    }'
  ```
- [x] 토큰 수령 확인: 5 NASUN (5 coins × 1 NASUN)
  ```bash
  nasun client switch --address faucet-test
  nasun client gas
  ```

#### 8.7 문서화 및 완료
- [x] Faucet 엔드포인트 문서화
  | 엔드포인트 | 메서드 | 설명 |
  |-----------|--------|------|
  | `http://3.38.127.23:5003/` | GET | 상태 확인 |
  | `http://3.38.127.23:5003/gas` | POST | 토큰 요청 |
- [x] NEXT_STEPS.md 문서 업데이트 (Phase 8 완료)
- [ ] 변경사항 Git 커밋 및 푸시

### Phase 9: 스마트 컨트랙트 배포
- [ ] Move 프로젝트 생성
- [ ] hello_nasun 컨트랙트 작성
- [ ] 컴파일 성공
- [ ] Nasun Devnet에 배포
- [ ] create_greeting 함수 호출
- [ ] update_greeting 함수 호출
- [ ] 객체 상태 확인

---

## 트러블슈팅

### CLI 연결 오류

**문제**: `Failed to connect to RPC server`

```bash
# 해결: RPC 엔드포인트 확인
curl -X POST http://3.38.127.23:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getChainIdentifier","params":[]}'
```

### Faucet 토큰 부족

**문제**: `Faucet out of gas`

```bash
# 해결: Faucet 키스토어에 토큰 추가
# Genesis 키로 Faucet 주소에 토큰 전송
```

### 컨트랙트 배포 실패

**문제**: `InsufficientGas`

```bash
# 해결: gas-budget 증가
--gas-budget 200000000
```

---

## 다음 단계 (향후)

1. **블록 탐색기 (Explorer)**: 웹 UI로 트랜잭션/블록 조회
2. **지갑 연동**: SUI Wallet 커스텀 네트워크 설정
3. **노드 확장**: 4노드로 Fault Tolerance 테스트
4. **모니터링**: Grafana + Prometheus 대시보드

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 1.0.0 | 2025-12-13 | 초안 작성 | Claude Code |
| 1.1.0 | 2025-12-13 | Phase 7 완료 반영, Phase 8 상세 체크리스트 추가, CLI alias 설정 | Claude Code |
| 1.2.0 | 2025-12-14 | Phase 8 Faucet 구축 완료, 엔드포인트 문서화 | Claude Code |
