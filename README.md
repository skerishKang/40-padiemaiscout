# GrantScout - 지원사업 매칭 플랫폼

[![CI](https://github.com/skerishKang/40-padiemaiscout/actions/workflows/ci.yml/badge.svg)](https://github.com/skerishKang/40-padiemaiscout/actions/workflows/ci.yml)

GrantScout(파디 스카우터)는 정부/공공기관 지원사업 공고를 수집하고, 기업 프로필 기반으로 AI 추천과 문서 분석을 제공하는 웹 서비스입니다.

## 주요 기능

- 공고 목록/검색/필터/정렬
- AI 스카우터(채팅) + 파일 업로드(PDF/이미지/문서) 분석
- 기업 프로필 기반 AI 맞춤 추천 (Pro/Premium)
- 관리자 대시보드: 수집/분석 배치 실행
- Toss Payments 기반 Pro 업그레이드

## 기술 스택

- 프론트엔드: React 19, TypeScript, Vite, Tailwind CSS, Firebase Web SDK
- 백엔드: Firebase Cloud Functions(Node.js 20), Firestore/Storage, Google Gemini

## 프로젝트 구조

- grantscout_web/
- functions/
- firestore.rules / storage.rules
- firebase.json / netlify.toml
- deploy.ps1 / global_deploy.ps1

## 개발 / 빌드

### 프론트엔드

```bash
npm --prefix grantscout_web ci
npm --prefix grantscout_web run dev
npm --prefix grantscout_web run build
```

### Cloud Functions

```bash
npm --prefix functions ci
```

## 환경 변수

예시 템플릿은 루트 `.env.example`를 참고하세요.

- `grantscout_web/.env`
  - `VITE_FIREBASE_*`
  - `VITE_TOSS_CLIENT_KEY`
- `functions/.env`
  - `GEMINI_API_KEYS`
  - `GEMINI_ALLOWED_MODELS`(선택)
  - `TOSS_SECRET_KEY`
