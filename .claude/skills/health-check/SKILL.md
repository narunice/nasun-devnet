---
name: health-check
description: |
  Nasun Devnet 3-node 인프라의 헬스를 총체적으로 체크합니다.
  외부 엔드포인트 검증, SSH를 통한 노드별 상세 점검, 합의 분석, 실제 장애 경험 기반 failure pattern detection을 수행합니다.
  "헬스체크 해줘", "데브넷 상태 확인", "노드 상태", "health check" 등의 요청에 사용합니다.
  인자로 quick, full, 1, 2, 3, rpc를 지원합니다.
---

# Health Check: Nasun Devnet 인프라 점검

Nasun Devnet 3-node 인프라의 헬스를 체크합니다.
외부 엔드포인트부터 내부 서비스, 합의 상태, 잠재적 장애 패턴까지 총체적으로 점검합니다.

## 인프라 구성 참조

| Node | IP | 역할 | 인스턴스 |
|------|-----|------|---------|
| node-1 | 3.38.127.23 | Validator + Faucet + Nginx | m6i.large (8GB) |
| node-2 | 3.38.76.85 | Validator + zkLogin Prover (Docker) | m6i.large (8GB) |
| node-3 | 54.180.61.196 | Fullnode (RPC) + sui-indexer + PostgreSQL + Explorer API + Nginx | m6i.2xlarge (32GB) |

## SSH 접속 공통

모든 SSH 명령에 다음 옵션을 사용합니다:

```
KEY=~/.ssh/.awskey/nasun-devnet-key.pem
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no"
NODE1=ubuntu@3.38.127.23
NODE2=ubuntu@3.38.76.85
NODE3=ubuntu@54.180.61.196
```

## $ARGUMENTS 처리

| 인자 | 동작 |
|------|------|
| (없음) 또는 `full` | 전체 5단계 실행 |
| `quick` | 1단계(외부 엔드포인트) + 3단계(합의) 요약만 |
| `rpc` | RPC 엔드포인트만 체크 (curl만, SSH 없음) |
| `1` | Node 1만 SSH 점검 (1단계 + 2단계 node-1만) |
| `2` | Node 2만 SSH 점검 (1단계 + 2단계 node-2만) |
| `3` | Node 3만 SSH 점검 (1단계 + 2단계 node-3만) |

`$ARGUMENTS`를 파싱하여 해당하는 단계만 실행합니다. 인자가 없으면 전체 실행.

---

## 실행 절차

### 1단계: 외부 엔드포인트 검증

아래 3개 요청을 **병렬로** 실행합니다:

**RPC 체크 (HTTPS)**:
```bash
curl -s -m 10 -X POST https://rpc.devnet.nasun.io \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getChainIdentifier","params":[]}'
```
- 기대값: `{"result":"272218f1"}`
- Chain ID가 `272218f1`이 아니면 CRITICAL

```bash
curl -s -m 10 -X POST https://rpc.devnet.nasun.io \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getLatestCheckpointSequenceNumber","params":[]}'
```
- 체크포인트 번호를 기록 (3단계에서 사용)

**Faucet 체크 (HTTPS)**:
```bash
curl -s -m 10 -o /dev/null -w "%{http_code}" https://faucet.devnet.nasun.io
```
- HTTP 200 또는 405 (Method Not Allowed) 이면 정상
- 타임아웃 또는 5xx이면 CRITICAL

**Explorer API 체크 (SSH 경유)**:
```bash
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@54.180.61.196 "curl -s -m 5 http://localhost:3200/api/v1/health"
```
- Port 3200은 Security Group에서 Production EC2 (43.200.67.52/32)에만 개방되어 있으므로 외부 직접 접근 불가
- SSH로 Node 3에 접속하여 localhost에서 체크해야 함
- 응답이 있으면 정상, 타임아웃이면 WARNING

`$ARGUMENTS`가 `rpc`이면 여기서 결과를 요약하고 종료합니다.
`$ARGUMENTS`가 `quick`이면 1단계 결과를 기록하고 3단계로 건너뜁니다.

---

### 2단계: 노드별 SSH 점검

3개 노드를 **병렬로** (Task 에이전트 3개) 점검합니다.
`$ARGUMENTS`가 `1`, `2`, `3`이면 해당 노드만 점검합니다.

#### Node 1 (3.38.127.23) — Validator + Faucet

