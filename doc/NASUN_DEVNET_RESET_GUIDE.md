# Nasun Devnet Network Reset Guide

**Version**: 4.1
**Last Updated**: 2026-01-27
**Current Network**: V6 (Chain ID: `12bf3808`)

---

## Overview

This guide documents the network reset procedure for Nasun Devnet. A reset is required when:
- Upgrading to a new Sui mainnet release (for zkLogin compatibility)
- Changing epoch duration or other genesis parameters
- Fixing DB schema incompatibility issues

---

## Current Network Status (V6)

| Item | Value |
|------|-------|
| **Chain ID** | `12bf3808` |
| **Fork Source** | Sui mainnet v1.63.3 |
| **Native Token** | NSN (min unit: SOE) |
| **Epoch Duration** | 2 hours (7,200,000ms) |
| **DB Pruning** | 50 epochs (~4 days) |
| **zkLogin** | Supported (prover-dev compatible) |

### Node Architecture (2-Node)

| Node | IP | Role | Instance |
|------|-----|------|----------|
| Node 1 | 3.38.127.23 | Validator + Fullnode + Faucet + nginx | c6i.xlarge |
| Node 2 | 3.38.76.85 | Validator | c6i.xlarge |

> **Note**: V6 uses 2-node architecture for cost reduction (~$60/month savings)

---

## Pre-Reset Checklist

### 1. Current Contract Inventory

Record all deployed contracts before reset:

| Contract | Package ID | Notes |
|----------|------------|-------|
| Devnet Tokens | | 통합 NBTC, NUSDC + Faucet (packages/devnet-tokens) |
| DeepBook V3 | | CLOB for trading |
| Prediction Market | | Binary prediction |
| Governance | | Vote contracts |
| Baram | | TEE-based price oracle |

### 2. Files to Update After Reset (Centralized ID Management)

**V6부터 `@nasun/devnet-config` 패키지를 통한 중앙화된 ID 관리를 사용합니다.**

대부분의 앱이 이미 이 패키지를 사용하도록 마이그레이션되었으므로,
리셋 후에는 다음 파일들만 업데이트하면 됩니다:

```
# 1. 중앙 소스 (핵심 - 반드시 업데이트)
packages/devnet-config/devnet-ids.json

# 2. Move.toml 파일 (수동 업데이트 필요)
packages/devnet-tokens/Move.toml              # 통합 토큰 패키지
apps/pado/contracts/Move.toml
apps/pado/contracts-prediction/Move.toml
apps/baram/contracts/Move.toml
apps/baram/contracts-executor/Move.toml
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
# Node 1 (3.38.127.23) - Validator
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.127.23
sudo systemctl stop nasun-validator

# Node 2 (3.38.76.85) - Validator
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.76.85
sudo systemctl stop nasun-validator

# Node 3 (52.78.117.96) - Fullnode + Faucet
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@52.78.117.96
sudo systemctl stop nasun-fullnode nasun-faucet
```

---

## Phase 3: Deploy New Binary

```bash
# From local machine - deploy sui-node to validators
scp -i ~/.ssh/.awskey/nasun-devnet-key.pem \
  target/release/sui-node ubuntu@3.38.127.23:~/
scp -i ~/.ssh/.awskey/nasun-devnet-key.pem \
  target/release/sui-node ubuntu@3.38.76.85:~/

# Deploy sui-node, sui, and sui-faucet to Node 3 (Fullnode + Faucet)
scp -i ~/.ssh/.awskey/nasun-devnet-key.pem \
  target/release/sui-node target/release/sui target/release/sui-faucet \
  ubuntu@52.78.117.96:~/
```

---

## Phase 4: Clear Old Data (All Nodes)

