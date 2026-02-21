# Nasun Devnet 운영 가이드

**Version**: 7.0.0
**Created**: 2025-12-23
**Updated**: 2026-02-21
**Author**: Claude Code
**Status**: 운영 중 (V7, 3-Node m6i)

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
10. [Indexer Infrastructure](#10-indexer-infrastructure-node-3)

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

| 서비스 | HTTPS | HTTP | 호스트 |
|--------|-------|------|--------|
| RPC | https://rpc.devnet.nasun.io | http://54.180.61.196:9000 | Node 3 |
| Faucet | https://faucet.devnet.nasun.io | http://3.38.127.23:5003 | Node 1 |
| Explorer | https://explorer.devnet.nasun.io | - | prod-ec2 → Node 3 |
| Explorer API | - | http://54.180.61.196:3200 | Node 3 |

> **참고**: 2026-02-21 3-node 마이그레이션 완료. RPC는 Node 3, Faucet은 Node 1에서 서비스됩니다.

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
| **V7 리셋** | Node 1 t3.xlarge 업그레이드, fullnode sync 문제 해결 | 2026-02-04 |
| **3-Node m6i 마이그레이션** | t3→m6i 전환, 역할 분리 (2V+1F), Node 3 신규 | **2026-02-21** |

---

## 2. 인프라 현황

### 2.1 EC2 인스턴스 (3-Node m6i 아키텍처, 2026-02-21)

| 노드 | IP | 역할 | 인스턴스 타입 | Instance ID | 상태 |
|------|-----|------|--------------|-------------|------|
| nasun-node-1 | 3.38.127.23 | **Validator + Faucet + Nginx** | **m6i.large (8GB)** | i-040cc444762741157 | ✅ 운영 중 |
| nasun-node-2 | 3.38.76.85 | **Validator + zkLogin Prover (Docker)** | **m6i.large (8GB)** | i-049571787762752ba | ✅ 운영 중 |
| nasun-node-3 | 54.180.61.196 | **Fullnode (RPC) + sui-indexer + PostgreSQL + Explorer API + Nginx** | **m6i.xlarge (16GB)** | i-0c3b43a7d96de2f09 | ✅ 운영 중 |

> **3-Node 마이그레이션 (2026-02-21)**: t3 Burstable 과부하 해결을 위해 m6i dedicated 인스턴스로 전환.
> 역할 분리: Validator 전용 (node-1,2) + Fullnode/Indexer 전용 (node-3).
> 이전 node-3 (i-0385f4fe2c8b7bc81, t3.large, 52.78.117.96)는 terminated.

**Auto Recovery 설정** (2026-01-01):
| 알람 이름 | 인스턴스 ID | 상태 |
|----------|-------------|------|
| nasun-node-1-auto-recovery | i-040cc444762741157 | ✅ OK |
| nasun-node-2-auto-recovery | i-049571787762752ba | ✅ OK |

인스턴스 상태 체크 실패 시 자동으로 복구됩니다.

### 2.2 스토리지

| 노드 | EBS | 주요 디렉토리 | 비고 |
|------|-----|--------------|------|
| Node 1 | **200GB gp3** | `~/.sui/sui_config/authorities_db/` | Fullnode 제거됨 (node-3으로 이전) |
| Node 2 | **200GB gp3** | `~/.sui/sui_config/authorities_db/` | Indexer/PostgreSQL 제거됨 (node-3으로 이전) |
| Node 3 | **300GB gp3** | `~/full_node_db/`, PostgreSQL data | Fullnode + Indexer + PostgreSQL |

> **3-Node 마이그레이션 (2026-02-21)**: Node 3에 300GB gp3 할당. Fullnode DB + PostgreSQL + data-ingestion 파일 수용.

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

메모리 부족으로 인한 노드 크래시 방지를 위해 스왑 설정:

| 노드 | 스왑 파일 | 크기 | 비고 |
|------|----------|------|------|
| Node 1 | /swapfile | **4GB** | 2026-02-07 확장 (2GB→4GB) |
| Node 2 | /swapfile | 2GB | |
| Node 3 | /swapfile | 4GB | 2026-02-21 마이그레이션 시 설정 |

```bash
# 스왑 상태 확인
swapon --show
free -h

# 스왑 비활성화 시 재활성화
sudo swapon /swapfile
```

### 2.4 SSH 접속

```bash
# Node 1 (Validator + Faucet + Nginx)
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.127.23

# Node 2 (Validator + zkLogin Prover)
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.76.85

# Node 3 (Fullnode + Indexer + PostgreSQL + Explorer API + Nginx)
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@54.180.61.196

# Production EC2 (Explorer 프론트엔드 nginx)
ssh -i ~/.ssh/nasun-prod-key.pem ec2-user@43.200.67.52
```

---

## 3. 서비스 관리

### 3.1 systemd 서비스 배치 (3-Node m6i 아키텍처, 2026-02-21)

| 노드 | 서비스 | 설명 | 포트 |
|------|--------|------|------|
| Node 1 | `nasun-validator` | Validator | 8080, 8084 |
| Node 1 | `nasun-faucet` | Faucet | 5003 |
| Node 1 | `nginx` | Faucet HTTPS 프록시 | 443 |
| Node 2 | `nasun-validator` | Validator | 8080, 8084 |
| Node 2 | `docker` (zkprover) | zkLogin Prover (docker-compose) | 8081 |
| Node 3 | `nasun-fullnode` | Fullnode (RPC) | 9000 |
| Node 3 | `sui-indexer` | Blockchain indexer (systemd) | 9185 (metrics) |
| Node 3 | `postgresql` | PostgreSQL 16 (sui_indexer DB) | 5432 |
| Node 3 | `explorer-api` | Hono REST API (PM2) | 3200 |
| Node 3 | `nginx` | RPC HTTPS + zkprover 프록시 | 443 |

> Note: Node 1의 `nasun-fullnode` 서비스는 disabled 상태 (node-3으로 이전됨).
> Node 2의 `sui-indexer`, `postgresql`, `explorer-api`도 disabled/제거됨.

### 3.2 서비스 관리 명령어

```bash
# Node 1: Validator + Faucet
ssh ubuntu@3.38.127.23 "sudo systemctl status nasun-validator nasun-faucet"

# Node 2: Validator + Prover
ssh ubuntu@3.38.76.85 "sudo systemctl status nasun-validator; docker ps"

# Node 3: Fullnode + Indexer + Explorer
ssh ubuntu@54.180.61.196 "sudo systemctl status nasun-fullnode sui-indexer postgresql; pm2 status"

# Fullnode 로그 (Node 3)
ssh ubuntu@54.180.61.196 "sudo journalctl -u nasun-fullnode -f"

# Validator 로그 (Node 1 or 2)
ssh ubuntu@3.38.127.23 "sudo journalctl -u nasun-validator -f"
```

### 3.3 서비스 설정 파일 위치

**Node 1** (`/etc/systemd/system/`):
- `nasun-validator.service` — Validator
- `nasun-faucet.service` — Faucet (RPC → node-3 VPC 172.31.25.242:9000)
- `nasun-fullnode.service` — **disabled** (node-3으로 이전)

**Node 2** (`/etc/systemd/system/`):
- `nasun-validator.service` — Validator
- zkLogin Prover: `~/zkprover/docker-compose.yml` (Docker)

**Node 3** (`/etc/systemd/system/`):
- `nasun-fullnode.service` — Fullnode (RPC)
- `sui-indexer.service` — Blockchain indexer
- `postgresql.service` — PostgreSQL 16
- Explorer API: PM2 (`~/explorer-api/`)

### 3.4 현재 서비스 설정

**Node 1: nasun-faucet.service**
```ini
[Unit]
Description=Nasun Devnet Faucet
After=network.target

[Service]
Type=simple
User=ubuntu
Environment="RUST_LOG=warn"
Environment="SUI_CONFIG_DIR=/home/ubuntu/.sui/sui_config"
ExecStart=/home/ubuntu/sui-faucet --host-ip 0.0.0.0 --port 5003 --amount 20000000000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

> Faucet RPC: `client.yaml`의 `rpc` 필드가 `http://172.31.25.242:9000` (node-3 VPC) 참조.

**Node 3: nasun-fullnode.service**
```ini
[Unit]
Description=Nasun Fullnode (RPC)
After=network.target

[Service]
Type=simple
User=ubuntu
Environment="RUST_LOG=warn"
ExecStart=/home/ubuntu/nasun-node/sui-node --config-path /home/ubuntu/nasun-node/fullnode.yaml
Restart=always
RestartSec=10
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
```

**Node 3: sui-indexer.service**
```ini
[Unit]
Description=Sui Indexer for Nasun Devnet
After=postgresql.service nasun-fullnode.service
Requires=postgresql.service

[Service]
Type=simple
User=ubuntu
ExecStart=/home/ubuntu/nasun-node/sui-indexer \
  --database-url postgres://sui_indexer:indexer_ec2_2026@localhost:5432/sui_indexer \
  --pool-size 5 --metrics-address 0.0.0.0:9185 \
  indexer --data-ingestion-path /home/ubuntu/nasun-node/data-ingestion \
  --checkpoint-download-queue-size 10
Restart=on-failure
RestartSec=10
MemoryMax=800M
CPUQuota=50%
OOMScoreAdjust=500

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

### 4.7 체크포인트 모니터링 및 자동 복구 (2026-01-01 추가, 2026-02-17 수정)

양 노드에 `/home/ubuntu/checkpoint-monitor.sh` 스크립트 설치:

> **2026-02-17 수정**: Fullnode DB 재동기화(Section 4.9) 진행 중에는 RPC가 정상적으로 내려가므로,
> resync lock 파일 체크를 추가하여 불필요한 validator 재시작을 방지합니다.

**Node 1/2 버전** (validator 재시작, Node 1 RPC 모니터링, SNS 알림):
```bash
#!/bin/bash

# Resync 중에는 스킵 (RPC 다운이 정상이므로)
RESYNC_LOCK="/home/ubuntu/.fullnode-resync.lock"
if [ -f "$RESYNC_LOCK" ]; then
    LOCK_PID=$(cat "$RESYNC_LOCK" 2>/dev/null || echo "")
    if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
        exit 0
    fi
fi

RPC_URL="http://localhost:9000"
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
  sleep 5
  sudo systemctl restart nasun-fullnode
  echo "$CURRENT 0" > "$STATE_FILE"
  logger -t checkpoint-monitor "Restarted validator and fullnode due to stale checkpoint"
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

### 4.8 Fullnode 자동 재시작 (2026-02-08 추가, 2026-02-17 수정, Node 1 비활성화)

> **2026-02-21**: Node 1의 Fullnode가 Node 3으로 이전되어 이 cron은 Node 1에서 **비활성화**됨.
> Node 3에서 Fullnode 메모리 leak 대응이 필요한 경우 동일 패턴으로 설정 가능.

SUI Fullnode의 메모리 leak 대응을 위해 6시간마다 자동 재시작.

> **2026-02-17 수정**: Fullnode DB 재동기화(Section 4.9) 진행 중에는 재시작을 스킵하도록
> resync lock 파일 체크를 추가했습니다.

**스크립트**: `/home/ubuntu/fullnode-restart.sh` (Node 1)

```bash
#!/bin/bash
# Fullnode periodic restart to mitigate memory leak
# RPC downtime: ~60-90 seconds during restart

LOG_FILE=/home/ubuntu/fullnode-restart.log
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

# Check if resync is in progress - skip restart
RESYNC_LOCK="/home/ubuntu/.fullnode-resync.lock"
if [ -f "$RESYNC_LOCK" ]; then
    LOCK_PID=$(cat "$RESYNC_LOCK" 2>/dev/null || echo "")
    if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
        echo "[$TIMESTAMP] Skipping restart: fullnode resync in progress (PID: $LOCK_PID)" >> $LOG_FILE
        exit 0
    fi
fi

# Log memory before restart
MEM_BEFORE=$(free -m | awk '/Mem:/ {print $3}')
SWAP_BEFORE=$(free -m | awk '/Swap:/ {print $3}')
FULLNODE_RSS=$(ps -o rss= -p $(pgrep -f 'fullnode.yaml') 2>/dev/null | awk '{print int($1/1024)}')

echo "[$TIMESTAMP] Restarting fullnode. RAM: ${MEM_BEFORE}MB, Swap: ${SWAP_BEFORE}MB, Fullnode RSS: ${FULLNODE_RSS}MB" >> $LOG_FILE

sudo systemctl restart nasun-fullnode

sleep 15

# Log memory after restart
MEM_AFTER=$(free -m | awk '/Mem:/ {print $3}')
SWAP_AFTER=$(free -m | awk '/Swap:/ {print $3}')
STATUS=$(systemctl is-active nasun-fullnode)

echo "[$TIMESTAMP] Restart complete. RAM: ${MEM_AFTER}MB, Swap: ${SWAP_AFTER}MB, Status: $STATUS" >> $LOG_FILE
```

**Cron 설정** (6시간마다, 00/06/12/18 UTC):
```
0 0,6,12,18 * * * /home/ubuntu/fullnode-restart.sh
```

**로그 확인**:
```bash
cat ~/fullnode-restart.log
```

| 항목 | 값 |
|------|-----|
| 재시작 간격 | 6시간 (00:00, 06:00, 12:00, 18:00 UTC) |
| RPC 중단 | ~60-90초 |
| 합의 영향 | 없음 (Fullnode는 합의 미참여) |
| 메모리 해제 효과 | RSS 7-8GB → ~800MB |

### 4.9 Fullnode DB 재동기화 자동화 (2026-02-17 추가, Node 1 비활성화)

> **2026-02-21**: Node 1의 Fullnode가 Node 3으로 이전되어 이 cron은 Node 1에서 **비활성화**됨.
> Node 3에서 디스크 관리가 필요한 경우 동일 패턴으로 설정 가능 (300GB EBS이므로 당분간 불필요).

Fullnode DB가 ~3.2GB/일 증가하여 디스크 임계값을 초과하는 것을 방지하기 위한
자동 재동기화 시스템. Fullnode DB를 삭제하고 genesis부터 재구축하여 디스크를 회수합니다.

**스크립트**: `/home/ubuntu/fullnode-resync.sh` (Node 1)

**트리거 조건** (OR):

| 트리거 | 조건 | 스케줄 |
|--------|------|--------|
| 디스크 임계값 | 80% 이상 | 6시간마다 체크 (xx:30 UTC) |
| 정기 실행 | 무조건 | 매월 1일 21:00 UTC (KST 06:00) |

**Cron 설정**:
```
# 디스크 임계값 트리거 (6시간마다, restart와 30분 오프셋)
30 0,6,12,18 * * * /home/ubuntu/fullnode-resync-trigger.sh

# 정기 실행 (매월 1일 21:00 UTC)
0 21 1 * * /home/ubuntu/fullnode-resync.sh >> /home/ubuntu/fullnode-resync.log 2>&1
```

**실행 흐름**:
1. Lock 파일 획득 (PID 기반 중복 실행 방지)
2. 24시간 쿨다운 확인 (최근 resync로부터)
3. Pre-flight checks (Validator 실행 확인, 디스크 상태 기록)
4. Faucet 서비스 중지
5. Fullnode 서비스 중지
6. Fullnode DB 삭제 (`~/full_node_db/`)
7. Fullnode 서비스 시작 (genesis부터 재동기화)
8. 동기화 진행 모니터링 (5분 간격, 최대 6시간)
9. Faucet 서비스 재시작
10. 완료 보고 (SNS 알림)

**영향**:

| 항목 | 영향 |
|------|------|
| RPC | 3-6시간 중단 (재동기화 중) |
| Faucet | RPC 복구 후 자동 재시작 |
| Validator/합의 | 영향 없음 |
| 온체인 데이터 | 보존 (Validator DB 유지) |

**안전장치**:
- Lock 파일 (`~/.fullnode-resync.lock`): PID 기반 중복 실행 방지 (stale lock 자동 정리)
- 24시간 쿨다운: 무한 루프 방지 (`~/.last-resync-time`)
- Validator 실행 확인: 미실행 시 resync 거부
- fullnode-restart cron과 충돌 방지: lock 체크로 스킵 (Section 4.8)
- checkpoint-monitor와 충돌 방지: lock 체크로 스킵 (Section 4.7)
- SNS 알림: 시작/완료/실패/타임아웃 각 단계별 알림

**수동 실행**:
```bash
# 직접 실행 (포그라운드)
/home/ubuntu/fullnode-resync.sh

# 백그라운드 실행
nohup /home/ubuntu/fullnode-resync.sh >> /home/ubuntu/fullnode-resync.log 2>&1 &
```

**로그 확인**:
```bash
cat ~/fullnode-resync.log
tail -20 ~/fullnode-resync.log
```

**관련 파일**:

| 파일 | 역할 |
|------|------|
| `~/fullnode-resync.sh` | 메인 재동기화 스크립트 |
| `~/fullnode-resync-trigger.sh` | 디스크 임계값 체크 트리거 |
| `~/fullnode-resync.log` | 실행 이력 로그 (1MB 자체 로테이션) |
| `~/.fullnode-resync.lock` | 중복 실행 방지 Lock (PID 기반) |
| `~/.last-resync-time` | 마지막 resync 시각 (쿨다운용) |

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

### 5.11 V7 Fullnode 메모리 leak 및 스왑 소진 대응 (2026-02-07~09)

**증상**:
- Node 1 메모리 80%+ 사용, 스왑 2GB 완전 소진 (100%)
- Fullnode RSS가 시간당 ~600MB~2.2GB 증가 (재시작 후 약 6-14시간 만에 임계치 도달)
- OOM killer 발동 위험

**원인 분석**:
- SUI Fullnode의 RocksDB 캐시 및 인덱싱 메모리가 운영 시간에 비례하여 증가
- Node 1에서 Validator(2.9GB) + Fullnode(최대 9.9GB) + proverServer(620MB) 동시 운영
- 16GB RAM에서 합산 메모리가 13-14GB 도달 시 스왑 진입

**조치 (3단계)**:

| 단계 | 조치 | 효과 |
|------|------|------|
| 1 | **스왑 확장 2GB → 4GB** (2026-02-07) | OOM 위험 완화, 스왑 소진까지 시간 확보 |
| 2 | **Fullnode 수동 재시작** | RSS 9.9GB → 781MB 즉시 해제, RPC ~60-90초 중단 |
| 3 | **Fullnode 자동 재시작 cron 설정** (2026-02-08) | 6시간마다 자동 재시작으로 메모리 관리 자동화 |

**스왑 확장 절차** (무중단):
```bash
# 1. 새 4GB 스왑파일 생성 및 활성화 (기존 스왑 유지한 채)
sudo fallocate -l 4G /swapfile_new
sudo chmod 600 /swapfile_new
sudo mkswap /swapfile_new
sudo swapon /swapfile_new      # 총 6GB 스왑 (2+4)

# 2. 기존 스왑 비활성화 및 교체
sudo swapoff /swapfile           # 기존 2GB 내용이 RAM+새 스왑으로 이동
sudo rm /swapfile
sudo swapoff /swapfile_new
sudo mv /swapfile_new /swapfile
sudo swapon /swapfile            # 4GB 스왑 활성화

# 3. fstab 확인 (기존 /swapfile 항목 유지)
grep swap /etc/fstab
```

**자동 재시작 효과 (cron 로그)**:
```
[2026-02-08 12:00] Before: RAM 11722MB, Fullnode RSS 7745MB → After: RAM 4148MB ✓
[2026-02-08 18:00] Before: RAM 11469MB, Fullnode RSS 7816MB → After: RAM 3873MB ✓
[2026-02-09 00:00] Before: RAM 10911MB, Fullnode RSS 7254MB → After: RAM 3968MB ✓
```

6시간 간격으로 Fullnode RSS가 7-8GB에 도달한 시점에 재시작, 메모리를 ~4GB로 해제.
스왑 사용량도 2GB(100%) → 300-600MB(7-16%)로 안정화.

**현재 상태 (2026-02-09)**:
- Node 1 메모리: 4.8GB/15GB (32%), 스왑: 624MB/4GB (16%)
- 디스크: 39% (pruning 작동, 하루 ~1GB 증가로 안정화)
- cron 3회 연속 정상 실행 확인

**교훈**:
- Fullnode 메모리 leak은 SUI 노드의 알려진 특성 (RocksDB 캐시 증가)
- 16GB RAM에서 Validator+Fullnode 동시 운영 시 정기 재시작 필수
- 스왑 확장 시 기존 스왑을 유지한 채 새 파일을 먼저 활성화하면 무중단 교체 가능
- Fullnode 재시작은 합의에 영향 없음 (RPC만 ~90초 중단)

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

> **V7 3-node 마이그레이션 (2026-02-21)**: m6i 인스턴스로 전환 완료.
> 향후 리셋 시 m6g (Graviton) 전환으로 추가 비용 절감 가능.

**전환 이유**:
- Graviton (m7g)은 x86 (현재 m6i) 대비 성능/비용 우위
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

> **현재 상태**: V7 3-node m6i 아키텍처로 안정화됨. 월 ~$332 (on-demand).
> 1년 Compute Savings Plan 적용 시 ~$241/월로 절감 가능.

### 9.3 Faucet 설정

V7에서 NSN faucet 설정:

```bash
# /etc/systemd/system/nasun-faucet.service
ExecStart=/home/ubuntu/sui-faucet --host-ip 0.0.0.0 --port 5003 --amount 20000000000
# --amount 20 NSN × --num-coins 5 (기본값) = 100 NSN/요청
```

| 버전 | 설정 | 결과 |
|------|------|------|
| V7 (현재) | `--amount 20000000000` | 100 NSN (20×5) |

---

## 10. Indexer Infrastructure (Node 3)

### 10.1 개요

Node 3 (54.180.61.196, m6i.xlarge)에서 sui-indexer + PostgreSQL 16 + Explorer API를 운영합니다.
이 인프라는 Network Explorer뿐 아니라 **모든 Nasun 프로젝트의 공유 데이터 소스**입니다.

> **2026-02-21**: Node 2에서 Node 3으로 이전. Fullnode과 같은 노드에서 운영하여
> `data-ingestion-dir` 로컬 파일 모드 사용 (기존 remote REST mode 대비 안정적).

### 10.2 서비스 구성

| 서비스 | 관리 방식 | OOM Score | 설명 |
|--------|----------|-----------|------|
| `nasun-fullnode` | systemd | -500 (보호) | Fullnode RPC + data-ingestion 파일 생성 |
| `postgresql` | systemd | - | PostgreSQL 16, DB: `sui_indexer` |
| `sui-indexer` | systemd | 500 (우선 kill) | data-ingestion 로컬 파일 → PostgreSQL |
| `explorer-api` | PM2 | - | Hono REST API, port 3200 |

### 10.3 sui-indexer

```bash
# Node 3에서 실행
ssh ubuntu@54.180.61.196

# 상태 확인
sudo systemctl status sui-indexer

# 로그 확인
sudo journalctl -u sui-indexer -f --no-pager

# 재시작
sudo systemctl restart sui-indexer
```

- **ingestion 모드**: local file (`--data-ingestion-path /home/ubuntu/nasun-node/data-ingestion`)
- **Metrics**: port 9185 (Fullnode이 9184 사용)
- **Config**: `/etc/systemd/system/sui-indexer.service`
- **CPU 제한**: `CPUQuota=50%`, **메모리 제한**: `MemoryMax=800M`
- **data-ingestion 자동 정리**: `--gc-checkpoint-files` (기본 true, 처리 완료 파일 자동 삭제)

### 10.4 PostgreSQL

```bash
# Node 3에서 실행
ssh ubuntu@54.180.61.196

# DB 크기 확인
sudo -u postgres psql -d sui_indexer -c "SELECT pg_size_pretty(pg_database_size('sui_indexer'));"

# 주요 테이블 행 수 확인
sudo -u postgres psql -d sui_indexer -c "SELECT relname, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC LIMIT 10;"

# 최신 인덱싱된 체크포인트
PGPASSWORD=indexer_ec2_2026 psql -U sui_indexer -d sui_indexer -c "SELECT MAX(sequence_number) FROM checkpoints;"
```

- **설정**: `shared_buffers=4GB`, `effective_cache_size=12GB`, `work_mem=64MB`, `max_connections=20`

### 10.5 Explorer API (PM2)

```bash
# Node 3에서 실행
ssh ubuntu@54.180.61.196

# 상태 확인
pm2 status explorer-api

# 재시작 (환경변수 로드 필수)
set -a && source ~/explorer-api/.env && set +a
pm2 restart explorer-api --update-env

# 헬스체크
curl http://localhost:3200/api/v1/health
```

- **코드**: `~/explorer-api/` (rsync from `nasun-monorepo/apps/network-explorer/api-server/`)
- **Security Group**: Port 3200 → Production EC2 (43.200.67.52/32) 전용

### 10.6 Devnet 리셋 시 인덱서 재초기화

```bash
# Node 3에서 실행
ssh ubuntu@54.180.61.196

# 1. 인덱서 중지
sudo systemctl stop sui-indexer

# 2. DB 초기화
sudo -u postgres psql -c "DROP DATABASE sui_indexer;"
sudo -u postgres psql -c "CREATE DATABASE sui_indexer OWNER sui_indexer;"

# 3. 인덱서 재시작
sudo systemctl start sui-indexer

# 4. API 서버 재시작
set -a && source ~/explorer-api/.env && set +a
pm2 restart explorer-api --update-env

# 5. 헬스체크
curl http://localhost:3200/api/v1/health
```

### 10.7 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| API `/health` 503 | PostgreSQL 다운 또는 인덱서 미동작 | `systemctl status postgresql sui-indexer` 확인 |
| 인덱싱 진행 안 됨 | data-ingestion 파일 미생성 | Fullnode `checkpoint-executor-config.data-ingestion-dir` 확인 |
| data-ingestion 파일 쌓임 | indexer가 중단됨 | `systemctl restart sui-indexer`, 파일 수 확인 |
| PM2 explorer-api 실패 | DATABASE_URL 미설정 | `set -a && source .env && set +a` 후 재시작 |
| metrics port 충돌 | Fullnode (9184) vs indexer | indexer는 9185 사용 확인 |

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
| 5.2.0 | 2026-02-09 | **V7 운영 안정화 조치 문서화**: Fullnode 메모리 leak 대응 (스왑 4GB 확장, 6시간 자동 재시작 cron), DB pruning 작동 확인 (epoch 50+), 문제 해결 사례 5.11 추가, 모니터링 4.8 추가, Faucet 설정 수정 | Claude Code |
| 5.3.0 | 2026-02-17 | **Fullnode DB 재동기화 자동화**: EBS 200GB 확장 (양 노드), fullnode-resync.sh (PID lock, 24h 쿨다운, SNS 알림), resync-trigger.sh (80% 임계값), checkpoint-monitor/fullnode-restart에 lock 연동, Section 4.9 추가 | Claude Code |
| 6.0.0 | 2026-02-20 | **Indexer Infrastructure (Node 2)**: sui-indexer + PostgreSQL 16 + Explorer API (Hono/PM2) 구축. Node 2 역할 업데이트, Section 10 추가, 서비스 배치 테이블 업데이트 | Claude Code |
| 7.0.0 | 2026-02-21 | **3-Node m6i 마이그레이션**: t3→m6i 전환, 역할 분리 (Node 1: Validator+Faucet, Node 2: Validator+Prover, Node 3: Fullnode+Indexer+Explorer). DNS 전환 (rpc→node-3), zkprover node-2 이전, Indexer Section 10 Node 3으로 업데이트 | Claude Code |