SSH로 아래 명령을 **하나의 SSH 세션**에서 실행합니다:

```bash
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@3.38.127.23 bash -s << 'HEALTH_EOF'
echo "=== SERVICES ==="
systemctl is-active nasun-validator nasun-faucet nginx 2>/dev/null | paste - - -

echo "=== DISK ==="
df -h / | tail -1

echo "=== MEMORY ==="
free -m | grep -E "Mem|Swap"

echo "=== VALIDATOR ERRORS (last 10min) ==="
sudo journalctl -u nasun-validator --since "10 minutes ago" --no-pager -p err 2>/dev/null | tail -20

echo "=== FAUCET ERRORS (last 10min) ==="
sudo journalctl -u nasun-faucet --since "10 minutes ago" --no-pager -p err 2>/dev/null | tail -10

echo "=== UPTIME ==="
uptime
HEALTH_EOF
```

점검 항목:
- `nasun-validator`: active 필수 (inactive = CRITICAL, 합의 중단)
- `nasun-faucet`: active 필수 (inactive = WARNING)
- `nginx`: active 필수 (inactive = WARNING, Faucet HTTPS 불가)
- 디스크 사용률: Threshold 표 참조
- Swap 사용률: Threshold 표 참조

#### Node 2 (3.38.76.85) — Validator + zkLogin Prover

```bash
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@3.38.76.85 bash -s << 'HEALTH_EOF'
echo "=== SERVICES ==="
systemctl is-active nasun-validator 2>/dev/null

echo "=== DOCKER (zkLogin Prover) ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "docker not accessible"

echo "=== DISK ==="
df -h / | tail -1

echo "=== MEMORY ==="
free -m | grep -E "Mem|Swap"

echo "=== VALIDATOR ERRORS (last 10min) ==="
sudo journalctl -u nasun-validator --since "10 minutes ago" --no-pager -p err 2>/dev/null | tail -20

echo "=== UPTIME ==="
uptime
HEALTH_EOF
```

점검 항목:
- `nasun-validator`: active 필수 (inactive = CRITICAL, 합의 중단)
- Docker zkLogin prover: 컨테이너 running 확인 (down = WARNING)
- 디스크/Swap: Threshold 표 참조

#### Node 3 (54.180.61.196) — Fullnode + Indexer + Explorer

Node 3는 가장 복잡하며, 대부분의 장애가 여기서 발생합니다.

```bash
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@54.180.61.196 bash -s << 'HEALTH_EOF'
echo "=== SERVICES ==="
systemctl is-active nasun-fullnode sui-indexer postgresql nginx 2>/dev/null | paste - - - -

echo "=== PM2 ==="
pm2 jlist 2>/dev/null | python3 -c "
import sys, json
try:
    apps = json.load(sys.stdin)
    for a in apps:
        print(f\"{a['name']}: {a['pm2_env']['status']} (restarts: {a['pm2_env']['restart_time']}, uptime: {(a['pm2_env'].get('pm_uptime',0))})\" )
except: print('PM2 parse error')
" 2>/dev/null || echo "pm2 not available"

echo "=== FULLNODE RSS ==="
ps aux | grep '[s]ui-node' | awk '{printf "%.0f MB\n", $6/1024}'

echo "=== INDEXER RSS ==="
ps aux | grep '[s]ui-indexer' | awk '{printf "%.0f MB\n", $6/1024}'

echo "=== DISK ==="
df -h / | tail -1

echo "=== MEMORY ==="
free -m | grep -E "Mem|Swap"

echo "=== CHK FILES ==="
find /home/ubuntu/nasun-node/data-ingestion -name "*.chk" 2>/dev/null | wc -l

echo "=== DB SIZE ==="
PGPASSWORD=indexer_ec2_2026 psql -U sui_indexer -d sui_indexer -h localhost -t -c "SELECT pg_size_pretty(pg_database_size('sui_indexer'));" 2>/dev/null || echo "DB connection failed"

echo "=== INDEXER CHECKPOINT ==="
PGPASSWORD=indexer_ec2_2026 psql -U sui_indexer -d sui_indexer -h localhost -t -c "SELECT MAX(sequence_number) FROM checkpoints;" 2>/dev/null || echo "query failed"

echo "=== FULLNODE CHECKPOINT ==="
curl -s -m 5 http://localhost:9000 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"sui_getLatestCheckpointSequenceNumber","params":[]}' 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['result'])" 2>/dev/null || echo "RPC failed"

echo "=== CGROUP MEMORY EVENTS (Fullnode) ==="
sudo cat /sys/fs/cgroup/system.slice/nasun-fullnode.service/memory.events 2>/dev/null | grep -E "high|max|oom" || echo "no cgroup data"

echo "=== CGROUP MEMORY EVENTS (Indexer) ==="
sudo cat /sys/fs/cgroup/system.slice/sui-indexer.service/memory.events 2>/dev/null | grep -E "high|max|oom" || echo "no cgroup data"

echo "=== FULLNODE ERRORS (last 10min) ==="
sudo journalctl -u nasun-fullnode --since "10 minutes ago" --no-pager -p err 2>/dev/null | tail -10

echo "=== INDEXER ERRORS (last 10min) ==="
sudo journalctl -u sui-indexer --since "10 minutes ago" --no-pager -p err 2>/dev/null | tail -10

echo "=== INDEXER SERVICE STATUS ==="
systemctl show sui-indexer --property=NRestarts,ActiveState,SubState,Result 2>/dev/null

echo "=== DEFENSE SYSTEM STATUS ==="
echo "-- Watchdog state --"
cat /home/ubuntu/.indexer-watchdog-state 2>/dev/null || echo "clean (no state)"
echo "-- Maintenance lock --"
ls -la /home/ubuntu/.indexer-maintenance.lock 2>/dev/null || echo "no lock"
echo "-- Indexer panics (last 1h) --"
sudo journalctl -u sui-indexer --since "1 hour ago" --no-pager 2>/dev/null | grep -c "panicked" || echo "0"
echo "-- vm.swappiness --"
cat /proc/sys/vm/swappiness

echo "=== UPTIME ==="
uptime
HEALTH_EOF
```