```bash
# On Node 1 (Validator)
rm -rf ~/authorities_db ~/consensus_db ~/.sui ~/.nasun

# On Node 2 (Validator)
rm -rf ~/authorities_db ~/consensus_db ~/.sui ~/.nasun

# On Node 3 (Fullnode)
rm -rf ~/full_node_db ~/.sui ~/.nasun
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

## Phase 7: Distribute Genesis to Node 2 and Node 3

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

# On Node 1: Copy genesis and fullnode config to Node 3
scp ~/.sui/sui_config/genesis.blob ubuntu@52.78.117.96:~/.nasun/nasun_config/
scp ~/.sui/sui_config/fullnode.yaml ubuntu@52.78.117.96:~/.nasun/nasun_config/
scp ~/.sui/sui_config/sui.keystore ubuntu@52.78.117.96:~/.nasun/nasun_config/
scp ~/.sui/sui_config/client.yaml ubuntu@52.78.117.96:~/.nasun/nasun_config/

# On Node 3: Setup directories and symlinks
ssh ubuntu@52.78.117.96
mkdir -p ~/.nasun/nasun_config ~/.sui/sui_config
# Symlink for faucet's keystore path reference
ln -sf ~/.nasun/nasun_config/sui.keystore ~/.sui/sui_config/sui.keystore
```

---

## Phase 8: Verify Log Management Settings

```bash
# On all 3 nodes - verify RUST_LOG setting
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

# 2. Node 1 (validator only)
ssh ubuntu@3.38.127.23
sudo systemctl start nasun-validator
sudo systemctl status nasun-validator

# 3. Wait for consensus to stabilize
sleep 30

# 4. Node 3 (fullnode + faucet)
ssh ubuntu@52.78.117.96
sudo systemctl start nasun-fullnode
sleep 10
sudo systemctl start nasun-faucet
sudo systemctl status nasun-fullnode nasun-faucet
```

---

## Phase 10: Verify Network

```bash
# Check Chain ID (via Node 3 Fullnode)
curl -X POST http://52.78.117.96:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getChainIdentifier","params":[]}'

# Check checkpoint progress
curl -X POST http://52.78.117.96:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getLatestCheckpointSequenceNumber","params":[]}'

# Test faucet (Node 3)
curl -X POST http://52.78.117.96:5003/gas \
  -H "Content-Type: application/json" \
  -d '{"FixedAmountRequest":{"recipient":"<YOUR_ADDRESS>"}}'

# Also verify via HTTPS endpoints
curl -X POST https://rpc.devnet.nasun.io \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getChainIdentifier","params":[]}'
```

---

## Smart Contract Redeployment

### Deployment Order

1. **Pado Tokens + Faucet** (NBTC, NUSDC) - Required for trading
2. **DeepBook V3** - CLOB for order matching
3. **Trading Pools** - NBTC/NUSDC, NSN/NUSDC
4. **Prediction Market** - Binary prediction contracts
5. **Governance** - Voting contracts
6. **Baram** - AI Settlement Layer (includes pado_tokens)
7. **Baram Executor** - TEE Executor Registry

### Step 1: Deploy Pado Tokens + Faucet

```bash
cd /home/naru/my_apps/nasun-monorepo/apps/pado/contracts
sui move build
sui client publish --gas-budget 100000000

# Record:
# - Package ID -> VITE_TOKENS_PACKAGE
# - TokenFaucet ID -> VITE_TOKEN_FAUCET
# - ClaimRecord ID -> VITE_CLAIM_RECORD
```

### Step 2: Deploy DeepBook V3

```bash
cd /home/naru/my_apps/nasun-monorepo/apps/pado/deepbook-v3
sui move build
sui client publish --gas-budget 200000000

# Record:
# - Package ID -> VITE_DEEPBOOK_PACKAGE
# - Registry ID -> VITE_DEEPBOOK_REGISTRY
# - AdminCap ID -> VITE_DEEPBOOK_ADMIN_CAP
```

### Step 3: Deploy Prediction Market

```bash
cd /home/naru/my_apps/nasun-monorepo/apps/pado/contracts-prediction
sui move build
sui client publish --gas-budget 100000000

# Record:
# - Package ID -> PREDICTION_PACKAGE_ID
# - AdminCap -> PREDICTION_ADMIN_CAP
# - GlobalState -> PREDICTION_GLOBAL_STATE
```

### Step 4: Deploy Governance

```bash
cd /home/naru/my_apps/nasun-monorepo/apps/nasun-website/contracts/governance
sui move build
sui client publish --gas-budget 100000000

# Record:
# - Package ID -> NASUN_DEVNET_PACKAGE_ID
# - Dashboard -> NASUN_DEVNET_DASHBOARD_ID
# - AdminCap -> NASUN_DEVNET_ADMIN_CAP
```

