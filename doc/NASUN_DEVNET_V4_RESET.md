# Nasun Devnet V4 Reset Guide

**Date**: 2026-01-02
**Purpose**: Fix zkLogin Prover-Validator key mismatch by updating to Sui mainnet v1.62.1

## Background

### Issue
- zkLogin transactions fail with "Invalid signature" error
- Root cause: Prover-Validator key mismatch
  - `prover-dev` (Mysten Labs) uses updated proving key
  - Nasun Devnet (based on v1.63.0 custom) has older verifying key

### Solution
- Update nodes to latest Sui mainnet release (v1.62.1)
- Reset network with new genesis (required due to DB schema incompatibility)
- Redeploy all smart contracts

## Pre-Reset Checklist

### Current Contract Inventory

| Contract | Package ID | Notes |
|----------|------------|-------|
| DeepBook V3 | `0xceaeca5c...` | CLOB for trading |
| DeepBook Registry | `0xf38bd1c8...` | Pool registry |
| Pado Tokens | `0xb083f14e...` | NBTC, NUSDC + Faucet |
| Token Faucet | `0x6f40eeee...` | Shared object |
| Claim Record | `0xb17a4b82...` | 24h cooldown tracking |
| Prediction Market | `0x6754f580...` | Binary prediction |
| GlobalState | `0x02bd4975...` | Prediction state |
| NBTC/NUSDC Pool | `0xd19dfb9a...` | Trading pool |
| NASUN/NUSDC Pool | `0x9022d534...` | Trading pool |
| Governance | TBD | Vote contracts |

### Files to Update After Reset

```
apps/pado/.env.staging
apps/pado/.env.development
apps/pado/.env.local
apps/pado/frontend/.env.staging
packages/wallet/src/config/tokens.ts (if token types change)
CLAUDE.md (both repos)
```

## Phase 1: Build New Binary

```bash
cd /home/naru/my_apps/nasun-devnet/sui

# Create branch from latest stable release
git fetch upstream --tags
git checkout -b nasun-v4-mainnet-1.62.1 mainnet-v1.62.1

# Build (takes ~20-40 min, or 3-4 min with ccache)
cargo build --release

# Verify build
./target/release/sui --version
./target/release/sui-node --version
```

## Phase 2: Stop Services on Both Nodes

```bash
# Node 1 (3.38.127.23)
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.127.23
sudo systemctl stop nasun-validator nasun-fullnode nasun-faucet
sudo systemctl status nasun-validator nasun-fullnode nasun-faucet

# Node 2 (3.38.76.85)
ssh -i ~/.ssh/.awskey/nasun-devnet-key.pem ubuntu@3.38.76.85
sudo systemctl stop nasun-validator
sudo systemctl status nasun-validator
```

## Phase 3: Deploy New Binary

```bash
# From local machine
scp -i ~/.ssh/.awskey/nasun-devnet-key.pem \
  /home/naru/my_apps/nasun-devnet/sui/target/release/sui-node \
  ubuntu@3.38.127.23:~/sui-node

scp -i ~/.ssh/.awskey/nasun-devnet-key.pem \
  /home/naru/my_apps/nasun-devnet/sui/target/release/sui-node \
  ubuntu@3.38.76.85:~/sui-node

# Also copy sui and sui-faucet for Node 1
scp -i ~/.ssh/.awskey/nasun-devnet-key.pem \
  /home/naru/my_apps/nasun-devnet/sui/target/release/sui \
  /home/naru/my_apps/nasun-devnet/sui/target/release/sui-faucet \
  ubuntu@3.38.127.23:~/
```

## Phase 4: Clear Old Data (Both Nodes)

```bash
# On Node 1
rm -rf ~/authorities_db ~/consensus_db ~/full_node_db ~/.nasun

# On Node 2
rm -rf ~/authorities_db ~/consensus_db ~/.nasun
```

## Phase 5: Generate New Genesis (Node 1 Only)

