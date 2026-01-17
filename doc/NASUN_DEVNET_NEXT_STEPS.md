# Nasun Devnet 다음 단계 계획서

**Version**: 2.0.0
**Created**: 2025-12-13
**Updated**: 2026-01-17
**Author**: Claude Code
**Status**: V5 리셋 완료, 스마트 컨트랙트 배포 완료, 더미 데이터 생성 완료
**Prerequisites**: Nasun Devnet V5 운영 중 (Sui mainnet v1.63.3 기반)

---

## 목차

1. [개요](#1-개요)
2. [V5 리셋 (완료)](#2-v5-리셋-완료)
3. [스마트 컨트랙트 재배포 (완료)](#3-스마트-컨트랙트-재배포-완료)
4. [더미 데이터 생성 (완료)](#4-더미-데이터-생성-완료)
5. [프론트엔드 설정 업데이트 (완료)](#5-프론트엔드-설정-업데이트-완료)
6. [다음 리셋 시 참고사항](#6-다음-리셋-시-참고사항)
7. [체크리스트](#7-체크리스트)

---

## 1. 개요

### 1.1 현재 상태 (2026-01-17 V5 리셋 완료)

| 항목 | 값 |
|------|-----|
| **Network** | Nasun Devnet |
| **Chain ID** | `56c8b101` (2026-01-17 V5 리셋) |
| **Fork Source** | Sui mainnet v1.63.3 |
| **Epoch Duration** | **2시간** (V4: 1분 → V5: 2시간) |
| **Native Token** | **NSN** (V4: NASUN → V5: NSN) |
| **DB Pruning** | **50 epochs** (~4일) |
| **RPC Endpoint** | `https://rpc.devnet.nasun.io` |
| **Status** | ✅ V5 운영 중, 모든 서비스 정상 |

### 1.2 V5 주요 변경사항

| 항목 | V4 | V5 | 변경 이유 |
|------|-----|-----|----------|
| Epoch Duration | 1분 | **2시간** | DB 증가 속도 120배 감소 |
| Native Token | NASUN | **NSN** | 브랜딩 변경 |
| DB Pruning | 0 (비활성화) | **50 epochs** | 디스크 관리 |

---

## 2. V5 리셋 (완료) ✅

- **작업일**: 2026-01-17
- **Chain ID**: `56c8b101`
- **목적**: 장기 안정 운영을 위한 epoch 조정 및 DB 최적화

### 2.1 리셋 절차 요약

1. Sui mainnet v1.63.3 빌드
2. 양 노드 서비스 중지 및 데이터 삭제
3. Genesis 생성 (`--epoch-duration-ms 7200000`)
4. 로그 관리 설정 확인
5. 서비스 재시작

상세 절차: [NASUN_DEVNET_V4_RESET.md](./NASUN_DEVNET_V4_RESET.md)

---

## 3. 스마트 컨트랙트 재배포 (완료) ✅

### 3.1 배포된 컨트랙트 목록

| 컨트랙트 | Package ID | 상태 |
|----------|------------|------|
| **Pado Tokens** | `0xc84727af62147f35ccf070f521e441f48be9325ab0a1b56225f361f0bc266bb8` | ✅ 완료 |
| **DeepBook V3** | `0x379b630c75bada9c10e5f0f0abc76d0462a57ce121430359ecd0c5dc34a01056` | ✅ 완료 |
| **Prediction Market** | `0xc428b702930337328044520256f783e51e80790cd766d5b6f77e7b126d3abb99` | ✅ 완료 |
| **Governance** | `0xa4636c566d7d06bcb3802e248390007a09fb78837349bce3cb71eadd905937cf` | ✅ 완료 |

### 3.2 Shared Object IDs

| 객체 | Object ID |
|------|-----------|
| TokenFaucet | `0xd8722be320d057f7f47aa562f3d54f2e4bc51ea6a53cc05972940640d4f81708` |
| ClaimRecord | `0x563fc1bb0e65babac3e34b698676c207b1f2b59c2b3e8feb5c230dab1809e689` |
| DeepBook Registry | `0xf2126547e61cccb012fa6f172ec81cc5278954492bc1c474848202f262953042` |
| Prediction GlobalState | `0x59320a0a63a16bdf5ad4173ed331d81f17afd63b706bd398fab0d629df6f4f7c` |
| Governance Dashboard | `0x542142dcf283834783cbf75e4b2e5bd32458a02171232738638b86de386acd0d` |
| ProposalTypeRegistry | `0x4da0ef1eb2cfd06970ceebcc9524d3819b0c5174eca18af1090338b25d4de756` |

---

## 4. 더미 데이터 생성 (완료) ✅

### 4.1 Governance Proposals

| 제목 | 타입 | Proposal ID |
|------|------|-------------|
| NSN Staking Reward Adjustment | Governance (Fee) | `0x464be9dc...` |
| Developer Grant Program | Governance (Fee) | `0x9019c7c4...` |
| AI Services 2026 Priority | Poll (Sponsored) | `0xd8cf3d4d...` |
| Community Event Preference | Poll (Sponsored) | `0x870ff5d5...` |

### 4.2 Prediction Markets

| 카테고리 | 질문 | Market ID |
|----------|------|-----------|
| AI Technology | Will OpenAI release GPT-5 in Q1 2026? | `0xdc2110ed...` |
| Crypto | Will BTC reach 200K by 2026? | `0x8d0f9ffc...` |
| Sports | Will Korea advance to 2026 World Cup semifinals? | `0x02e0ffab...` |

---

## 5. 프론트엔드 설정 업데이트 (완료) ✅

### 5.1 업데이트된 파일 목록

#### Pado 앱

| 파일 | 업데이트 내용 |
|------|-------------|
| `.env.development` | V5 환경변수 전체 업데이트 |
| `.env.staging` | V5 환경변수 전체 업데이트 |
| `.env.local` | V5 환경변수 전체 업데이트 |
| `frontend/src/features/prediction/constants.ts` | V5 Package ID, Market IDs |
| `frontend/src/lib/unified-margin.ts` | V5 PADO_TOKENS_PACKAGE |
| `frontend/src/features/lottery/constants.ts` | V5 NUSDC_TYPE |
| `frontend/src/features/earn/hooks/useLendingActions.ts` | V5 NUSDC_TYPE |
| `frontend/src/features/perp/hooks/usePerpOrder.ts` | V5 nusdcType |
| `contracts/Move.toml` | V5 published-at, pado address |
| `contracts-prediction/Move.toml` | V5 pado address, environments |

#### Nasun Website

| 파일 | 업데이트 내용 |
|------|-------------|
| `frontend/.env.development` | V5 Governance 환경변수 |
| `frontend/.env.local` | V5 Governance 환경변수 |
| `frontend/src/constants/suiPackageConstants.ts` | V5 NASUN_DEVNET_* 상수 |

---

## 6. 다음 리셋 시 참고사항

> **중요**: 다음 Devnet 리셋 시 아래 문서를 참조하세요.

### 6.1 Post-Reset Checklist

**[NASUN_DEVNET_POST_RESET_CHECKLIST.md](./NASUN_DEVNET_POST_RESET_CHECKLIST.md)** 문서에 다음 내용이 포함되어 있습니다:

1. **스마트 컨트랙트 배포 순서** - 의존성 고려한 배포 순서
2. **더미 데이터 생성 명령어** - Proposal, Poll, Prediction Market
3. **프론트엔드 파일 업데이트 목록** - 업데이트가 필요한 모든 파일과 변수명
4. **검증 체크리스트** - 리셋 후 확인해야 할 항목

### 6.2 리셋 후 작업 순서

```
1. 네트워크 검증 (Chain ID, 체크포인트, Faucet)
2. 스마트 컨트랙트 배포
   - Pado Tokens + Faucet
   - DeepBook V3
   - Prediction Market
   - Governance
3. 더미 데이터 생성
   - Governance Proposals (2개 이상)
   - Governance Polls (2개 이상)
   - Prediction Markets (3개 이상)
4. 프론트엔드 설정 업데이트
   - .env 파일들
   - 하드코딩된 constants.ts 파일들
5. 개발 서버 재시작 및 검증
```

---

## 7. 체크리스트

### V5 리셋 및 복구

- [x] Sui v1.63.3 빌드 및 배포
- [x] Genesis 재생성 (Chain ID: `56c8b101`, Epoch: 2시간)
- [x] 노드 서비스 재시작 및 동기화
- [x] HTTPS/RPC/Faucet 정상 확인
- [x] zkLogin 작동 확인

### 스마트 컨트랙트

- [x] Pado Tokens + Faucet 재배포
- [x] DeepBook V3 재배포
- [x] Prediction Market 배포
- [x] Governance 배포

### 더미 데이터

- [x] Governance Proposals 2개 생성
- [x] Governance Polls 2개 생성
- [x] Prediction Markets 3개 생성

### 프론트엔드 연동

- [x] Pado 앱 환경변수 업데이트
- [x] Pado 앱 constants.ts 업데이트
- [x] Nasun Website 환경변수 업데이트
- [x] Nasun Website suiPackageConstants.ts 업데이트
- [x] 개발 서버 실행 및 데이터 표시 확인

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 1.7.0 | 2026-01-01 | 모니터링 설정 완료 | Claude Code |
| 1.8.0 | 2026-01-04 | V4 리셋 완료 및 컨트랙트 배포 상태 반영 | Gemini CLI |
| 2.0.0 | 2026-01-17 | **V5 리셋 완료**, 더미 데이터 생성, 프론트엔드 업데이트 | Claude Code |
