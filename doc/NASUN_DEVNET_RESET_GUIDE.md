# Nasun Devnet Network Reset Guide

**Version**: 5.1
**Last Updated**: 2026-02-04
**Current Network**: V7 (Chain ID: `272218f1`)

---

## Overview

This guide documents the network reset procedure for Nasun Devnet. A reset is required when:
- Upgrading to a new Sui mainnet release (for zkLogin compatibility)
- Changing epoch duration or other genesis parameters
- Fixing DB schema incompatibility issues

---

## Current Network Status (V7)

| Item | Value |
|------|-------|
| **Chain ID** | `272218f1` |
| **Fork Source** | Sui mainnet v1.63.3 |
| **Native Token** | NSN (min unit: SOE) |
| **Epoch Duration** | 2 hours (7,200,000ms) |
| **DB Pruning** | 50 epochs (~4 days) |
| **zkLogin** | Supported (prover-dev compatible) |

### Node Architecture (2-Node)

| Node | IP | Role | Instance |
|------|-----|------|----------|
| Node 1 | 3.38.127.23 | Validator + Fullnode + Faucet + nginx | t3.xlarge (16GB) |
| Node 2 | 3.38.76.85 | Validator | t3.large (8GB) |

> **Note**: V7 upgraded Node 1 to t3.xlarge (16GB) for memory headroom

---

## Pre-Reset Checklist

### 1. Current Contract Inventory

Record all deployed contracts before reset (V7: 15 packages):

| Tier | Contract | Directory |
|------|----------|-----------|
| 1 | Devnet Tokens | `packages/devnet-tokens` |
| 1 | DeepBook Token | `apps/pado/deepbookv3/packages/token` |
| 1 | DeepBook V3 | `apps/pado/deepbookv3/packages/deepbook` |
| 1 | Governance | `apps/nasun-website/contracts/governance` |
| 1 | NSA | `apps/pado/contracts-nsa` |
| 1 | Baram Executor | `apps/baram/contracts-executor` |
| 1 | Baram Attestation | `apps/baram/contracts-attestation` |
| 1 | Baram Compliance | `apps/baram/contracts-compliance` |
| 2 | Prediction Market | `apps/pado/contracts-prediction` |
| 2 | Lottery | `apps/pado/contracts-lottery` |
| 2 | Oracle | `apps/pado/contracts-oracle` |
| 2 | Lending | `apps/pado/contracts-lending` |
| 2 | Baram | `apps/baram/contracts` |
| 3 | Margin | `apps/pado/contracts-margin` |
| 3 | Perp | `apps/pado/contracts-perp` |

### 2. Files to Update After Reset (Centralized ID Management)

**V6부터 `@nasun/devnet-config` 패키지를 통한 중앙화된 ID 관리를 사용합니다.**

대부분의 앱이 이미 이 패키지를 사용하도록 마이그레이션되었으므로,
리셋 후에는 다음 파일들만 업데이트하면 됩니다:

```
# 1. 중앙 소스 (핵심 - 반드시 업데이트)
packages/devnet-config/devnet-ids.json

# 2. Move.toml 파일 (15개 - published-at + environments chain ID 업데이트)
packages/devnet-tokens/Move.toml
apps/pado/deepbookv3/packages/token/Move.toml
apps/pado/deepbookv3/packages/deepbook/Move.toml
apps/pado/contracts-prediction/Move.toml
apps/pado/contracts-lottery/Move.toml
apps/pado/contracts-oracle/Move.toml
apps/pado/contracts-lending/Move.toml
apps/pado/contracts-margin/Move.toml
apps/pado/contracts-perp/Move.toml
apps/pado/contracts-nsa/Move.toml
apps/baram/contracts/Move.toml
apps/baram/contracts-executor/Move.toml
apps/baram/contracts-attestation/Move.toml
apps/baram/contracts-compliance/Move.toml
apps/nasun-website/contracts/governance/Move.toml

# 3. 문서
nasun-devnet/CLAUDE.md
```

**자동으로 동기화되는 파일들** (pnpm devnet:sync 실행 시):
```
apps/pado/.env.development
apps/pado/.env.staging
apps/baram/.env
apps/baram/frontend/.env
apps/nasun-website/frontend/.env.development
```

