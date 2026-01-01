# Nasun Devnet 다음 단계 계획서

**Version**: 1.7.0
**Created**: 2025-12-13
**Updated**: 2026-01-01
**Author**: Claude Code
**Status**: V3 리셋 완료, Phase 1 (Pado Spot DEX) 준비 중
**Prerequisites**: Nasun Devnet V3 운영 중 (Sui mainnet v1.63.0 기반)

---

## 목차

1. [개요](#1-개요)
2. [Phase 7: 토큰 전송 테스트](#2-phase-7-토큰-전송-테스트)
3. [Phase 8: Faucet 구축](#3-phase-8-faucet-구축)
4. [Phase 9: 스마트 컨트랙트 배포](#4-phase-9-스마트-컨트랙트-배포)
5. [Phase 10: HTTPS 설정](#5-phase-10-https-설정)
6. [Phase 11: 지갑 구현 (계획)](#6-phase-11-지갑-구현-계획)
7. [체크리스트](#7-체크리스트)

---

## 1. 개요

### 1.1 현재 상태 (2025-12-25 V3 리셋)

| 항목 | 값 |
|------|-----|
| **Network** | Nasun Devnet |
| **Chain ID** | `6681cdfd` (2025-12-25 V3 리셋) |
| **Fork Source** | Sui mainnet v1.63.0 |
| **RPC Endpoint (HTTPS)** | `https://rpc.devnet.nasun.io` |
| **RPC Endpoint (HTTP)** | `http://3.38.127.23:9000` |
| **Faucet (HTTPS)** | `https://faucet.devnet.nasun.io` |
| **Faucet (HTTP)** | `http://3.38.127.23:5003` |
| **Explorer** | `https://explorer.devnet.nasun.io` |
| **Native Token** | NASUN (최소단위: SOE) |
| **Status** | ✅ V3 운영 중 |

### 1.2 다음 단계 목표

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        다음 단계 로드맵                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Phase 7-10 ✅           Phase 11 ✅              V3 리셋 ✅             │
│  ─────────────────       ─────────────────        ─────────────────     │
│  기본 인프라 구축         지갑 구현                 Sui mainnet v1.63.0   │
│  (완료)                   (완료)                   (완료)                │
│  • 토큰 전송 ✅           • Explorer 내 지갑 ✅    • Chain ID 변경 ✅    │
│  • Faucet ✅              • Ed25519 생성 ✅        • 로그 최적화 ✅      │
│  • HTTPS ✅               • 암호화 저장 ✅         • 문서 업데이트 ✅    │
│                                                                         │
│  Pado Phase 1 🔜         Pado Phase 2 📋         Pado Phase 3 📋       │
│  ─────────────────       ─────────────────        ─────────────────     │
│  Spot DEX MVP             Perps (무기한 선물)     Prediction Markets   │
│  (진행 예정)              (계획 중)                (계획 중)             │
│  • DeepBook V3 배포       • Oracle 통합            • 예측 시장            │
│  • 테스트 토큰 발행       • Unified Margin         • Governance           │
│  • 스왑 UI 개발           • Flash Loan             • DEEP 토큰            │
│                                                                         │
│  난이도: ⭐⭐⭐           난이도: ⭐⭐⭐⭐          난이도: ⭐⭐⭐⭐       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

> **참고**: V3 리셋으로 DeepBook V2가 deprecated 되었습니다 (abort 1337).
> Pado DEX 개발을 위해 DeepBook V3를 별도 배포해야 합니다.

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
# 예상 출력: 6681cdfd (2025-12-25 V3 리셋)
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

## 4. Phase 9: 스마트 컨트랙트 배포 ✅ 완료

### 4.0 배포 결과 요약 (2025-12-14)

| 항목 | 값 |
|------|-----|
| **Package ID** | `0x50023dcd6281f8e3836dcd05482e3df40d1c7f59fb4f00e9a3ca8b7fcb4debda` |
| **Module** | `hello` |
| **Greeting Object** | `0xce779d345fa0c5d1c86e7a98021311e730b071baea6ae94b31cd3ecba9f3ea14` |

**테스트 결과:**
| TX | 함수 | 결과 |
|----|------|------|
| `DbJU95fbt4SZ72RTHFYk2TfqdSxSPE8oL8ZpnpQFciyc` | publish | ✅ 패키지 배포 성공 |
| `A5JPTauZtgRdBw6MeAT1PQbE4eQ6DyUvA9pHAZMD6dwW` | create_greeting | ✅ "Hello from Nasun Devnet!" |
| `9hycYQG63ZYSsSiYzrW2kq2ti8RPKMa3LQMT5MUhyXBn` | update_greeting | ✅ "Welcome to Nasun Blockchain!" |

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

## 5. Phase 10: HTTPS 설정 ✅ 완료

### 5.0 설정 결과 요약 (2025-12-15)

| 항목 | 값 |
|------|-----|
| **RPC (HTTPS)** | `https://rpc.devnet.nasun.io` |
| **Faucet (HTTPS)** | `https://faucet.devnet.nasun.io` |
| **Explorer** | `https://devnet.nasun.io` (배포 예정) |
| **SSL 인증서** | Let's Encrypt (2026-03-15 만료, 자동 갱신) |
| **리버스 프록시** | Nginx |

### 5.1 목표

- SUI 지갑 연동을 위한 HTTPS 엔드포인트 제공
- 보안 강화 (TLS 암호화)
- 도메인 기반 접근 (IP 대신)

### 5.2 구현 내용

#### DNS 설정 (Porkbun)

| Type | Host | Value |
|------|------|-------|
| A | rpc.devnet | 3.38.127.23 |
| A | faucet.devnet | 3.38.127.23 |
| A | devnet | 3.38.127.23 |

#### 서버 설정 (EC2)

```bash
# Nginx 설치
sudo apt install -y nginx

# Let's Encrypt 인증서 발급
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d rpc.devnet.nasun.io -d faucet.devnet.nasun.io -d devnet.nasun.io
```

#### AWS Security Group

- 포트 80 (HTTP → HTTPS 리다이렉트)
- 포트 443 (HTTPS)

### 5.3 SUI 지갑 연동 현황

**문제 발견**: 주요 SUI 지갑들이 커스텀 RPC를 지원하지 않음

| 지갑 | 커스텀 RPC | 비고 |
|------|-----------|------|
| Sui Wallet (Slush) | ❌ | 이전 지원, 현재 불가 |
| Suiet | ❌ | 의도적 미지원 |
| Nightly | ⚠️ | 제한적 |

**해결 방안**: Phase 11에서 Nasun 자체 지갑 구현

---

## 6. Phase 11: 지갑 구현 (계획)

### 6.0 계획 요약

| 항목 | 값 |
|------|-----|
| **접근 방식** | Option B+ (Explorer 내 모듈화된 지갑) |
| **계획서 위치** | `nasun-explorer/doc/NASUN_WALLET_IMPLEMENTATION_PLAN.md` |
| **예상 소요** | 3-4일 |
| **상태** | 📋 계획 수립 완료 |

### 6.1 배경

- SUI 지갑들이 커스텀 RPC를 지원하지 않음
- 사용자가 CLI 없이 Nasun Devnet과 상호작용할 방법 필요
- Explorer에 지갑 기능을 통합하되, 향후 분리 가능한 모듈 구조로 설계

### 6.2 주요 기능

1. **지갑 생성**: Ed25519 키페어 생성
2. **암호화 저장**: AES-256 + PBKDF2로 로컬 스토리지에 저장
3. **잔액 조회**: NASUN 토큰 잔액 표시
4. **토큰 전송**: 서명 및 전송
5. **Faucet 연동**: 버튼 클릭으로 테스트 토큰 수령

### 6.3 아키텍처 (Option B+)

```
nasun-explorer/
├── src/
│   ├── pages/              # Explorer 페이지들 (기존)
│   └── wallet/             # 지갑 모듈 (신규) ★
│       ├── index.ts        # 단일 export point
│       ├── components/     # 지갑 UI 컴포넌트
│       ├── hooks/          # 지갑 로직 훅
│       └── lib/            # 암호화, 키관리 유틸
```

**핵심 원칙**: `wallet/` 모듈은 외부 의존성 없이 독립 동작 가능

### 6.4 구현 단계

| Phase | 내용 | 예상 기간 |
|-------|------|----------|
| 1 | 지갑 코어 (키생성, 암호화, 잔액) | 1-2일 |
| 2 | 트랜잭션 (전송, 서명) | 1일 |
| 3 | Faucet 연동 | 0.5일 |
| 4 | Explorer 통합 | 0.5일 |

### 6.5 다음 작업

```bash
# nasun-explorer 프로젝트에서 새 Claude 세션 열기
cd /home/naru/my_apps/nasun-explorer
# Claude Code 실행 후:
# "doc/NASUN_WALLET_IMPLEMENTATION_PLAN.md 문서를 읽고 Phase 1부터 구현해줘"
```

---

## 7. 체크리스트

### Phase 7: 토큰 전송 테스트 ✅ 완료 (2025-12-13)
- [x] CLI 환경에 Nasun Devnet 추가
- [x] 환경 전환 및 Chain ID 확인 (`6681cdfd` - V3 리셋 후)
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
- [x] 변경사항 Git 커밋 및 푸시 (commit: `1ec7455`)

### Phase 9: 스마트 컨트랙트 배포 ✅ 완료 (2025-12-14)
- [x] Move 프로젝트 생성 (`contracts/hello_nasun/`)
- [x] hello_nasun 컨트랙트 작성 (`sources/hello_nasun.move`)
- [x] 컴파일 성공 (로컬 Sui Framework 의존성 사용)
- [x] Nasun Devnet에 배포 - Package ID: `0x50023dcd...`
- [x] create_greeting 함수 호출 - "Hello from Nasun Devnet!"
- [x] update_greeting 함수 호출 - "Welcome to Nasun Blockchain!"
- [x] 객체 상태 확인 - Greeting Object ID: `0xce779d34...`

### Phase 10: HTTPS 설정 ✅ 완료 (2025-12-15)
- [x] Porkbun DNS에 A 레코드 추가 (rpc.devnet, faucet.devnet, devnet)
- [x] EC2에 Nginx 설치 및 설정
- [x] Let's Encrypt SSL 인증서 발급 (Certbot)
- [x] AWS Security Group 포트 80, 443 열기
- [x] HTTPS RPC 테스트 (`https://rpc.devnet.nasun.io`)
- [x] HTTPS Faucet 테스트 (`https://faucet.devnet.nasun.io`)
- [x] 인증서 자동 갱신 확인 (`certbot.timer`)
- [x] SUI 지갑 커스텀 RPC 지원 현황 조사 → 미지원 확인

### Phase 11: 지갑 구현 ✅ 완료 (2025-12-18)
- [x] 지갑 구현 옵션 분석 (A/B/C/D)
- [x] 외부 AI 조언 수집 (Perplexity, Gemini)
- [x] Option B+ (하이브리드) 선택
- [x] 상세 구현 계획서 작성 (`nasun-explorer/doc/NASUN_WALLET_IMPLEMENTATION_PLAN.md`)
- [x] Phase 1: 지갑 코어 구현
- [x] Phase 2: 트랜잭션 구현
- [x] Phase 3: Faucet 연동
- [x] Phase 4: Explorer 통합

### V3 리셋 ✅ 완료 (2025-12-25)
- [x] Sui mainnet v1.63.0 기반 재빌드
- [x] 새 Chain ID: `6681cdfd`
- [x] 2노드 동시 시작 및 합의 확인
- [x] Fullnode (RPC) 서비스 구성
- [x] Faucet 서비스 재구성 (--write-ahead-log 제거)
- [x] 로그 관리 최적화 (logrotate, journald)
- [x] Explorer 환경변수 업데이트 (AWS Amplify)
- [x] 문서 업데이트 (CLAUDE.md, OPERATIONS.md 등)

### 모니터링 설정 ✅ 완료 (2026-01-01)
- [x] EC2 Auto Recovery 알람 설정 (양 노드)
- [x] 디스크 모니터링 스크립트 설치 (80% 임계값)
- [x] Cron job 설정 (매시간 실행)
- [x] SNS 토픽 생성 (`nasun-devnet-alerts`)
- [x] 이메일 알림 구독 (naru@nasun.io)
- [x] Node 1 impaired 상태 복구 (Force Stop → Start)

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

1. **Pado Phase 1**: DeepBook V3 배포 + 테스트 토큰 + Spot DEX MVP
2. **Pado Phase 2**: Perps (무기한 선물) 개발
3. **노드 확장**: 4노드로 Fault Tolerance 테스트
4. **모니터링**: Grafana + Prometheus 대시보드
5. **NFT 컨트랙트**: Nasun NFT 컨트랙트 배포

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 1.0.0 | 2025-12-13 | 초안 작성 | Claude Code |
| 1.1.0 | 2025-12-13 | Phase 7 완료 반영, Phase 8 상세 체크리스트 추가, CLI alias 설정 | Claude Code |
| 1.2.0 | 2025-12-14 | Phase 8 Faucet 구축 완료, 엔드포인트 문서화 | Claude Code |
| 1.3.0 | 2025-12-14 | Phase 9 스마트 컨트랙트 배포 완료, hello_nasun 패키지 배포 | Claude Code |
| 1.4.0 | 2025-12-15 | Phase 10 HTTPS 설정 완료, SSL 인증서 발급 | Claude Code |
| 1.5.0 | 2025-12-15 | Phase 11 지갑 구현 계획 수립, Option B+ 선택 | Claude Code |
| 1.6.0 | 2025-12-25 | V3 리셋 완료 (Chain ID: 6681cdfd), Phase 11 완료, Pado 로드맵 추가 | Claude Code |
| 1.7.0 | 2026-01-01 | 모니터링 설정 완료 (Auto Recovery, 디스크 모니터링, SNS 알림) | Claude Code |