```bash
# On Node 1 (3.38.127.23)
./sui genesis --force --epoch-duration-ms 60000 --committee-size 2 \
  --benchmark-ips 3.38.127.23 3.38.76.85 --with-faucet

# Fix Fullnode config (bind to 0.0.0.0 for external access)
sed -i 's|network-address: /ip4/127.0.0.1|network-address: /ip4/0.0.0.0|g' ~/.nasun/nasun_config/fullnode.yaml
sed -i 's|listen-address: "127.0.0.1|listen-address: "0.0.0.0|g' ~/.nasun/nasun_config/fullnode.yaml

# Fix Validator config (EC2 NAT requires 0.0.0.0)
sed -i 's|network-address: /ip4/3.38.127.23|network-address: /ip4/0.0.0.0|' ~/.nasun/nasun_config/3.38.127.23-*.yaml

# Verify new chain ID
grep -A2 "chain_id" ~/.nasun/nasun_config/fullnode.yaml
```

## Phase 6: Distribute Genesis to Node 2

```bash
# From Node 1
scp ~/.nasun/nasun_config/genesis.blob ubuntu@3.38.76.85:~/.nasun/nasun_config/
scp ~/.nasun/nasun_config/3.38.76.85-*.yaml ubuntu@3.38.76.85:~/validator.yaml

# On Node 2: Fix Validator config
ssh ubuntu@3.38.76.85
sed -i 's|network-address: /ip4/3.38.76.85|network-address: /ip4/0.0.0.0|' ~/validator.yaml
```

## Phase 7: Start Services

```bash
# Node 2 first (validator only)
ssh ubuntu@3.38.76.85
sudo systemctl start nasun-validator
sudo systemctl status nasun-validator

# Then Node 1 (validator + fullnode + faucet)
ssh ubuntu@3.38.127.23
sudo systemctl start nasun-validator nasun-fullnode nasun-faucet
sudo systemctl status nasun-validator nasun-fullnode nasun-faucet
```

## Phase 8: Verify Network

```bash
# Check Chain ID
curl -X POST http://3.38.127.23:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getChainIdentifier","params":[]}'

# Check checkpoint progress
curl -X POST http://3.38.127.23:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getLatestCheckpointSequenceNumber","params":[]}'

# Test faucet
curl -X POST http://3.38.127.23:5003/gas \
  -H "Content-Type: application/json" \
  -d '{"FixedAmountRequest":{"recipient":"<YOUR_ADDRESS>"}}'
```

---

# Smart Contract Redeployment

## Order of Deployment

1. **Pado Tokens + Faucet** (NBTC, NUSDC) - Required for trading
2. **DeepBook V3** - CLOB for order matching
3. **Trading Pools** - NBTC/NUSDC, NASUN/NUSDC
4. **Prediction Market** - Binary prediction contracts
5. **Governance** - Voting contracts (if applicable)

## Step 1: Deploy Pado Tokens + Faucet

```bash
cd /home/naru/my_apps/nasun-monorepo/apps/pado/contracts

# Build
/home/naru/my_apps/nasun-devnet/sui/target/release/sui move build

# Deploy
/home/naru/my_apps/nasun-devnet/sui/target/release/sui client publish --gas-budget 100000000

# Expected outputs:
# - Package ID (VITE_TOKENS_PACKAGE, VITE_FAUCET_PACKAGE)
# - TokenFaucet shared object (VITE_TOKEN_FAUCET)
# - ClaimRecord shared object (VITE_CLAIM_RECORD)
# - NBTC type: <PACKAGE>::nbtc::NBTC
# - NUSDC type: <PACKAGE>::nusdc::NUSDC
```

Record the following:
- Package ID → `VITE_TOKENS_PACKAGE`, `VITE_FAUCET_PACKAGE`
- TokenFaucet ID → `VITE_TOKEN_FAUCET`
- ClaimRecord ID → `VITE_CLAIM_RECORD`

## Step 2: Deploy DeepBook V3

```bash
cd /home/naru/my_apps/nasun-monorepo/apps/pado/deepbook-v3

# Build
/home/naru/my_apps/nasun-devnet/sui/target/release/sui move build

# Deploy
/home/naru/my_apps/nasun-devnet/sui/target/release/sui client publish --gas-budget 200000000

# Expected outputs:
# - Package ID (VITE_DEEPBOOK_PACKAGE)
# - Registry shared object (VITE_DEEPBOOK_REGISTRY)
# - AdminCap owned object (VITE_DEEPBOOK_ADMIN_CAP)
```

Record the following:
- Package ID → `VITE_DEEPBOOK_PACKAGE`
- Registry ID → `VITE_DEEPBOOK_REGISTRY`
- AdminCap ID → `VITE_DEEPBOOK_ADMIN_CAP`