점검 항목 (Threshold 표에 따라 평가):
- `nasun-fullnode`: active 필수 (inactive = CRITICAL)
- `sui-indexer`: active 필수 (inactive = WARNING — 합의에는 영향 없음)
- `postgresql`: active 필수 (inactive = CRITICAL — indexer + API 모두 중단)
- PM2 앱: `explorer-api` (online 필수), `baram-aer-api` (online 권장)
- Fullnode RSS: F1 패턴 감지
- Indexer RSS: F2 패턴 감지
- .chk 파일 수: F3 패턴 감지
- Indexer checkpoint vs Fullnode checkpoint: F4 패턴 (lag 계산)
- Swap 사용률: F5 패턴 감지
- 디스크 사용률: F6 패턴 감지
- cgroup memory.events의 `high` count: throttle 빈도 확인
- DB 크기: 성장 추세 파악 (매일 ~8.7GB 증가)

---

### 3단계: 합의 분석

2단계 결과를 바탕으로 합의 상태를 판단합니다:

**합의 판단 로직**:
- Node 1 validator active + Node 2 validator active → 합의 정상
- 어느 하나라도 inactive → **CRITICAL: 합의 중단** (2-validator, f=0)
- 1단계 체크포인트 번호와 이전 체크 (또는 10초 후 재확인)를 비교하여 진행 중인지 확인
- 체크포인트가 진행하지 않으면 → **CRITICAL: 합의 stale**

---

### 4단계: Failure Pattern Detection

실제 장애 경험에서 도출한 8개 패턴을 2단계 데이터에서 감지합니다:

