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

## 강점(현재 잘 구축된 부분)

- 공고 수집/구조화 파이프라인: 기업마당·K-Startup 수집, 관리자 배치/스케줄러 지원, 중복 방지(소스+링크 기반 문서 ID)
- AI 스카우터/문서 분석: 채팅에서 PDF/이미지/Word 등 문서 업로드 기반 분석
- 기업 프로필 기반 AI Pick: Pro 이상에서 `checkSuitability`로 적합도 점수/사유 생성(기본 임계치 60점)
- 결제/등급: Toss Payments 결제 승인 확인 후 Pro로 자동 승급(프리미엄 등급은 확장 포인트)

## 개선 / 상용화 제언(요약)

### (1) 데이터 수집/품질 관리

- 다중 소스 전략: 공공 API(가능한 경우) + 스크래핑 + 관리자 수기 보완
- 품질 메타데이터: source, 수집일, 원문 링크, 수정 이력, 신뢰도 표시
- 검증/모니터링: 수집 성공률/중복/누락 탐지, 실패 로그(`admin_sync_logs`) 기반 운영 가시화
- 요청 제어: 기간 제한(현재 최대 7일) 유지, 과도한 요청 방지

### (2) AI 추천 투명성/정확도

- 추천 근거 노출: 현재 reason 일부 노출 → UI에서 근거를 구조화(조건 충족/미충족)
- 피드백 루프: '도움됨/아님', '지원함/미지원' 이벤트 수집으로 추천 품질 지표화
- AI/룰 혼합: 지역/기간/금액 등 필터 + AI 적합도 조합(100% AI 의존 방지)

### (3) 보안/개인정보/운영 정책

- 규칙 점검: `firestore.rules` / `storage.rules`를 기준으로 권한·role 변경·파일 접근 정책 정리
- 데이터 보관/삭제: 프로필/업로드/결제 데이터의 보관 기간 및 삭제 플로우 정의(상용화 준비)
- 민감정보 최소 수집: 사업자번호/재무 등은 필요 시 단계적으로 도입

### (4) 성능/비용/확장성

- AI 호출량 제어: 후보군 제한, 배치 분석(`analyzeScrapedGrantsBatch`) 기반으로 비용/지연 관리
- 캐싱/인덱스: Firestore 쿼리 패턴 기준 인덱스 최적화 및 캐시 전략 수립
- 비동기 파이프라인: 수집→분석→추천을 이벤트/큐 기반으로 분리(트래픽 증가 대비)

### (5) UX/UI 및 제품화

- 추천/탐색/내 분석 흐름 정리(홈=스카우터, 공고 목록, 내 분석 내역)
- 모바일 최적화 및 온보딩(프로필 작성 유도, 추천 생성 조건 안내)
- 신청 진행 관리(관심→지원 준비→제출) 상태 추적은 유료 기능으로 확장 가능

## 실행 가능한 단기 로드맵(예시)

1) 1-2개월: 수집 안정화(소스별 모니터링/검증), AI 추천 근거 UI 강화, 모바일 UX 개선
2) 2-3개월: 결제/구독 운영 고도화(구독 관리, Pro 혜택 정의), 추천 품질 지표 수집
3) 3-4개월: 관리자 품질 대시보드, 파트너/API 초안, 데이터 신뢰도/이력 노출
4) 4-6개월: 정책/약관/개인정보 처리 정비, B2B 기능(팀/권한) 검토, 확장형 요금제 설계
