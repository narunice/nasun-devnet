# Nasun Devnet 운영 가이드

**Version**: 5.1.0
**Created**: 2025-12-23
**Updated**: 2026-02-04
**Author**: Claude Code
**Status**: 운영 중 (V7, 2-Node)

---

## 목차

1. [운영 개요](#1-운영-개요)
2. [인프라 현황](#2-인프라-현황)
3. [서비스 관리](#3-서비스-관리)
4. [로그 관리](#4-로그-관리)
5. [문제 해결 사례](#5-문제-해결-사례)
6. [모니터링 명령어](#6-모니터링-명령어)
7. [긴급 대응 절차](#7-긴급-대응-절차)
8. [중앙화된 ID 관리](#8-중앙화된-id-관리-nasundevnet-config)
9. [향후 계획](#9-향후-계획)

---

## 1. 운영 개요

### 1.1 네트워크 정보

| 항목 | 값 |
|------|-----|
| **Network Name** | Nasun Devnet |
| **Chain ID** | `272218f1` (2026-02-04 V7 리셋) |
| **Fork Source** | Sui mainnet v1.63.3 |
| **Native Token** | NSN (최소단위: SOE) |
| **Consensus** | Narwhal/Bullshark |
| **Epoch Duration** | 2시간 (7,200,000ms) |
| **DB Pruning** | 3 epoch DBs 유지 |

### 1.2 엔드포인트

| 서비스 | HTTPS | HTTP |
|--------|-------|------|
| RPC | https://rpc.devnet.nasun.io | http://3.38.127.23:9000 |
| Faucet | https://faucet.devnet.nasun.io | http://3.38.127.23:5003 |
| Explorer | https://explorer.devnet.nasun.io | - |

> **참고**: V6부터 2-node 아키텍처로 변경. RPC/Faucet은 Node 1 (3.38.127.23)에서 서비스됩니다.

### 1.3 개발 히스토리

| Phase | 내용 | 완료일 |
|-------|------|--------|
| 1-6 | 기본 인프라 구축 (2노드 Devnet) | 2025-12-13 |
| 7 | 토큰 전송 테스트 | 2025-12-13 |
| 8 | Faucet 구축 | 2025-12-14 |
| 9 | 스마트 컨트랙트 배포 (hello_nasun) | 2025-12-14 |
| 10 | HTTPS 설정 (Let's Encrypt) | 2025-12-15 |
| 11 | 지갑 구현 (Explorer 내장) | 2025-12-18 |
| **V3 리셋** | Sui mainnet v1.63.0 기반 재구축 | 2025-12-25 |
| **V4 리셋** | zkLogin 호환 (v1.62.1 mainnet) | 2026-01-02 |
| **V5 리셋** | 2시간 epoch, NSN 토큰, DB pruning | 2026-01-17 |
| **3-Node 전환** | Fullnode/Faucet 전용 Node 3 추가, Node 1 Validator 전용화 | 2026-01-23 |
| **V5 복구** | Execution engine halt → authorities_db 초기화 복구 | 2026-01-23 |
| **V6 리셋** | 2-Node 아키텍처로 전환, 전체 Genesis 리셋 | 2026-01-27 |
| **디스크 인시던트** | EBS 48GB→100GB 확장, 3-tier 모니터링 | 2026-02-03 |
| **V7 리셋** | Node 1 t3.xlarge 업그레이드, fullnode sync 문제 해결 | **2026-02-04** |

---

## 2. 인프라 현황

### 2.1 EC2 인스턴스 (2-Node 아키텍처, V7)

| 노드 | IP | 역할 | 인스턴스 타입 | Instance ID | 상태 |
|------|-----|------|--------------|-------------|------|
| nasun-node-1 | 3.38.127.23 | **Validator + Fullnode + Faucet + nginx** | **t3.xlarge (16GB)** | i-040cc444762741157 | ✅ 운영 중 |
| nasun-node-2 | 3.38.76.85 | **Validator Only** | t3.large (8GB) | i-049571787762752ba | ✅ 운영 중 |
| nasun-node-3 | 52.78.117.96 | (중지됨) | t3.large | i-0385f4fe2c8b7bc81 | ⏹️ 중지 |

> **인스턴스 업그레이드 (2026-02-04 V7)**: Node 1을 t3.large(8GB) → t3.xlarge(16GB)로 업그레이드.
> Fullnode + Validator + Faucet을 동시에 운영하기 위한 메모리 확보.
> t3a (AMD)는 ap-northeast-2b AZ에서 미지원하여 t3 (Intel) 유지.

**Auto Recovery 설정** (2026-01-01):
| 알람 이름 | 인스턴스 ID | 상태 |
|----------|-------------|------|
| nasun-node-1-auto-recovery | i-040cc444762741157 | ✅ OK |
| nasun-node-2-auto-recovery | i-049571787762752ba | ✅ OK |

인스턴스 상태 체크 실패 시 자동으로 복구됩니다.

### 2.2 스토리지

| 노드 | EBS | 주요 디렉토리 | 현재 사용량 (2026-02-03) |
|------|-----|--------------|-------------------------|
| Node 1 | **100GB gp3** | `~/.sui/sui_config/authorities_db/`, `~/full_node_db/` | 6% (~5.7GB) |
| Node 2 | **100GB gp3** | `~/.sui/sui_config/authorities_db/` | 6% (~5.3GB) |

> **V7 리셋 (2026-02-04)**: 전체 데이터 초기화. 디스크 사용량 6%로 리셋됨.

**DB Pruning 설정** (현재 상태):
```yaml
authority-store-pruning-config:
  num-latest-epoch-dbs-to-retain: 3    # 3개 epoch DB 유지
  epoch-db-pruning-period-secs: 3600   # 1시간마다 pruning
  num-epochs-to-retain: 50             # 50 epoch 보관 (2026-02-03 수정)
```

> **주의**: Validator의 경우 SUI 코드가 `num-epochs-to-retain: 50`을 무시하고 aggressive pruner(0)로
> 강제 리셋합니다. Fullnode는 설정값(50)을 유지합니다.

- **Config 경로**: `~/.sui/sui_config/`

### 2.3 스왑 메모리

메모리 부족으로 인한 노드 크래시 방지를 위해 모든 노드에 2GB 스왑 설정:

| 노드 | 스왑 파일 | 크기 |
|------|----------|------|
| Node 1 | /swapfile | 2GB |
| Node 2 | /swapfile | 2GB |
| Node 3 | /swapfile | 2GB |

```bash
# 스왑 상태 확인
swapon --show
free -h

# 스왑 비활성화 시 재활성화
sudo swapon /swapfile
```

### 2.4 SSH 접속

```bash
# Node 1 (Validator + Fullnode + Faucet + nginx)
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.127.23

# Node 2 (Validator)
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.76.85
```

---

## 3. 서비스 관리

### 3.1 systemd 서비스 배치 (2-Node 아키텍처, V6)

| 노드 | 서비스 | 설명 | 포트 |
|------|--------|------|------|
| Node 1 | `nasun-validator` | Validator | 8080, 8084 |
| Node 1 | `nasun-fullnode` | Fullnode (RPC) | 9000 |
| Node 1 | `nasun-faucet` | Faucet | 5003 |
| Node 1 | `nginx` | HTTPS 리버스 프록시 | 443 |
| Node 2 | `nasun-validator` | Validator | 8080, 8084 |

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

### 3.4 현재 서비스 설정 (Node 1)

**nasun-fullnode.service**
```ini
[Unit]
Description=Nasun Fullnode (RPC)
After=network.target nasun-validator.service

[Service]
Type=simple
User=ubuntu
Environment="RUST_LOG=warn"
ExecStart=/home/ubuntu/sui-node --config-path /home/ubuntu/.sui/sui_config/fullnode.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**nasun-faucet.service**
```ini
[Unit]
Description=Nasun Devnet Faucet
After=network.target nasun-fullnode.service

[Service]
Type=simple
User=ubuntu
Environment="RUST_LOG=warn"
Environment="SUI_CONFIG_DIR=/home/ubuntu/.sui/sui_config"
ExecStart=/home/ubuntu/sui-faucet --host-ip 0.0.0.0 --port 5003 --amount 100000000000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**중요**: 모든 서비스에 `RUST_LOG=warn` 환경변수가 설정되어 있어야 로그량이 줄어듭니다.

---

## 4. 로그 관리

### 4.1 로그 레벨 설정

SUI 노드는 기본적으로 INFO 레벨 로그를 syslog에 기록합니다.
**RUST_LOG=warn** 설정으로 로그량을 99% 이상 줄일 수 있습니다.

| 로그 레벨 | 예상 일간 로그량 |
|----------|-----------------|
| INFO (기본) | ~3.4GB/일 |
| WARN (권장) | ~6MB/일 |

### 4.2 logrotate 설정 (2025-12-25 최적화)

`/etc/logrotate.d/rsyslog`:

```
/var/log/syslog
/var/log/mail.log
/var/log/kern.log
/var/log/auth.log
/var/log/user.log
/var/log/cron.log
{
    rotate 3
    daily
    maxsize 100M
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

**주요 변경점 (2025-12-25)**:
- `maxsize`: 500MB → **100MB** (더 자주 로테이션)
- `rotate`: 3개 보관 유지
- `daily`: 일간 로테이션

### 4.3 journald 설정 (2025-12-25 추가)

`/etc/systemd/journald.conf`:

```ini
[Journal]
SystemMaxUse=500M
SystemKeepFree=1G
MaxRetentionSec=7day
MaxFileSec=1day
```

| 설정 | 값 | 설명 |
|------|-----|------|
| SystemMaxUse | 500MB | 전체 저널 최대 크기 |
| SystemKeepFree | 1GB | 디스크 최소 여유 공간 |
| MaxRetentionSec | 7일 | 로그 보관 기간 |
| MaxFileSec | 1일 | 개별 파일 최대 기간 |

```bash
# journald 설정 적용
sudo systemctl restart systemd-journald
```

### 4.4 디스크 사용량 확인

```bash
# 전체 디스크 사용량
df -h /

# syslog 크기
ls -lh /var/log/syslog*

# 디렉토리별 사용량
du -sh /home/ubuntu/* | sort -hr | head -10

# journald 디스크 사용량
journalctl --disk-usage
```

### 4.5 디스크 모니터링 스크립트 (2026-01-01 추가, 2026-02-03 강화)

양 노드에 `/home/ubuntu/disk-monitor.sh` 스크립트 설치:

```bash
#!/bin/bash
USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
HOSTNAME=$(hostname)

if [ "$USAGE" -ge 90 ]; then
    SUBJECT="CRITICAL: Nasun Devnet Disk ${USAGE}% - ${HOSTNAME}"
    MESSAGE="CRITICAL: Disk usage at ${USAGE}% on ${HOSTNAME}. Immediate action required - services may crash."
elif [ "$USAGE" -ge 80 ]; then
    SUBJECT="WARNING: Nasun Devnet Disk ${USAGE}% - ${HOSTNAME}"
    MESSAGE="WARNING: Disk usage at ${USAGE}% on ${HOSTNAME}. Consider expanding EBS or cleaning up data."
elif [ "$USAGE" -ge 70 ]; then
    SUBJECT="NOTICE: Nasun Devnet Disk ${USAGE}% - ${HOSTNAME}"
    MESSAGE="NOTICE: Disk usage at ${USAGE}% on ${HOSTNAME}. Monitor growth trend."
else
    exit 0
fi

echo "$MESSAGE" | logger -t disk-monitor
aws sns publish --topic-arn arn:aws:sns:ap-northeast-2:150674276464:nasun-devnet-alerts \
  --message "$MESSAGE" \
  --subject "$SUBJECT" 2>/dev/null || true
```

**Cron 설정** (매시간 실행):
```
0 * * * * /home/ubuntu/disk-monitor.sh
```

### 4.6 SNS 알림 설정 (2026-01-01 추가)

| 항목 | 값 |
|------|-----|
| **토픽 이름** | nasun-devnet-alerts |
| **토픽 ARN** | `arn:aws:sns:ap-northeast-2:150674276464:nasun-devnet-alerts` |
| **구독 이메일** | naru@nasun.io |

**알림 트리거**:
- EC2 Auto Recovery (인스턴스 상태 체크 실패)
- 디스크 사용량 70% NOTICE / 80% WARNING / 90% CRITICAL (2026-02-03 단계별 강화)
- 체크포인트 5분 이상 멈춤 (합의 장애)

### 4.7 체크포인트 모니터링 및 자동 복구 (2026-01-01 추가)

양 노드에 `/home/ubuntu/checkpoint-monitor.sh` 스크립트 설치:

**Node 1/2 버전** (validator 재시작, Node 1 RPC 모니터링, SNS 알림):
```bash
#!/bin/bash
RPC_URL="http://3.38.127.23:9000"
STATE_FILE="/home/ubuntu/.checkpoint_state"
STALE_THRESHOLD=5  # 5분

CURRENT=$(curl -s -X POST $RPC_URL \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getLatestCheckpointSequenceNumber","params":[]}' \
  | jq -r '.result // "error"')

if [ -f "$STATE_FILE" ]; then
  read PREV_CHECKPOINT STALE_COUNT < "$STATE_FILE"
else
  PREV_CHECKPOINT=0; STALE_COUNT=0
fi

if [ "$CURRENT" = "$PREV_CHECKPOINT" ] && [ "$CURRENT" != "error" ]; then
  STALE_COUNT=$((STALE_COUNT + 1))
else
  STALE_COUNT=0
fi

echo "$CURRENT $STALE_COUNT" > "$STATE_FILE"

if [ "$STALE_COUNT" -ge "$STALE_THRESHOLD" ]; then
  aws sns publish --topic-arn arn:aws:sns:ap-northeast-2:150674276464:nasun-devnet-alerts \
    --message "ALERT: Checkpoint stuck at $CURRENT for ${STALE_COUNT}min. Restarting..." \
    --subject "Nasun Devnet Consensus Alert" 2>/dev/null || true
  sudo systemctl restart nasun-validator
  echo "$CURRENT 0" > "$STATE_FILE"
  logger -t checkpoint-monitor "Restarted validator due to stale checkpoint"
fi
```

**Cron 설정** (매분 실행):
```
* * * * * /home/ubuntu/checkpoint-monitor.sh
```

| 노드 | RPC URL | 재시작 대상 | SNS 알림 |
|------|---------|------------|----------|
| Node 1 | localhost:9000 | validator + fullnode | O |
| Node 2 | 3.38.127.23:9000 | validator | X |

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

### 5.3 Node 2 syslog 9.1GB 문제 (2025-12-25)

**증상**:
- Node 2 디스크 사용량 28%로 급증
- `/var/log/syslog` 파일이 9.1GB 차지

**원인**:
- Node 2에 `RUST_LOG=warn` 미적용
- journald 용량 제한 미설정

**해결**:
1. 긴급 로그 정리
   ```bash
   sudo truncate -s 0 /var/log/syslog
   ```
2. logrotate 설정 강화 (maxsize 100M)
3. journald 제한 설정 추가
4. 디스크 사용량 9%로 정상화

### 5.4 V3 리셋 중 노드 동기화 문제 (2025-12-25)

**증상**:
- 체크포인트 265에서 진행 멈춤
- 두 노드 간 genesis 불일치

**원인**:
- genesis.blob 동기화 실패
- 이전 DB 잔여 데이터 충돌

**해결**:
1. 양 노드 DB 완전 삭제
   ```bash
   rm -rf ~/authorities_db ~/consensus_db ~/.nasun
   ```
2. genesis.blob 재동기화 (Node 1 → Node 2)
3. 두 노드 동시 재시작
4. 새 Chain ID `6681cdfd`로 정상 진행

**교훈**:
- V3 리셋 시 모든 데이터 완전 삭제 필수
- genesis.blob MD5 해시 비교로 동일성 확인

### 5.5 Node 1 Impaired 상태 복구 (2026-01-01)

**증상**:
- Explorer에서 "Disconnected" 표시
- SSH/RPC 접속 모두 타임아웃
- EC2 Instance Status: `impaired`

**원인**:
- EC2 인스턴스 내부 문제 (정확한 원인 불명)
- 디스크 사용량 60%로 정상 범위였음

**해결**:
1. AWS EC2 상태 확인
   ```bash
   aws ec2 describe-instance-status --instance-ids i-040cc444762741157
   # InstanceStatus: impaired, SystemStatus: ok
   ```
2. Reboot 시도 → 실패 (stopping 상태 유지)
3. Force Stop → Start로 복구
   ```bash
   aws ec2 stop-instances --instance-ids i-040cc444762741157 --force
   aws ec2 start-instances --instance-ids i-040cc444762741157
   ```
4. 모든 서비스 정상 복구

**후속 조치**:
- EC2 Auto Recovery 알람 설정 (양 노드)
- 디스크 모니터링 스크립트 설치 (매시간)
- SNS 이메일 알림 구성

### 5.6 합의 멈춤 (Consensus Stuck) 복구 (2026-01-01)

**증상**:
- Explorer에서 TPS 0tx/s 표시
- 체크포인트 2269299에서 멈춤 (14시간 이상)

**원인**:
- Node 1이 impaired 상태에서 Force Stop → Start로 복구됨
- 복구 후 Node 2와의 합의 상태 불일치
- 2노드 시스템에서 한 노드 상태 변경 시 합의 교착 발생

**해결**:
1. 양 노드 Validator 동시 재시작
   ```bash
   # Node 1에서
   sudo systemctl restart nasun-validator
   # Node 2에서
   sudo systemctl restart nasun-validator
   ```
2. Fullnode 재시작
   ```bash
   sudo systemctl restart nasun-fullnode
   ```
3. 체크포인트 진행 확인 (2269299 → 2269364)

**후속 조치**:
- 체크포인트 모니터링 스크립트 설치 (양 노드)
- 5분간 멈춤 시 자동 복구 및 SNS 알림

### 5.7 Node 1 반복 크래시 및 3-Node 아키텍처 전환 (2026-01-23)

**증상**:
- Node 1이 반복적으로 Disconnected 상태 발생 (3회 이상)
- SSH 접속 불가, Force Stop/Start로 복구 반복
- 복구 후에도 수일 내 재발

**원인**:
- Node 1에서 Validator + Fullnode (2개 sui-node 프로세스) 동시 실행
- c6i.xlarge (8GB RAM)에서 메모리/리소스 경합
- Swap 설정으로도 완전한 방지 불가

**해결**:
1. Node 3 (t3.large, 52.78.117.96) 추가
2. Fullnode + Faucet + nginx를 Node 3으로 이전
3. Node 1은 Validator Only로 변경
4. DNS (rpc.devnet.nasun.io, faucet.devnet.nasun.io) → Node 3으로 변경
5. SSL 인증서 Node 3에서 발급

**결과**: 각 노드가 단일 sui-node 프로세스만 실행하여 안정성 확보.

### 5.8 V5 Execution Engine Halt 및 복구 (2026-01-23)

**증상**:
- 양 validator에서 `Failed to send certified blocks: SendError` 경고 지속
- 새 체크포인트 생성 중단 (20시간 이상)
- Faucet/RPC 정상 응답하지만 체크포인트 멈춤

**원인**:
- Execution engine의 내부 채널 receiver가 drop됨
- Consensus는 블록을 계속 생성하지만, execution이 처리 불가
- 정확한 트리거 불명 (Jan 22 08:30경 발생)

**해결 시도**:
1. **consensus_db만 삭제** → 실패
   - `assertion failed: Commit replay should start at the beginning`
   - authorities_db에 commit index 59496 기록 vs consensus_db 비어있음 → 불일치

2. **authorities_db + consensus_db 모두 삭제** → 성공
   ```bash
   # 양 노드에서 실행
   sudo systemctl stop nasun-validator
   rm -rf ~/.sui/sui_config/authorities_db/
   rm -rf ~/.sui/sui_config/consensus_db/
   sudo systemctl start nasun-validator
   ```
   - 기존 genesis.blob으로 epoch 0부터 재시작
   - Chain ID 유지 (`56c8b101`)
   - **모든 온체인 상태 초기화** (컨트랙트, 트랜잭션 히스토리 삭제)

3. Node 3 fullnode도 DB 삭제 후 재동기화
   ```bash
   sudo systemctl stop nasun-fullnode
   rm -rf ~/full_node_db/
   sudo systemctl start nasun-fullnode
   ```

**교훈**:
- `consensus_db`와 `authorities_db`는 commit index로 연동되어 있어 하나만 삭제 불가
- Execution engine halt 시 전체 DB 초기화가 유일한 복구 방법
- "Failed to send certified blocks" 에러가 지속되면 네트워크 halt 상태 의심
- 복구 후에도 해당 WARN 로그가 표시되지만 기능에는 영향 없음

### 5.9 V6 리셋 및 2-Node 아키텍처 전환 (2026-01-27)

**배경**:
V5 네트워크에서 3-Node 아키텍처 (Node 1,2: Validator, Node 3: Fullnode+Faucet)를 운영 중
Node 3 (t3.large, 8GB RAM)이 Fullnode 운영에 메모리 부족으로 반복 크래시 발생.

**V5에서 발생한 문제들**:
1. Node 3 메모리 부족으로 인한 반복적인 Fullnode 크래시
2. "thread stall" 및 "slow DB writes" 경고 지속
3. Fullnode가 Validator와 동기화 유지 실패
4. 합의 오류로 인한 체크포인트 진행 멈춤

**V6 전환 결정 이유**:
1. **비용 절감**: Node 3 제거로 월 ~$60 절감 ($180 → $120)
2. **안정성 확보**: t3.large가 Fullnode에 부적합, c6i.xlarge에서 운영
3. **단순화**: 3-node 아키텍처의 복잡성 제거
4. **합의 오류 복구**: V5에서 발생한 합의 오류를 Genesis 리셋으로 해결

**전환 작업 (2026-01-27)**:
1. Node 3 서비스 중지 및 EC2 인스턴스 Stop
2. Node 1/2에서 모든 DB 삭제
3. Node 1에서 새 Genesis 생성 (2시간 epoch 유지)
4. Fullnode 설정을 Node 1으로 이동
5. Faucet 및 nginx 설정을 Node 1으로 이동
6. DNS (rpc/faucet.devnet.nasun.io) A 레코드를 Node 1 IP로 변경
7. SSL 인증서 Node 1에서 재발급 (certbot)
8. 모든 스마트 컨트랙트 재배포

**결과**:
- Chain ID: `12bf3808`
- 2-Node 아키텍처 안정 운영
- 모든 서비스 정상 작동 (RPC, Faucet, HTTPS)

**현재 상태 (2026-01-27 기준)**:
| 항목 | 상태 |
|------|------|
| Chain ID | `12bf3808` |
| 체크포인트 | 진행 중 (20000+) |
| Node 1 (Validator+Fullnode+Faucet) | ✅ 정상 |
| Node 2 (Validator) | ✅ 정상 |
| RPC (https://rpc.devnet.nasun.io) | ✅ 정상 |
| Faucet (https://faucet.devnet.nasun.io) | ✅ 정상 |
| 디스크 사용량 | Node 1: 16%, Node 2: 13% |

### 5.10 디스크 100% - DB Pruning 미작동 (2026-02-03)

**증상**:
- 네트워크 disconnected 상태 (RPC 502, 서비스 크래시)
- Node 1: `/dev/root` 48GB 중 48GB 사용 (100%)
- Validator, Fullnode 모두 `signal=ABRT` (core-dump)로 crash-looping
- SSH 접속 불가 (Security Group IP 제한)

**근본 원인**:
1. `num-epochs-to-retain: 0`으로 설정되어 있었지만, 이 값은 가장 공격적인 pruning이 아닌
   **모든 epoch 보관**을 의미할 수 있음 (SUI 버전에 따라 동작 다름)
2. 7일간 DB가 무제한 성장: authorities_db 18GB + full_node_db 24GB = 42GB
3. 로그 및 OS까지 합산하여 48GB 디스크 100% 도달
4. SSH는 `125.134.72.215/32`만 허용되어 현재 IP(`115.22.178.82`)에서 접속 불가

**DB 크기 분석 (장애 시점)**:
| 디렉토리 | 크기 | 설명 |
|----------|------|------|
| `authorities_db/live/store` | 9.7GB | Validator object store |
| `authorities_db/live/checkpoints` | 2.7GB | Validator checkpoint data |
| `full_node_db/live/store` | ~15GB | Fullnode object store |
| `full_node_db/live/checkpoints` | ~7GB | Fullnode checkpoint data |
| `/var/log` + journal | ~1.5GB | 로그 |

**복구 절차**:
1. AWS CLI로 Security Group에 현재 IP SSH 허용 추가
2. SSH 접속 후 서비스 중지
3. `full_node_db` 삭제 (24GB 확보)
4. Pruning 설정 수정: `num-epochs-to-retain: 0` → `50` (양쪽 노드)
5. 서비스 재시작 (Validator, Fullnode)
6. Fullnode DB genesis부터 재구축 대기
7. Faucet 재시작 (Fullnode 동기화 완료 후)

**추가 조치 (재발 방지)**:
1. **EBS 볼륨 확장**: 양쪽 노드 50GB → 100GB (무중단, `modify-volume` + `growpart` + `resize2fs`)
2. **디스크 모니터링 강화**: 80% 단일 임계값 → 70% NOTICE / 80% WARNING / 90% CRITICAL
3. **Pruning 설정 수정 확인**: Validator는 SUI 코드가 aggressive(0)로 override, Fullnode는 50 유지

**SUI Pruning 동작 참고**:
```
# Validator 시작 시 로그:
WARN sui_core::authority::authority_store_pruner:
  Using objects pruner with num_epochs_to_retain = 50 can lead to performance issues
WARN sui_core::authority::authority_store_pruner:
  Resetting to aggressive pruner.

# Fullnode 시작 시 로그:
WARN sui_core::authority::authority_store_pruner:
  Consider using an aggressive pruner (num_epochs_to_retain = 0)
```
Validator는 config 값을 무시하고 aggressive pruning으로 강제 전환됨.
Fullnode는 경고만 표시하고 설정값(50)을 유지.

**교훈**:
- 48GB는 Validator + Fullnode 동시 운영에 불충분
- Pruning 설정만으로는 디스크 안전을 보장할 수 없음 (충분한 디스크 + 모니터링 필수)
- Security Group SSH IP를 동적 IP 환경에서 관리할 대책 필요
- 디스크 장애 시 full_node_db 삭제로 대량 공간 확보 가능 (Fullnode는 자동 재구축)

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

## 8. 중앙화된 ID 관리 (@nasun/devnet-config)

### 8.1 개요

Devnet 리셋 후 10개 이상의 파일에서 ID를 수동 업데이트하던 문제를 해결하기 위해 `@nasun/devnet-config` 패키지를 도입했습니다.

**도입 전 문제점:**
- Devnet 리셋 시 10+ 파일에서 수동 ID 업데이트 필요
- 실수로 구버전 ID 사용 시 런타임 에러
- 업데이트 시간 30분+

**도입 후:**
- JSON 파일 1개만 수정
- `pnpm devnet:sync`로 .env 자동 동기화
- 업데이트 시간 5분

### 8.2 새로운 Devnet 리셋 워크플로우

```bash
# 1. 스마트 컨트랙트 배포 후 ID 기록

# 2. devnet-ids.json 업데이트 (단일 소스)
cd /home/naru/my_apps/nasun-monorepo
vi packages/devnet-config/devnet-ids.json

# 3. .env 파일 자동 동기화
pnpm devnet:sync

# 4. 커밋
git add . && git commit -m "chore: update devnet IDs for V7"
```

### 8.3 devnet-ids.json 구조

```json
{
  "version": "V7",
  "lastUpdated": "2026-02-04",
  "admin": "0xe1c4c90b...",
  "network": {
    "chainId": "272218f1",
    "rpcUrl": "http://3.38.127.23:9000",
    "faucetUrl": "https://faucet.devnet.nasun.io",
    "explorerUrl": "https://explorer.nasun.io/devnet"
  },
  "tokens": { "packageId": "...", "tokenFaucet": "...", "claimRecord": "...", "upgradeCap": "..." },
  "deepbook": { "tokenPackageId": "...", "packageId": "...", "registry": "...", "adminCap": "..." },
  "prediction": { "packageId": "...", "globalState": "...", "adminCap": "...", "upgradeCap": "..." },
  "lottery": { "packageId": "...", "registry": "...", "adminCap": "...", "upgradeCap": "..." },
  "governance": { "packageId": "...", "dashboard": "...", "adminCap": "...", "votingPowerOracle": "...", "certificateRegistry": "...", "proposalTypeRegistry": "..." },
  "baram": {
    "packageId": "...", "registry": "...", "upgradeCap": "...",
    "executorPackageId": "...", "executorRegistry": "...", "executorAdminCap": "...", "executorUpgradeCap": "...",
    "stakingConfig": "...", "stakingRegistry": "...", "stakingAdminCap": "...", "tierRegistry": "...",
    "processedRequests": "...",
    "attestationPackageId": "...", "attestationRegistry": "...", "attestationAdminCap": "...", "attestationUpgradeCap": "...",
    "compliancePackageId": "...", "complianceRegistry": "...", "complianceAdminCap": "...", "complianceUpgradeCap": "..."
  },
  "pools": { "nbtcNusdc": "...", "nsnNusdc": "..." },
  "oracle": { "packageId": "...", "registry": "...", "adminCap": "...", "upgradeCap": "..." },
  "lending": { "packageId": "...", "pool": "...", "adminCap": "...", "upgradeCap": "..." },
  "margin": { "packageId": "...", "registry": "...", "upgradeCap": "..." },
  "perp": { "packageId": "...", "btcMarket": "...", "upgradeCap": "..." },
  "nsa": { "packageId": "...", "upgradeCap": "..." }
}
```

### 8.4 마이그레이션된 파일

| 앱 | 파일 | 변경 내용 |
|----|------|----------|
| @nasun/wallet | `src/config/tokens.ts` | NBTC_TYPE, NUSDC_TYPE import |
| @nasun/wallet | `src/sui/tokenFaucet.ts` | TOKENS_PACKAGE_ID, TOKEN_FAUCET import |
| Pado | `features/prediction/constants.ts` | @nasun/devnet-config에서 import |
| Pado | `features/lottery/constants.ts` | @nasun/devnet-config에서 import |
| Baram | `config/network.ts` | fallback을 devnet-config에서 import |
| Nasun Website | `constants/suiPackageConstants.ts` | @nasun/devnet-config에서 import |

### 8.5 패키지 위치

```
packages/devnet-config/
├── package.json
├── devnet-ids.json          # 단일 소스 of truth
├── src/
│   ├── index.ts             # 메인 export
│   ├── types.ts             # 타입 정의
│   └── ids/                 # 도메인별 ID export
│       ├── network.ts
│       ├── tokens.ts
│       ├── deepbook.ts
│       ├── prediction.ts
│       ├── lottery.ts
│       ├── governance.ts
│       └── baram.ts
└── scripts/
    └── sync-env.ts          # .env 동기화 스크립트
```

### 8.6 통합 토큰 패키지 (packages/devnet-tokens)

모든 나선 앱에서 공용으로 사용하는 NBTC/NUSDC 토큰 패키지.

**위치**: `nasun-monorepo/packages/devnet-tokens/`

**포함 컨트랙트**:
| 파일 | 설명 |
|------|------|
| `nbtc.move` | NBTC (8 decimals) - Nasun Network Test BTC |
| `nusdc.move` | NUSDC (6 decimals) - Nasun Network Test USDC |
| `faucet.move` | 통합 TokenFaucet (24시간 cooldown rate limiting) |

**V7 배포 ID**:
| 항목 | Object ID |
|------|-----------|
| Package | `0x96adf476d488ffb588d0bfdb5c422355f065386a2e7124e66746fb7078816731` |
| TokenFaucet | `0x7cc75ad1f00f65589074ba9a8f0ad4922b2be3bfef31c22c66d137bc8dbced92` |
| ClaimRecord | `0x6416304b56cd61238fe552ddb3d07ecc4c12c749fc7038b04d20de3e52953fe1` |
| UpgradeCap | `0xef52338fb8b2f564938f830ae2822818dfce49491508d95bcc85c0e3e7ddf269` |

**Devnet 리셋 후 업데이트 필요 파일**:
- `packages/devnet-tokens/Move.toml` - published-at, addresses 섹션
- `packages/devnet-config/devnet-ids.json` - tokens 섹션

> **배경**: 기존에 Pado 앱과 Baram 앱이 각각 별도의 NUSDC를 사용하여 혼란이 발생.
> 이를 해결하기 위해 모든 앱에서 공용으로 사용할 수 있는 통합 토큰 패키지 생성.

### 8.7 V7 스마트 컨트랙트 배포 방법론

V7에서 확립된 15개 컨트랙트 배포 방법론입니다.

**배포 명령어 패턴**:

| 유형 | 명령어 |
|------|--------|
| 독립 패키지 (의존성 없음) | `sui client test-publish --build-env devnet --gas-budget 500000000` |
| devnet_tokens 의존 패키지 | `sui client test-publish --build-env devnet --pubfile-path /home/naru/my_apps/nasun-monorepo/Pub.devnet.toml --gas-budget 500000000` |

> **주의**: `--with-unpublished-dependencies`를 이미 배포된 의존성에 사용하면 안 됩니다.
> 이 플래그는 의존성을 번들링하여 별도의 타입을 생성하므로 타입 호환성이 깨집니다.
> 대신 `--pubfile-path`로 공유 `Pub.devnet.toml` 파일을 지정하세요.

**3-tier 배포 순서**:

| Tier | 컨트랙트 | 의존성 |
|------|---------|--------|
| **Tier 1** (독립) | devnet_tokens, deepbook_token, deepbook, governance, nsa, baram_executor, baram_attestation, baram_compliance | 없음 |
| **Tier 2** (devnet_tokens 의존) | prediction, lottery, oracle, lending, baram | devnet_tokens |
| **Tier 3** (다중 의존) | margin, perp | devnet_tokens + 기타 |

**공유 Pub.devnet.toml**:

`test-publish` 명령은 배포 시 자동으로 `Pub.devnet.toml`에 패키지 엔트리를 추가합니다.
`--pubfile-path`로 모노레포 루트의 공유 파일을 지정하면, 이전 Tier에서 배포된 패키지의
주소를 후속 배포에서 자동으로 참조할 수 있습니다.

**배포 후 추가 생성이 필요한 공유 객체 (Post-deploy)**:

일부 컨트랙트는 `init()` 함수에서 모든 공유 객체를 생성하지 않습니다.
다음 객체들은 배포 후 별도의 트랜잭션으로 생성해야 합니다:

| 객체 | 생성 방법 | 비고 |
|------|----------|------|
| ProposalTypeRegistry | `governance::proposal::init_type_registry` | AdminCap 필요 |
| TierRegistry | `baram_executor::executor_tier::create_tier_registry` | AdminCap 필요 |
| BTC PerpMarket | `pado_perp::perpetual::create_market` | AdminCap 필요 |
| CertificateRegistry | PTB: `create_registry` + `share_registry` | 2-step PTB |
| VotingPowerOracle | PTB: `create_oracle` + `share_oracle` | Ed25519 공개키 필요 |
| NBTC/NUSDC Pool | `deepbook::pool::create_pool_admin` | 토큰 타입 인자 필요 |
| NSN/NUSDC Pool | `deepbook::pool::create_pool_admin` | 토큰 타입 인자 필요 |

---

## 9. 향후 계획

### 9.1 Graviton (ARM) 전환 계획

향후 리셋(V8+) 시 비용 절감을 위해 ARM 아키텍처로 전환 검토.

> **V7 상황**: V7은 Node 1을 t3.large → t3.xlarge로 업그레이드하여 메모리 문제를 해결했으나,
> ARM 전환은 수행하지 않았습니다 (t3a가 ap-northeast-2b AZ에서 미지원, Graviton은 별도 인스턴스 생성 필요).

**전환 이유**:
- Graviton (c7g.xlarge)은 x86 (현재 t3.xlarge) 대비 성능/비용 우위
- Sui는 ARM (aarch64) 공식 지원
- 월 비용 절감 가능

**Move 스마트 컨트랙트**:
- Move 바이트코드는 플랫폼 독립적이므로 재빌드 불필요
- 로컬 개발 환경 (x86)과 서버 (ARM) 아키텍처 차이는 개발에 영향 없음

### 9.2 Compute Savings Plan 적용

인스턴스 타입이 안정화된 후, **Compute Savings Plan** (1년 No Upfront)을 적용하여 추가 비용 절감.

**Savings Plan 선택 이유**:
- Reserved Instance보다 유연함 (리전, 인스턴스 패밀리 변경 가능)
- EC2, Fargate, Lambda 모두 적용
- 인스턴스 수가 아닌 시간당 사용액($) 기준 약정

> **현재 상태**: V7에서 Node 1이 t3.xlarge (16GB)로 변경되어 인스턴스 구성이 안정화됨.
> ARM 전환 여부를 결정한 후 Savings Plan 구매 권장.

### 9.3 Faucet 설정

V7에서 NSN faucet 설정:

```bash
# /etc/systemd/system/nasun-faucet.service
ExecStart=/home/ubuntu/sui-faucet --host-ip 0.0.0.0 --port 5003 --amount 100000000000
# --amount 100 NSN × --num-coins 5 (기본값) = 500 NSN 총
```

| 버전 | 설정 | 결과 |
|------|------|------|
| V7 (현재) | `--amount 100000000000` | 500 NSN (100×5) |

> **참고**: 필요 시 `--amount 20000000000`으로 변경하여 100 NSN (20×5)으로 줄일 수 있음.

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 1.0.0 | 2025-12-23 | 초안 작성 - 디스크 풀 문제 해결 사례 포함 | Claude Code |
| 1.1.0 | 2025-12-25 | V3 리셋 반영 (Chain ID: 6681cdfd), journald 설정 추가, 로그 관리 최적화, 새 문제 해결 사례 추가 | Claude Code |
| 1.2.0 | 2026-01-01 | EC2 Auto Recovery 설정, 디스크 모니터링 스크립트, SNS 알림 설정, Node 1 impaired 복구 사례 추가 | Claude Code |
| 1.3.0 | 2026-01-01 | 체크포인트 모니터링 및 자동 복구 스크립트 추가, 합의 멈춤 복구 사례 추가 | Claude Code |
| 2.0.0 | 2026-01-17 | V5 리셋 반영 (Chain ID: 56c8b101, 2시간 epoch, NSN 토큰, DB pruning), 스왑 설정 추가 | Claude Code |
| 3.0.0 | 2026-01-23 | 3-Node 아키텍처 전환 (Node 3 추가), V5 execution halt 복구 사례, 서비스 배치/엔드포인트 업데이트 | Claude Code |
| 4.0.0 | 2026-01-27 | **V6 리셋 및 2-Node 전환** (Chain ID: 12bf3808), Node 3 중지, Node 1에서 Fullnode/Faucet/nginx 통합 운영, 비용 절감 (~$60/월), 전체 컨트랙트 재배포 | Claude Code |
| 4.1.0 | 2026-01-27 | **중앙화된 ID 관리 시스템 도입** (@nasun/devnet-config), Section 8 추가, devnet 리셋 워크플로우 단순화 (10+ 파일 → 1개 JSON) | Claude Code |
| 5.0.0 | 2026-02-04 | **V7 리셋** (Chain ID: 272218f1), Node 1 t3.xlarge(16GB) 업그레이드, 15개 컨트랙트 3-tier 배포, 디스크 100% 인시던트(EBS 100GB 확장) | Claude Code |
| 5.1.0 | 2026-02-04 | V7 배포 방법론 문서화 (Section 8.7), `test-publish --pubfile-path` 패턴, 3-tier 배포 순서, post-deploy 공유 객체 생성 절차, devnet-ids.json V7 구조 반영 | Claude Code |