## Step 3: Create Trading Pools

```bash
# Use sui client call to create pools
# NBTC/NUSDC pool
/home/naru/my_apps/nasun-devnet/sui/target/release/sui client call \
  --package <DEEPBOOK_PACKAGE> \
  --module pool \
  --function create_pool \
  --type-args '<TOKENS_PACKAGE>::nbtc::NBTC' '<TOKENS_PACKAGE>::nusdc::NUSDC' \
  --args <REGISTRY_ID> <tick_size> <lot_size> <min_size> <creation_fee> \
  --gas-budget 100000000

# NASUN/NUSDC pool
/home/naru/my_apps/nasun-devnet/sui/target/release/sui client call \
  --package <DEEPBOOK_PACKAGE> \
  --module pool \
  --function create_pool \
  --type-args '0x2::sui::SUI' '<TOKENS_PACKAGE>::nusdc::NUSDC' \
  --args <REGISTRY_ID> <tick_size> <lot_size> <min_size> <creation_fee> \
  --gas-budget 100000000
```

Record the following:
- NBTC/NUSDC Pool ID → `VITE_POOL_NBTC_NUSDC`
- NASUN/NUSDC Pool ID → `VITE_POOL_NASUN_NUSDC`

## Step 4: Deploy Prediction Market

```bash
cd /home/naru/my_apps/nasun-monorepo/apps/pado/contracts-prediction

# Build
/home/naru/my_apps/nasun-devnet/sui/target/release/sui move build

# Deploy
/home/naru/my_apps/nasun-devnet/sui/target/release/sui client publish --gas-budget 100000000

# Expected outputs:
# - Package ID
# - AdminCap
# - GlobalState shared object
```

## Step 5: Create Test Markets

```bash
# Create BTC prediction market
/home/naru/my_apps/nasun-devnet/sui/target/release/sui client call \
  --package <PREDICTION_PACKAGE> \
  --module prediction_market \
  --function create_market \
  --args <ADMIN_CAP> <GLOBAL_STATE> \
    "Will BTC reach $150,000 by March 2026?" \
    "Prediction description" \
    "Crypto" \
    <end_timestamp_ms> \
    <resolution_timestamp_ms> \
    <RESOLVER_ADDRESS> \
  --gas-budget 100000000
```

---

# Update Configuration Files

## Template for .env files

```bash
# Nasun Devnet Configuration
# Generated: 2026-01-02 (V4 Reset)

# Network
VITE_RPC_URL=https://rpc.devnet.nasun.io
VITE_FAUCET_URL=https://faucet.devnet.nasun.io/gas
VITE_CHAIN_ID=<NEW_CHAIN_ID>

# DeepBook V3 Package
VITE_DEEPBOOK_PACKAGE=<NEW_DEEPBOOK_PACKAGE>
VITE_DEEPBOOK_REGISTRY=<NEW_REGISTRY>
VITE_DEEPBOOK_ADMIN_CAP=<NEW_ADMIN_CAP>

# Pado Test Tokens Package
VITE_TOKENS_PACKAGE=<NEW_TOKENS_PACKAGE>

# Token Types
VITE_NBTC_TYPE=<NEW_TOKENS_PACKAGE>::nbtc::NBTC
VITE_NUSDC_TYPE=<NEW_TOKENS_PACKAGE>::nusdc::NUSDC

# Trading Pools
VITE_POOL_NBTC_NUSDC=<NEW_POOL_ID>
VITE_POOL_NASUN_NUSDC=<NEW_POOL_ID>

# Token Faucet (shared objects)
VITE_FAUCET_PACKAGE=<NEW_TOKENS_PACKAGE>
VITE_TOKEN_FAUCET=<NEW_TOKEN_FAUCET>
VITE_CLAIM_RECORD=<NEW_CLAIM_RECORD>

# Prediction Market
VITE_PREDICTION_RESOLVER_ADDRESS=<RESOLVER_ADDRESS>

# zkLogin Authentication
VITE_GOOGLE_CLIENT_ID=869935693878-o7ln8iu737ia6a6ujsfrjineh94k5ubh.apps.googleusercontent.com
VITE_ZKLOGIN_SALT_API_URL=https://ar4sxrde2c.execute-api.ap-northeast-2.amazonaws.com/prod/auth/zklogin/salt
```

## Files to Update

