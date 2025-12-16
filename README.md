# GrantScout - 지원사업 매칭 플랫폼

[![CI](https://github.com/skerishKang/40-padiemaiscout/actions/workflows/ci.yml/badge.svg)](https://github.com/skerishKang/40-padiemaiscout/actions/workflows/ci.yml)

GrantScout(파디 스카우터)는 정부/공공기관 지원사업 공고를 수집·구조화하고, 기업 프로필/문서 분석을 바탕으로 지원 가능성과 준비사항을 빠르게 파악하도록 돕는 웹 서비스입니다.

- 대상 사용자: 중소기업, 스타트업, 지원사업 담당자
- 핵심 기능 축: 공고 수집·검색, AI 스카우터(채팅/문서), 기업 맞춤 추천, 관리자 배치/스케줄링

## 주요 기능

- 공고 목록/검색/필터/정렬
- 즐겨찾기(관심 공고 저장)
- AI 스카우터(채팅) + 문서 업로드(PDF/이미지/Word 등) 분석
- 기업 프로필 기반 AI 맞춤 추천 (Pro 이상)
- 관리자 대시보드: 기업마당/K-Startup 수집 + 상세 분석 배치 + 스케줄러 설정
- Toss Payments 기반 Pro 업그레이드

## 기술 스택

- 프론트엔드: React 19, TypeScript, Vite, Tailwind CSS, Firebase Web SDK
- 백엔드: Firebase Cloud Functions(Node.js 20), Firestore/Storage, Google Gemini
- 결제: Toss Payments

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

## 개선 / 상용화 제언(요약)

### (1) 사용성 개선

- 대시보드 리뉴얼: 검색·필터·추천·분석 내역을 한 흐름으로 재구성
- 모바일 대응 강화: 공고 탐색/추천 확인/문서 분석을 모바일에서도 빠르게 수행
- 다국어 지원: 영어/중국어 등 단계적 확장(우선은 UI 문자열 분리부터)

### (2) 검색 및 필터링 고도화

- 자연어 검색: “1억 이상 지원금”, “서울 소재 기관” 같은 문장을 필터/키워드로 변환
- 세분화 필터: 지원금 범위, 신청 기한, 기관 유형, 지역/업종 등

### (3) AI 분석 기능 확장

- 신청서 자동 작성(초안): 기업 프로필 + 공고 분석 결과를 기반으로 초안/목차 생성
- 경쟁률/트렌드 인사이트: 과거 공고/유사 공고 누적 데이터 기반 분석(장기)
- 분석 리포트 템플릿화: “지원 가능성/준비 서류/리스크 체크리스트”를 표준 출력으로 제공

### (4) 상용화/운영 관점

- 데이터 정책 정리: 기업 프로필/문서/결제 데이터의 보관·권한·이력 관리 기준 확립
- 비용 최적화: AI 호출량 제어(후보군 제한/배치 처리), Firestore 인덱스/저장 구조 점검
- 아키텍처 확장: Functions 내부 모듈화 → 트래픽 증가 시 기능별 서비스 분리 검토
- 요금제 확장: Free/Pro/Premium/Enterprise로 기능·추천량·후보군 차등(단계적 적용)

### (5) 마케팅/타겟팅(제안)

- B2B: 무료 체험 → 기업 단위 라이선스, 컨설팅사/공공기관 제휴
- B2C: 창업 커뮤니티/인큐베이터 연계, 구독형 업그레이드
- 글로벌: 다국어 + 해외 지원사업 포털 확장(지역별 데이터 소스 확보부터)
