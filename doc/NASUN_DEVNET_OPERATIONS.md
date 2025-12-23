# Nasun Devnet 운영 가이드

**Version**: 1.0.0
**Created**: 2025-12-23
**Author**: Claude Code
**Status**: 운영 중

---

## 목차

1. [운영 개요](#1-운영-개요)
2. [인프라 현황](#2-인프라-현황)
3. [서비스 관리](#3-서비스-관리)
4. [로그 관리](#4-로그-관리)
5. [문제 해결 사례](#5-문제-해결-사례)
6. [모니터링 명령어](#6-모니터링-명령어)
7. [긴급 대응 절차](#7-긴급-대응-절차)

---

## 1. 운영 개요

### 1.1 네트워크 정보

| 항목 | 값 |
|------|-----|
| **Network Name** | Nasun Devnet |
| **Chain ID** | `33a8f3c5` |
| **Native Token** | NASUN (최소단위: SOE) |
| **Consensus** | Narwhal/Bullshark |
| **Epoch Duration** | 60초 |

### 1.2 엔드포인트

| 서비스 | HTTPS | HTTP |
|--------|-------|------|
| RPC | https://rpc.devnet.nasun.io | http://3.38.127.23:9000 |
| Faucet | https://faucet.devnet.nasun.io | http://3.38.127.23:5003 |
| Explorer | https://explorer.devnet.nasun.io | - |

### 1.3 개발 히스토리

| Phase | 내용 | 완료일 |
|-------|------|--------|
| 1-6 | 기본 인프라 구축 (2노드 Devnet) | 2025-12-13 |
| 7 | 토큰 전송 테스트 | 2025-12-13 |
| 8 | Faucet 구축 | 2025-12-14 |
| 9 | 스마트 컨트랙트 배포 (hello_nasun) | 2025-12-14 |
| 10 | HTTPS 설정 (Let's Encrypt) | 2025-12-15 |
| 11 | 지갑 구현 (계획 중) | - |

---

## 2. 인프라 현황

### 2.1 EC2 인스턴스

| 노드 | IP | 역할 | 인스턴스 타입 |
|------|-----|------|--------------|
| nasun-node-1 | 3.38.127.23 | Validator + Fullnode (RPC) + Faucet | c6i.xlarge |
| nasun-node-2 | 3.38.76.85 | Validator | c6i.xlarge |

### 2.2 스토리지

- **EBS**: 48GB gp3 (각 노드)
- **사용 현황**: 약 24GB 사용 (51%)
- **주요 디렉토리**:
  - `/home/ubuntu/full_node_db`: ~13GB
  - `/home/ubuntu/authorities_db`: ~9GB

### 2.3 SSH 접속

```bash
# Node 1 (주 노드)
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.127.23

# Node 2
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.76.85
```

---

## 3. 서비스 관리

### 3.1 systemd 서비스 목록

| 서비스 | 설명 | 포트 |
|--------|------|------|
| `nasun-validator` | Validator 노드 | 8080, 8084 |
| `nasun-fullnode` | Fullnode (RPC 서비스) | 9000 |
| `nasun-faucet` | Faucet 서비스 | 5003 |

### 3.2 서비스 관리 명령어

```bash
# 서비스 상태 확인
sudo systemctl status nasun-validator nasun-fullnode nasun-faucet

# 서비스 재시작
sudo systemctl restart nasun-validator nasun-fullnode

# 서비스 로그 확인
sudo journalctl -u nasun-fullnode -f
sudo journalctl -u nasun-validator -f

# 서비스 시작/중지
sudo systemctl start nasun-fullnode
sudo systemctl stop nasun-fullnode
```

### 3.3 서비스 설정 파일 위치

```
/etc/systemd/system/
├── nasun-validator.service
├── nasun-fullnode.service
└── nasun-faucet.service
```

### 3.4 현재 서비스 설정 (예: nasun-fullnode.service)

```ini
[Unit]
Description=Nasun Devnet Fullnode (RPC)
After=network.target nasun-validator.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu
Environment="RUST_LOG=warn"    # 로그 레벨 설정
ExecStart=/home/ubuntu/sui-node --config-path fullnode.yaml
Restart=always
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

**중요**: `RUST_LOG=warn` 환경변수가 설정되어 있어야 로그량이 줄어듭니다.

---

## 4. 로그 관리

### 4.1 로그 레벨 설정

SUI 노드는 기본적으로 INFO 레벨 로그를 syslog에 기록합니다.
**RUST_LOG=warn** 설정으로 로그량을 99% 이상 줄일 수 있습니다.

| 로그 레벨 | 예상 일간 로그량 |
|----------|-----------------|
| INFO (기본) | ~3.4GB/일 |
| WARN (권장) | ~6MB/일 |

### 4.2 logrotate 설정

`/etc/logrotate.d/rsyslog`:

```
/var/log/syslog
/var/log/mail.log
/var/log/kern.log
/var/log/auth.log
/var/log/user.log
/var/log/cron.log
{
    daily
    rotate 3
    maxsize 500M
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
```

### 4.3 디스크 사용량 확인

```bash
# 전체 디스크 사용량
df -h /

# syslog 크기
ls -lh /var/log/syslog*

# 디렉토리별 사용량
du -sh /home/ubuntu/* | sort -hr | head -10
```

---

## 5. 문제 해결 사례

### 5.1 디스크 100% 문제 (2025-12-23)

**증상**:
- Explorer에서 "Disconnected" 표시
- RPC 호출 시 502 Bad Gateway
- 노드 프로세스 다운

**원인**:
- `/var/log/syslog.1` 파일이 24GB 차지
- SUI 노드가 매 블록마다 INFO 로그를 기록
- 일주일 만에 디스크 100% 사용

**해결**:
1. 로그 파일 삭제
   ```bash
   sudo rm /var/log/syslog.1
   ```
2. logrotate 설정 강화 (일간 + 500MB 제한)
3. systemd 서비스에 `RUST_LOG=warn` 추가
4. 서비스 재시작

**예방**:
- logrotate 설정 유지
- RUST_LOG=warn 환경변수 필수
- 주기적 디스크 모니터링

### 5.2 systemd 서비스 충돌 (2025-12-23)

**증상**:
- syslog에 "Address already in use" 에러 반복
- 10초마다 새 노드 프로세스 시작 시도

**원인**:
- 수동으로 시작한 노드 프로세스가 포트 점유
- systemd 서비스의 `Restart=always` 설정으로 재시작 반복 시도
- 두 프로세스가 충돌

**해결**:
1. 수동 시작한 노드 종료
   ```bash
   pkill -9 -f sui-node
   ```
2. systemd 서비스에 RUST_LOG=warn 추가
   ```bash
   sudo sed -i '/\[Service\]/a Environment="RUST_LOG=warn"' /etc/systemd/system/nasun-validator.service
   sudo sed -i '/\[Service\]/a Environment="RUST_LOG=warn"' /etc/systemd/system/nasun-fullnode.service
   sudo systemctl daemon-reload
   ```
3. 서비스 재시작
   ```bash
   sudo systemctl restart nasun-validator nasun-fullnode
   ```

**교훈**:
- 노드는 반드시 systemd 서비스로 관리
- 수동 실행 시 기존 서비스 중지 필요

---

## 6. 모니터링 명령어

### 6.1 RPC 상태 확인

```bash
# Chain ID 확인
curl -s -X POST https://rpc.devnet.nasun.io \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getChainIdentifier","params":[]}' | jq

# 최신 체크포인트
curl -s -X POST https://rpc.devnet.nasun.io \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getLatestCheckpointSequenceNumber","params":[]}' | jq

# 총 트랜잭션 수
curl -s -X POST https://rpc.devnet.nasun.io \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getTotalTransactionBlocks","params":[]}' | jq
```

### 6.2 프로세스 상태

```bash
# sui-node 프로세스 확인
ps aux | grep sui-node | grep -v grep

# 포트 리스닝 확인
ss -tlnp | grep -E '9000|5003|8080|8084'

# systemd 서비스 상태
sudo systemctl is-active nasun-validator nasun-fullnode nasun-faucet
```

### 6.3 로그 모니터링

```bash
# 실시간 syslog 모니터링 (sui-node 로그)
tail -f /var/log/syslog | grep sui-node

# systemd 서비스 로그
sudo journalctl -u nasun-fullnode -f --no-pager

# syslog 증가율 확인 (30초)
SIZE1=$(stat -c%s /var/log/syslog); sleep 30; SIZE2=$(stat -c%s /var/log/syslog); echo "30초간 증가: $((SIZE2-SIZE1)) 바이트"
```

---

## 7. 긴급 대응 절차

### 7.1 노드 다운 시

1. **상태 확인**
   ```bash
   sudo systemctl status nasun-validator nasun-fullnode
   ```

2. **서비스 재시작**
   ```bash
   sudo systemctl restart nasun-validator nasun-fullnode
   ```

3. **재시작 후 확인**
   ```bash
   sleep 10 && ss -tlnp | grep 9000
   curl -s -X POST http://localhost:9000 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"sui_getChainIdentifier","params":[]}'
   ```

### 7.2 디스크 풀 시

1. **상황 확인**
   ```bash
   df -h /
   du -sh /var/log/* | sort -hr | head -5
   ```

2. **로그 정리**
   ```bash
   sudo rm /var/log/syslog.1
   sudo apt-get clean
   ```

3. **노드 재시작**
   ```bash
   sudo systemctl restart nasun-validator nasun-fullnode
   ```

### 7.3 긴급 연락처

| 역할 | 담당 | 비고 |
|------|------|------|
| 인프라 관리 | - | AWS 콘솔 접근 |
| 개발 담당 | - | 코드 수정 |

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 1.0.0 | 2025-12-23 | 초안 작성 - 디스크 풀 문제 해결 사례 포함 | Claude Code |