1. `apps/pado/.env.staging`
2. `apps/pado/.env.development`
3. `apps/pado/.env.local`
4. `apps/pado/frontend/.env.staging` (copy of above)
5. `packages/wallet/src/config/tokens.ts` (if token package changed)

---

# Verification Checklist

- [ ] Network running (Chain ID matches)
- [ ] Checkpoints progressing
- [ ] Faucet working
- [ ] zkLogin flow working (Google OAuth → ZK Proof → Transaction)
- [ ] Token faucet working (NBTC, NUSDC)
- [ ] Trading pools accessible
- [ ] Prediction markets visible

---

# Rollback Procedure

If the new version fails:

```bash
# Stop services
sudo systemctl stop nasun-validator nasun-fullnode nasun-faucet

# Restore old binary (if saved)
cp ~/sui-node.backup ~/sui-node

# Clear corrupted DB
rm -rf ~/authorities_db ~/consensus_db ~/full_node_db

# Regenerate genesis with old binary
./sui genesis --force ...

# Start services
sudo systemctl start nasun-validator nasun-fullnode nasun-faucet
```

---

# Troubleshooting

## DB Schema Incompatibility

```
SerializationError("invalid value: integer `9`, expected variant index 0 <= i < 9")
Failed to deserialize value from DB table "epoch_start_configuration"
```

**Cause**: New binary cannot read DB created by different version
**Solution**: Full network reset with new genesis

## zkLogin Still Failing

Check ZkLoginEnv in verifying key:
- Prod environment: Uses `GLOBAL_VERIFYING_KEY`
- Test environment: Uses `INSECURE_VERIFYING_KEY`

Ensure binary is built with correct environment.

## Consensus Stuck

Both validators must be running with identical genesis.blob.
Check logs:
```bash
sudo journalctl -u nasun-validator -f
```

---

## Phase 7.5: Log Management Setup (REQUIRED!)

> ⚠️ **CRITICAL**: Without these settings, syslog can fill up the disk in days!
> This was the cause of the 2026-01-04 disk full incident.

### 1. Verify RUST_LOG Settings

All services must have `RUST_LOG=warn`:

```bash
# On both nodes
grep RUST_LOG /etc/systemd/system/nasun-*.service
# Should all show: Environment="RUST_LOG=warn"

# If validator has debug/trace level, fix it:
sudo sed -i 's/Environment="RUST_LOG=.*"/Environment="RUST_LOG=warn"/' /etc/systemd/system/nasun-validator.service
sudo systemctl daemon-reload
```

### 2. Configure logrotate

```bash
# On both nodes
sudo tee /etc/logrotate.d/rsyslog << 'EOF'
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
EOF
```

### 3. Configure journald Limits

```bash
# On both nodes
sudo tee /etc/systemd/journald.conf << 'EOF'
[Journal]
SystemMaxUse=500M
SystemKeepFree=1G
MaxRetentionSec=7day
MaxFileSec=1day
EOF

sudo systemctl restart systemd-journald
```

### 4. Install Disk Monitoring Script

```bash
# On both nodes
cat > ~/disk-monitor.sh << 'EOF'
#!/bin/bash
THRESHOLD=80
USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$USAGE" -ge "$THRESHOLD" ]; then
    echo "ALERT: Disk usage at ${USAGE}% on $(hostname)" | logger -t disk-monitor
    aws sns publish --topic-arn arn:aws:sns:ap-northeast-2:150674276464:nasun-devnet-alerts \
      --message "ALERT: Disk usage at ${USAGE}%" \
      --subject "Nasun Devnet Disk Alert" 2>/dev/null || true
fi
EOF

chmod +x ~/disk-monitor.sh

# Add to cron (hourly)
(crontab -l 2>/dev/null | grep -v disk-monitor; echo "0 * * * * /home/ubuntu/disk-monitor.sh") | crontab -
```

### 5. Verification Checklist

- [ ] `grep RUST_LOG /etc/systemd/system/nasun-*.service` → all show `warn`
- [ ] `cat /etc/logrotate.d/rsyslog | grep maxsize` → shows `100M`
- [ ] `cat /etc/systemd/journald.conf | grep SystemMaxUse` → shows `500M`
- [ ] `ls -la ~/disk-monitor.sh` → file exists
- [ ] `crontab -l | grep disk-monitor` → shows hourly cron

---

**Document Version**: 1.1
**Last Updated**: 2026-01-04