**이미 마이그레이션된 TypeScript 파일들** (수동 업데이트 불필요):
```
packages/wallet/src/config/tokens.ts          → @nasun/devnet-config 사용
packages/wallet/src/sui/tokenFaucet.ts        → @nasun/devnet-config 사용
apps/pado/frontend/src/features/prediction/constants.ts  → @nasun/devnet-config 사용
apps/pado/frontend/src/features/lottery/constants.ts     → @nasun/devnet-config 사용
apps/baram/frontend/src/config/network.ts               → @nasun/devnet-config 사용
apps/nasun-website/frontend/src/constants/suiPackageConstants.ts → @nasun/devnet-config 사용
```

---

## Phase 1: Build New Binary

> **zkLogin Compatibility**: Always use a **mainnet release tag** to ensure zkLogin works.
> The verifying key is embedded in the binary and must match prover-dev's proving key.

```bash
cd /home/naru/my_apps/nasun-devnet/sui

# Fetch latest stable tags
git fetch upstream --tags
git tag -l 'mainnet-v*' | sort -V | tail -5

# Create branch from latest stable release
git checkout -b nasun-v<VERSION>-mainnet-<VERSION> mainnet-v<VERSION>

# Build (20-40 min, or 3-4 min with ccache)
cargo build --release

# Verify build
./target/release/sui --version
./target/release/sui-node --version
```

---

## Phase 2: Stop Services on All Nodes

```bash
# Node 1 (3.38.127.23) - Validator + Fullnode + Faucet
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.127.23
sudo systemctl stop nasun-faucet nasun-fullnode nasun-validator

# Node 2 (3.38.76.85) - Validator
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.76.85
sudo systemctl stop nasun-validator
```

---

## Phase 3: Deploy New Binary

```bash
# From local machine - deploy sui-node to both nodes
scp -i ~/.ssh/.awskey/nasun-devnet-key.pem \
  target/release/sui-node ubuntu@3.38.127.23:~/
scp -i ~/.ssh/.awskey/nasun-devnet-key.pem \
  target/release/sui-node ubuntu@3.38.76.85:~/

# Deploy sui and sui-faucet to Node 1 (Fullnode + Faucet)
scp -i ~/.ssh/.awskey/nasun-devnet-key.pem \
  target/release/sui target/release/sui-faucet \
  ubuntu@3.38.127.23:~/
```

---

## Phase 4: Clear Old Data (All Nodes)

```bash
# On Node 1 (Validator + Fullnode + Faucet)
rm -rf ~/authorities_db ~/consensus_db ~/full_node_db ~/.sui ~/.nasun

# On Node 2 (Validator)
rm -rf ~/authorities_db ~/consensus_db ~/.sui ~/.nasun
```

---

## Phase 5: Generate New Genesis (Node 1 Only)

```bash
# On Node 1 (3.38.127.23)
# Use 2-hour epoch for stable operations (recommended)
./sui genesis --force --epoch-duration-ms 7200000 --committee-size 2 \
  --benchmark-ips 3.38.127.23 3.38.76.85 --with-faucet

# Fix Fullnode config (bind to 0.0.0.0 for external access)
# Note: This config will be deployed to Node 3 in Phase 7
sed -i 's|network-address: /ip4/127.0.0.1|network-address: /ip4/0.0.0.0|g' ~/.sui/sui_config/fullnode.yaml
sed -i 's|listen-address: "127.0.0.1|listen-address: "0.0.0.0|g' ~/.sui/sui_config/fullnode.yaml

# Fix Validator config (EC2 NAT requires 0.0.0.0)
sed -i 's|network-address: /ip4/3.38.127.23|network-address: /ip4/0.0.0.0|' ~/.sui/sui_config/3.38.127.23-*.yaml

# Create symlink for backward compatibility
mkdir -p ~/.nasun && ln -s ~/.sui/sui_config ~/.nasun/nasun_config

# Verify new chain ID
grep -A2 "chain_id" ~/.sui/sui_config/fullnode.yaml
```

---

## Phase 6: Configure DB Pruning

Add pruning settings to both validator and fullnode configs:

```yaml
# In fullnode.yaml and validator.yaml
authority-store-pruning-config:
  num-epochs-to-retain: 50  # ~4 days with 2-hour epochs
```

---

## Phase 7: Distribute Genesis to Node 2

```bash
# On Node 1: Copy genesis and validator config to Node 2
scp ~/.sui/sui_config/genesis.blob ubuntu@3.38.76.85:~/.sui/sui_config/
scp ~/.sui/sui_config/3.38.76.85-*.yaml ubuntu@3.38.76.85:~/validator.yaml

# On Node 2: Setup and fix config
ssh ubuntu@3.38.76.85
mkdir -p ~/.sui/sui_config ~/.nasun
ln -s ~/.sui/sui_config ~/.nasun/nasun_config
cp ~/validator.yaml ~/.sui/sui_config/
sed -i 's|network-address: /ip4/3.38.76.85|network-address: /ip4/0.0.0.0|' ~/validator.yaml
```

