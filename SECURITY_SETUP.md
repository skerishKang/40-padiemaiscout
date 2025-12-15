# GrantScout 설정 가이드

이 저장소는 React(Vite) 프론트엔드(`grantscout_web`)와 Firebase Cloud Functions(`functions`)로 구성됩니다.

## 구성

- `grantscout_web/`: React 19 + TypeScript + Vite
- `functions/`: Firebase Cloud Functions (Node.js 20)
- `firestore.rules`, `storage.rules`: 보안 규칙

## Firebase 설정

### Authentication

- Email/Password
- Google

### Firestore / Storage

- Firestore 규칙: `firestore.rules`
- Storage 규칙: `storage.rules`

배포 예시:

```bash
firebase deploy --only firestore:rules
firebase deploy --only storage
```

## 환경 변수

이 프로젝트는 프론트와 Functions가 각각 별도의 `.env`를 사용합니다.

- `grantscout_web/.env`: Vite 환경 변수
- `functions/.env`: Cloud Functions 환경 변수

샘플은 저장소 루트의 `.env.example`를 참고하세요.
