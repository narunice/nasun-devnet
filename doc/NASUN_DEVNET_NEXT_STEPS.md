# Nasun Devnet 다음 단계 계획서

**Version**: 1.8.0
**Created**: 2025-12-13
**Updated**: 2026-01-04
**Author**: Claude Code
**Status**: V4 리셋 완료, 스마트 컨트랙트 배포 완료, 서비스 연동 진행 중
**Prerequisites**: Nasun Devnet V4 운영 중 (Sui mainnet v1.62.1 기반)

---

## 목차

1. [개요](#1-개요)
2. [V4 리셋 (완료)](#2-v4-리셋-완료)
3. [Phase 12: 스마트 컨트랙트 재배포 (완료)](#3-phase-12-스마트-컨트랙트-재배포-완료)
4. [Phase 13: Pado 서비스 정상화 (진행 중)](#4-phase-13-pado-서비스-정상화-진행-중)
5. [Phase 14: Nasun Website 설정 (신규)](#5-phase-14-nasun-website-설정-신규)
6. [체크리스트](#6-체크리스트)

---

## 1. 개요

### 1.1 현재 상태 (2026-01-04 V4 리셋 완료)

| 항목 | 값 |
|------|-----|
| **Network** | Nasun Devnet |
| **Chain ID** | `4c879694` (2026-01-02 V4 리셋) |
| **Fork Source** | Sui mainnet v1.62.1 (zkLogin fix) |
| **RPC Endpoint (HTTPS)** | `https://rpc.devnet.nasun.io` |
| **Status** | ✅ V4 운영 중, 컨트랙트 배포 완료 |

### 1.2 진행 상황 요약

- **V4 리셋**: zkLogin 문제 해결을 위한 노드 다운그레이드(v1.62.1) 및 제네시스 초기화 완료.
- **컨트랙트**: Pado 운영에 필요한 DeepBook V3, Tokens, Pools 등 핵심 컨트랙트 배포 완료.
- **잔여 작업**: Frontend 환경 변수 동기화, Nasun Website용 더미 데이터(거버넌스 제안) 생성 필요.

---

## 2. V4 리셋 (완료) ✅

- **Chain ID**: `4c879694`
- **목적**: `prover-dev` 키 불일치로 인한 zkLogin 서명 실패 해결.
- **결과**: 노드 정상 가동, zkLogin 서명 검증 성공 확인.

---

## 3. Phase 12: 스마트 컨트랙트 재배포 (완료) ✅

V4 리셋 후 삭제된 컨트랙트들을 모두 재배포했습니다.

### 3.1 배포된 컨트랙트 목록

| 컨트랙트 | 상태 | 비고 |
|----------|------|------|
| **Pado Tokens** | ✅ 완료 | NBTC, NUSDC |
| **Faucet** | ✅ 완료 | Token Faucet, Claim Record |
| **DeepBook V3** | ✅ 완료 | CLOB 엔진, Registry, AdminCap |
| **Trading Pools** | ✅ 완료 | NBTC/NUSDC, NASUN/NUSDC |
| **Prediction Market** | ✅ 완료 | 바이너리 옵션 시장 |

---

## 4. Phase 13: Pado 서비스 정상화 (진행 중) 🚧

배포된 컨트랙트 정보를 프론트엔드 및 지갑 설정에 반영해야 합니다.

### 4.1 환경 변수 업데이트 (Required)

새로 배포된 Package ID와 Shared Object ID를 다음 파일들에 업데이트해야 합니다:

- `apps/pado/.env.development`
- `apps/pado/.env.staging`
- `packages/wallet/src/config/tokens.ts`

### 4.2 검증 테스트

1. **Faucet**: NBTC, NUSDC 토큰 수령 확인
2. **Swap**: DeepBook을 통한 토큰 교환 테스트
3. **zkLogin**: 구글 로그인을 통한 트랜잭션 서명 테스트

---

## 5. Phase 14: Nasun Website 설정 (신규) 📋

Nasun 공식 웹사이트의 거버넌스 기능을 테스트하기 위한 초기 데이터를 생성해야 합니다.

### 5.1 목표
- 거버넌스 대시보드에 표시될 더미 프로포절(Proposals) 생성.
- 투표 기능 테스트를 위한 환경 조성.

### 5.2 작업 내용
- [ ] 더미 프로포절 생성 스크립트 작성 또는 CLI 실행.
- [ ] 다양한 상태(진행 중, 종료됨, 통과됨 등)의 프로포절 데이터 주입.

---

## 6. 체크리스트

### V4 리셋 및 복구
- [x] Sui v1.62.1 빌드 및 배포
- [x] Genesis 재생성 (Chain ID: `4c879694`)
- [x] 노드 서비스 재시작 및 동기화
- [x] HTTPS/RPC/Faucet 정상 확인

### 스마트 컨트랙트 (Pado)
- [x] Pado Tokens 재배포
- [x] DeepBook V3 재배포
- [x] Trading Pools 재생성
- [x] Prediction Market 배포

### 서비스 연동 및 기타
- [ ] Pado Frontend 환경변수 업데이트
- [ ] zkLogin 최종 검증
- [ ] Nasun Website 더미 프로포절 생성

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 1.7.0 | 2026-01-01 | 모니터링 설정 완료 | Claude Code |
| 1.8.0 | 2026-01-04 | V4 리셋 완료 및 컨트랙트 배포 상태 반영 | Gemini CLI |