> **참고**: 2-Node 아키텍처에서 Fullnode와 Faucet은 Node 1에서 실행됩니다.
> Genesis 생성 시 Node 1에 fullnode.yaml이 이미 생성되므로 별도 복사가 필요 없습니다.

---

## Phase 8: Verify Log Management Settings

```bash
# On both nodes - verify RUST_LOG setting
grep RUST_LOG /etc/systemd/system/nasun-*.service
# All should show: Environment="RUST_LOG=warn"

# Verify logrotate
cat /etc/logrotate.d/rsyslog | grep maxsize
# Should show: 100M

# Verify journald
cat /etc/systemd/journald.conf | grep SystemMaxUse
# Should show: 500M
```

---

## Phase 9: Start Services

```bash
# 1. Node 2 first (validator only)
ssh ubuntu@3.38.76.85
sudo systemctl start nasun-validator
sudo systemctl status nasun-validator

# 2. Node 1 (validator + fullnode + faucet)
ssh ubuntu@3.38.127.23
sudo systemctl start nasun-validator
sudo systemctl status nasun-validator

# 3. Wait for consensus to stabilize
sleep 30

# 4. Start Fullnode and Faucet on Node 1
sudo systemctl start nasun-fullnode
sleep 10
sudo systemctl start nasun-faucet
sudo systemctl status nasun-fullnode nasun-faucet
```

---

## Phase 10: Verify Network

```bash
# Check Chain ID (via Node 1 Fullnode)
curl -X POST http://3.38.127.23:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getChainIdentifier","params":[]}'

# Check checkpoint progress
curl -X POST http://3.38.127.23:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getLatestCheckpointSequenceNumber","params":[]}'

# Test faucet (Node 1)
curl -X POST http://3.38.127.23:5003/gas \
  -H "Content-Type: application/json" \
  -d '{"FixedAmountRequest":{"recipient":"<YOUR_ADDRESS>"}}'

# Also verify via HTTPS endpoints
curl -X POST https://rpc.devnet.nasun.io \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getChainIdentifier","params":[]}'
```

---

## Smart Contract Redeployment

> **V7에서 확립된 방법론**: 15개 컨트랙트를 3-tier로 나누어 의존성 순서대로 배포합니다.
> 자세한 단계별 가이드는 [POST_RESET_CHECKLIST.md](./NASUN_DEVNET_POST_RESET_CHECKLIST.md) Section 2를 참조하세요.

### Deployment Command Pattern

```bash
# Tier 1 (독립 패키지): test-publish만 사용
cd <contract_dir>
rm -f Move.lock Pub.devnet.toml
sui client test-publish --build-env devnet --gas-budget 500000000

# Tier 2/3 (의존 패키지): 공유 Pub.devnet.toml 참조
cd <contract_dir>
rm -f Move.lock Pub.devnet.toml
sui client test-publish --build-env devnet \
  --pubfile-path /home/naru/my_apps/nasun-monorepo/Pub.devnet.toml \
  --gas-budget 500000000
```

> **주의**: `--with-unpublished-dependencies`를 이미 배포된 의존성에 사용하지 마세요.
> 의존성을 번들링하여 별도의 타입을 생성하므로 타입 호환성이 깨집니다.
> 반드시 `--pubfile-path`로 공유 `Pub.devnet.toml`을 지정하세요.

### 3-Tier Deployment Order (15 contracts)

| Tier | Contracts | Dependencies |
|------|-----------|-------------|
| **Tier 1** | devnet_tokens, deepbook_token, deepbook, governance, nsa, baram_executor, baram_attestation, baram_compliance | None |
| **Tier 2** | prediction, lottery, oracle, lending, baram | devnet_tokens |
| **Tier 3** | margin, perp | devnet_tokens + others |

### Post-deploy Shared Object Creation

Some contracts don't create all shared objects in `init()`. These must be created separately:

| Object | Method |
|--------|--------|
| ProposalTypeRegistry | `governance::proposal::init_type_registry` |
| TierRegistry | `baram_executor::executor_tier::create_tier_registry` |
| CertificateRegistry | PTB: `create_registry` + `share_registry` |
| VotingPowerOracle | PTB: `create_oracle` + `share_oracle` (Ed25519 key required) |
| NBTC/NUSDC Pool | `deepbook::pool::create_pool_admin` |
| NSN/NUSDC Pool | `deepbook::pool::create_pool_admin` |
| BTC PerpMarket | `pado_perp::perpetual::create_market` |