### Step 5: Deploy Baram (AI Settlement Layer)

> **Note**: Baram uses pado_tokens as dependency. Use `--with-unpublished-dependencies` if pado_tokens
> was not separately published, or ensure pado_tokens has proper Pub.devnet.toml.

```bash
cd /home/naru/my_apps/nasun-monorepo/apps/baram/contracts

# Update Move.toml [environments] section with new chain ID
# Remove pado address from [addresses] if using dependency

# Build and publish
sui client test-publish --build-env devnet --with-unpublished-dependencies --gas-budget 100000000

# Record:
# - Package ID -> VITE_BARAM_PACKAGE_ID
# - BaramRegistry (shared) -> VITE_BARAM_REGISTRY_ID
# - UpgradeCap -> VITE_BARAM_UPGRADE_CAP
# - NUSDC Type -> VITE_NUSDC_TYPE (e.g., <PKG>::nusdc::NUSDC)
```

### Step 6: Deploy Baram Executor Registry

```bash
cd /home/naru/my_apps/nasun-monorepo/apps/baram/contracts-executor

# Update Move.toml [environments] section with new chain ID

# Build and publish
sui client test-publish --build-env devnet --gas-budget 100000000

# Record:
# - Package ID -> VITE_EXECUTOR_PACKAGE_ID
# - ExecutorRegistry (shared) -> VITE_EXECUTOR_REGISTRY_ID
# - AdminCap -> VITE_EXECUTOR_ADMIN_CAP
```

### Step 7: Register TEE Executor (Optional - requires EC2 enclave)

After deploying executor-nitro on EC2 Nitro Enclave, register the executor:

```bash
# Get RSA public key from enclave attestation
# Then register executor using AdminCap

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

- [ ] All 2 nodes running (Node 1 validator+fullnode+faucet, Node 2 validator)
- [ ] Network running (Chain ID matches expected)
- [ ] Checkpoints progressing
- [ ] Faucet working (100 NSN per request, via Node 1)
- [ ] HTTPS endpoints working (rpc.devnet.nasun.io, faucet.devnet.nasun.io)
- [ ] zkLogin flow working (Google OAuth -> ZK Proof -> Transaction)
- [ ] All contracts redeployed
- [ ] Baram contracts deployed (baram + baram_executor)
- [ ] TEE Executor registered (if EC2 enclave available)
- [ ] devnet-ids.json updated with all contract IDs
- [ ] `pnpm devnet:sync` executed successfully
- [ ] Frontend .env files updated (via devnet:sync)
- [ ] CLAUDE.md documentation updated
- [ ] Monitoring scripts working (disk-monitor.sh, checkpoint-monitor.sh)

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
curl -s -X POST http://52.78.117.96:9000 \
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

# On Node 1 and Node 2 (both validators):
sudo systemctl stop nasun-validator
rm -rf ~/authorities_db ~/consensus_db

# On Node 3 (fullnode):
sudo systemctl stop nasun-fullnode nasun-faucet
rm -rf ~/full_node_db

# Restart services (validators first, then fullnode)
# Node 2:
sudo systemctl start nasun-validator
# Node 1:
sudo systemctl start nasun-validator
# Wait for consensus to stabilize, then Node 3:
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
# Check client.yaml keystore path
grep keystore ~/.nasun/nasun_config/client.yaml

# Create symlink if needed (e.g., client.yaml references ~/.sui/sui_config/sui.keystore)
mkdir -p ~/.sui/sui_config
ln -sf ~/.nasun/nasun_config/sui.keystore ~/.sui/sui_config/sui.keystore
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

---

## See Also

- **[NASUN_DEVNET_POST_RESET_CHECKLIST.md](./NASUN_DEVNET_POST_RESET_CHECKLIST.md)** - Post-reset contract deployment and frontend update checklist
- **[NASUN_DEVNET_OPERATIONS.md](./NASUN_DEVNET_OPERATIONS.md)** - Day-to-day operations guide

---

**Document Version**: 4.1
**Last Updated**: 2026-01-27
