# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 언어 설정

**모든 응답과 사고는 한국어로 진행합니다.** 코드 주석, 커밋 메시지, 문서 작성 시에도 한국어를 사용합니다.

## Project Overview

**Nasun Devnet** is a forked SUI blockchain network for development and testing purposes.

| Spec | Value |
|------|-------|
| Network Name | Nasun Devnet |
| Chain ID | `nasun-devnet-1` |
| Native Token | NASUN |
| Consensus | Narwhal/Bullshark (SUI default) |
| Validators | 2 nodes (EC2 c6i.xlarge) |

## Repository Structure

```
nasun-devnet/
├── doc/                    # Planning and documentation
│   └── NASUN_DEVNET_SETUP_PLAN.md  # Master setup guide
├── sui/                    # SUI fork code (to be cloned)
├── genesis/                # Genesis files
├── configs/                # Node configuration files
└── scripts/                # Automation scripts
```

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

## 2-Node Consensus Notes

- Minimum viable for Devnet (f=0 Byzantine fault tolerance)
- Both nodes must be running for consensus to proceed
- Single node failure halts the network
- Upgrade to 4+ nodes for production fault tolerance