### Shared Pub.devnet.toml

`test-publish` automatically adds entries to `Pub.devnet.toml` on successful deployment.
When using `--pubfile-path` pointing to a shared file at the monorepo root, subsequent
deployments can automatically resolve addresses of previously deployed packages.

```bash
# Monorepo root의 공유 Pub 파일
/home/naru/my_apps/nasun-monorepo/Pub.devnet.toml

# 리셋 시 이전 Pub 파일 삭제
rm -f /home/naru/my_apps/nasun-monorepo/Pub.devnet.toml
```

### TEE Executor Registration (Optional)

After deploying executor-nitro on EC2 Nitro Enclave:

```bash
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

## Frontend ID Update (Centralized)

스마트 컨트랙트 배포 후, 중앙화된 ID 관리 시스템을 통해 모든 앱의 ID를 업데이트합니다.

### Step 1: Update devnet-ids.json

```bash
cd /home/naru/my_apps/nasun-monorepo
vi packages/devnet-config/devnet-ids.json
```

배포된 컨트랙트의 ID를 각 섹션에 기록:

```json
{
  "version": "V7",
  "lastUpdated": "2026-XX-XX",
  "network": {
    "chainId": "<NEW_CHAIN_ID>"
  },
  "tokens": {
    "packageId": "<TOKENS_PACKAGE_ID>",
    "tokenFaucet": "<TOKEN_FAUCET_ID>",
    "claimRecord": "<CLAIM_RECORD_ID>"
  },
  "deepbook": {
    "tokenPackageId": "<TOKEN_PKG>",
    "packageId": "<DEEPBOOK_PKG>",
    "registry": "<REGISTRY_ID>",
    "adminCap": "<ADMIN_CAP_ID>"
  },
  "prediction": {
    "packageId": "<PREDICTION_PKG>",
    "adminCap": "<ADMIN_CAP_ID>",
    "globalState": "<GLOBAL_STATE_ID>"
  },
  "governance": {
    "packageId": "<GOVERNANCE_PKG>",
    "dashboard": "<DASHBOARD_ID>",
    "adminCap": "<ADMIN_CAP_ID>",
    "proposalTypeRegistry": "<REGISTRY_ID>"
  },
  "baram": {
    "packageId": "<BARAM_PKG>",
    "registry": "<REGISTRY_ID>",
    "executorPackageId": "<EXECUTOR_PKG>",
    "executorRegistry": "<EXECUTOR_REGISTRY_ID>"
  }
}
```

### Step 2: Sync .env Files

```bash
pnpm devnet:sync
```

이 명령은 다음 .env 파일들을 자동으로 업데이트합니다:
- `apps/pado/.env.development`
- `apps/pado/.env.staging`
- `apps/baram/.env`
- `apps/baram/frontend/.env`
- `apps/nasun-website/frontend/.env.development`

### Step 3: Commit Changes

```bash
git add packages/devnet-config/devnet-ids.json
git add apps/*/.env* apps/*/frontend/.env*
git commit -m "chore: update devnet IDs for V7"
```

---

## Verification Checklist

**Network:**
- [ ] All 2 nodes running (Node 1 validator+fullnode+faucet, Node 2 validator)
- [ ] Network running (Chain ID matches expected)
- [ ] Checkpoints progressing
- [ ] Faucet working (NSN per request, via Node 1)
- [ ] HTTPS endpoints working (rpc.devnet.nasun.io, faucet.devnet.nasun.io)
- [ ] zkLogin flow working (Google OAuth -> ZK Proof -> Transaction)

**Smart Contracts (15 packages):**
- [ ] Tier 1: devnet_tokens, deepbook_token, deepbook, governance, nsa, baram_executor, baram_attestation, baram_compliance
- [ ] Tier 2: prediction, lottery, oracle, lending, baram
- [ ] Tier 3: margin, perp
- [ ] Post-deploy: ProposalTypeRegistry, TierRegistry, CertificateRegistry, VotingPowerOracle, DeepBook Pools (2), BTC PerpMarket
- [ ] All Move.toml files updated with published-at
- [ ] TEE Executor registered (if EC2 enclave available)

**Frontend & Config:**
- [ ] devnet-ids.json updated with all contract IDs
- [ ] `pnpm devnet:sync` executed successfully
- [ ] Frontend .env files updated (via devnet:sync)
- [ ] CLAUDE.md documentation updated

**Infrastructure:**
- [ ] Monitoring scripts working (disk-monitor.sh, checkpoint-monitor.sh)
- [ ] EBS volume size sufficient (100GB recommended)
- [ ] DB pruning configured (num-epochs-to-retain: 50)

---

## Troubleshooting

### DB Schema Incompatibility

```
SerializationError("invalid value: integer `9`, expected variant index 0 <= i < 9")
Failed to deserialize value from DB table "epoch_start_configuration"
```

**Cause**: New binary cannot read DB created by different version
**Solution**: Full network reset with new genesis

### zkLogin Still Failing

Ensure the binary is built from a mainnet release tag. The verifying key must match prover-dev's proving key.

### Consensus Stuck

Both validators must be running with identical genesis.blob:

```bash
# Compare genesis on both nodes
md5sum ~/.sui/sui_config/genesis.blob