| ID | 패턴 | 감지 조건 | 심각도 | 권장 조치 |
|----|------|-----------|--------|-----------|
| F1 | Fullnode memory leak | RSS > 12GB (WARNING), > 16GB (CRITICAL) | W/C | Fullnode 재시작 (`sudo systemctl restart nasun-fullnode`). 8시간 cron이 자동 관리하지만, 16GB 초과 시 즉시 개입 필요. node-3는 m6i.2xlarge (32GB)이므로 여유 있음 |
| F2 | Indexer OOM 위험 | RSS > 2GB (WARNING), > 3GB (CRITICAL) 또는 cgroup high event 급증 | W/C | Indexer 재시작. MemoryHigh=3G, MemoryMax=4G에서 OOM kill 발생하면 watchdog가 자동 복구 |
| F3 | .chk 파일 누적 | > 10K (WARNING), > 50K (CRITICAL) | W/C | Indexer가 정상이면 자동 GC 대기. 50K+ 이면 `chk-cleanup.sh` 수동 실행 또는 indexer 상태 확인 |
| F4 | Indexer lag | > 500 (WARNING, growing), > 5000 (CRITICAL) | W/C | Indexer 로그 확인. DB 문제 또는 OOM 반복일 가능성. 심하면 DB reinit 필요 |
| F5 | Swap thrashing | swap used > 70% (WARNING), > 90% (CRITICAL) | W/C | Fullnode RSS 확인 후 재시작. Swap 90%+ 에서는 시스템 전체 성능 저하 |
| F6 | 디스크 부족 | > 80% (WARNING), > 90% (CRITICAL) | W/C | `du -sh` 로 큰 디렉토리 확인. 로그 정리, DB reinit, .chk 정리 고려 |
| F7 | 합의 중단 | Validator 1개 이상 inactive | C | 즉시 해당 validator 재시작. 두 노드 모두 동일 genesis 확인 |
| F8 | 서비스 restart 폭주 | NRestarts 높거나 Result=start-limit-hit | C | `systemctl reset-failed` 후 원인 분석. 보통 DB 연결 실패 또는 config 오류 |
| F9 | Indexer crash-loop | panics 3+ in 1h (same epoch error) | C | Watchdog v2가 자동 DB reinit 실행. 미실행 시 watchdog 로그 확인 |

---

### 5단계: 결과 요약

모든 데이터를 수집한 뒤 아래 형식으로 출력합니다:

**요약 테이블**:

```
## Nasun Devnet Health Report

| 항목 | 상태 | 비고 |
|------|------|------|
| RPC (HTTPS) | OK/FAIL | Chain ID, checkpoint |
| Faucet (HTTPS) | OK/FAIL | HTTP status |
| Explorer API | OK/FAIL | |
| Node 1 Validator | OK/FAIL | |
| Node 1 Faucet | OK/FAIL | |
| Node 2 Validator | OK/FAIL | |
| Node 2 zkLogin Prover | OK/FAIL | |
| Node 3 Fullnode | OK/FAIL | RSS: XGB |
| Node 3 Indexer | OK/FAIL | lag: N, .chk: N |
| Node 3 PostgreSQL | OK/FAIL | DB size: XGB |
| Node 3 Explorer API | OK/FAIL | |
| Node 3 Baram API | OK/FAIL | |
| Consensus | OK/STALE | checkpoint: N |
| Disk (node-1) | OK/WARN | XX% |
| Disk (node-2) | OK/WARN | XX% |
| Disk (node-3) | OK/WARN | XX% |
| Swap (node-3) | OK/WARN | XX% |
```

**Failure Pattern 발견 시**:

각 감지된 패턴에 대해:
```
### [SEVERITY] F{N}: {패턴명}
- 현재 값: {측정값}
- Threshold: {WARNING/CRITICAL 기준}
- 권장 조치: {구체적 명령어 포함}
```

**모든 정상 시**:
```
All systems operational. No issues detected.
```

---

## Threshold 표

| 메트릭 | 정상 | WARNING | CRITICAL |
|--------|------|---------|----------|
| Fullnode RSS | < 8GB | 12GB+ | 16GB+ |
| Indexer RSS | < 1GB | 2GB+ | 3GB+ |
| Indexer lag | < 100 | 500+ | 5000+ |
| .chk files | < 5K | 10K+ | 50K+ |
| Disk usage | < 70% | 80%+ | 90%+ |
| Swap usage | < 50% | 70%+ | 90%+ |
| DB size | < 15GB | 20GB+ | 25GB+ |

---

## 주의사항

- **Read-only**: 헬스 체크 중 절대 서비스 재시작, 설정 변경, 파일 수정 금지
- **SSH 타임아웃**: 10초 (`-o ConnectTimeout=10`). 노드 unreachable 시 hang 방지
- **민감 정보**: DB 비밀번호, 프라이빗 키 등 출력 금지 (SSH 명령 내에서만 사용)
- **로그 제한**: journalctl은 최근 10분, 최대 20줄로 제한 (과도한 출력 방지)
- **문제 발견 시**: 권장 조치를 제안하되, 실행은 사용자 승인 후에만 수행
- **PostgreSQL 비밀번호**: SSH 명령 내에서 PGPASSWORD 환경변수로 사용하되 출력에 노출하지 않음