# Restart both validators if stuck
sudo systemctl restart nasun-validator  # Node 1
sudo systemctl restart nasun-validator  # Node 2
```

### Execution Engine Halt (SendError)

```
Failed to send certified blocks: SendError
```

**Cause**: Execution engine's mpsc channel receiver is dropped. Consensus continues producing blocks but execution layer cannot process them. No new checkpoints are generated.

**Diagnosis**:
```bash
# Check if checkpoints are progressing
curl -s -X POST http://3.38.127.23:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getLatestCheckpointSequenceNumber","params":[]}' | jq
# If checkpoint number is not increasing, execution is halted

# Check validator logs for SendError
sudo journalctl -u nasun-validator --since "1 hour ago" | grep -c "SendError"
```

**Solution**: Full DB wipe and restart (preserves Chain ID with existing genesis.blob):

```bash
# IMPORTANT: consensus_db and authorities_db are linked via commit index.
# You MUST delete both together. Deleting only consensus_db causes assertion panic:
#   "Commit replay should start at the beginning if there is no commit history"

# On Node 1 (validator + fullnode + faucet):
sudo systemctl stop nasun-faucet nasun-fullnode nasun-validator
rm -rf ~/authorities_db ~/consensus_db ~/full_node_db

# On Node 2 (validator):
sudo systemctl stop nasun-validator
rm -rf ~/authorities_db ~/consensus_db

# Restart services (validators first, then fullnode)
# Node 2:
sudo systemctl start nasun-validator
# Node 1:
sudo systemctl start nasun-validator
# Wait for consensus to stabilize:
sleep 30
sudo systemctl start nasun-fullnode
sleep 10
sudo systemctl start nasun-faucet
```

**Note**: This preserves the Chain ID but resets all on-chain state (contracts, transactions). Smart contracts must be redeployed.

### Faucet "No managed addresses" Error

```
No managed addresses
```

**Cause**: Faucet cannot find the keystore file. The client.yaml references a path that doesn't exist on the node.

**Solution**:
```bash
# On Node 1: Check client.yaml keystore path
grep keystore ~/.sui/sui_config/client.yaml
# Ensure keystore path in client.yaml matches actual file location
```

---

## Reset History

| Version | Date | Fork Source | Chain ID | Notes |
|---------|------|-------------|----------|-------|
| V3 | 2025-12-25 | v1.63.0 custom | `6681cdfd` | Initial reset for DeepBook |
| V4 | 2026-01-02 | v1.62.1 mainnet | `4c879694` | zkLogin fix |
| V5 | 2026-01-17 | v1.63.3 mainnet | `56c8b101` | 2-hour epoch, NSN token, DB pruning |
| V5 Recovery | 2026-01-23 | v1.63.3 mainnet | `56c8b101` | Execution halt recovery (DB wipe, 3-node arch) |
| V6 | 2026-01-27 | v1.63.3 mainnet | `12bf3808` | 2-node arch (cost reduction), consensus reset |
| V7 | 2026-02-04 | v1.63.3 mainnet | `272218f1` | Node 1 t3.xlarge upgrade, fullnode sync fix |

---

## See Also

- **[NASUN_DEVNET_POST_RESET_CHECKLIST.md](./NASUN_DEVNET_POST_RESET_CHECKLIST.md)** - Post-reset contract deployment and frontend update checklist
- **[NASUN_DEVNET_OPERATIONS.md](./NASUN_DEVNET_OPERATIONS.md)** - Day-to-day operations guide

---

**Document Version**: 5.1
**Last Updated**: 2026-02-04
