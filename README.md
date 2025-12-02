# GrantScout - 지원사업 매칭 플랫폼

<div align="center">
  <img src="assets/logo.png" alt="GrantScout Logo" width="200"/>
  
  [![CI/CD Pipeline](https://github.com/yourusername/grantscouter/actions/workflows/ci.yml/badge.svg)](https://github.com/yourusername/grantscouter/actions/workflows/ci.yml)
  [![Flutter](https://img.shields.io/badge/Flutter-3.16.0-blue.svg)](https://flutter.dev)
  [![Firebase](https://img.shields.io/badge/Firebase-Latest-orange.svg)](https://firebase.google.com)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
</div>

## 📋 목차
- [개요](#개요)
- [주요 기능](#주요-기능)
- [기술 스택](#기술-스택)
- [시작하기](#시작하기)
- [프로젝트 구조](#프로젝트-구조)
- [개발 가이드](#개발-가이드)
- [배포](#배포)
- [보안](#보안)
- [기여하기](#기여하기)

## 개요

GrantScout는 기업과 개인이 정부 지원사업을 쉽게 찾고 매칭할 수 있도록 돕는 AI 기반 플랫폼입니다. Google의 Gemini API를 활용하여 지원사업 공고를 분석하고, 사용자의 프로필과 매칭하여 최적의 지원사업을 추천합니다.

### 🎯 목표
- 복잡한 지원사업 공고를 쉽게 이해할 수 있도록 구조화
- AI 기반 자동 매칭으로 적합한 지원사업 발견
- 지원 과정 전반에 대한 가이드 제공

## 주요 기능

### 1. 📄 문서 분석
- PDF 형식의 지원사업 공고 자동 분석
- 핵심 정보 추출 (지원 자격, 마감일, 지원 규모 등)
- 한글(HWP) 문서 지원 (개발 중)

### 2. 🤖 AI 매칭
- Gemini API를 활용한 지능형 매칭
- 기업 프로필과 지원사업 요구사항 비교 분석
- 적합도 점수 및 상세 분석 리포트 제공

### 3. 👤 사용자 관리
- Google 소셜 로그인
- 기업/개인 프로필 관리
- 지원 이력 추적

### 4. 🔔 알림 시스템
- 새로운 매칭 지원사업 알림
- 마감일 임박 알림
- 지원 상태 업데이트

## 기술 스택

### Frontend
- **Flutter** 3.16.0 - 크로스 플랫폼 개발
- **Provider** - 상태 관리
- **Material Design 3** - UI/UX

### Backend
- **Firebase**
  - Authentication - 사용자 인증
  - Firestore - NoSQL 데이터베이스
  - Storage - 파일 저장소
  - Cloud Functions - 서버리스 백엔드

### AI/ML
- **Google Gemini API** - 문서 분석 및 매칭
- **PDF.js** - PDF 텍스트 추출

### DevOps
- **GitHub Actions** - CI/CD
- **Firebase Hosting** - 웹 호스팅
- **Firebase App Distribution** - 앱 배포

## 시작하기

### 사전 요구사항
- Flutter SDK 3.16.0 이상
- Dart SDK 3.2.0 이상
- Firebase CLI
- Node.js 18+ (Cloud Functions)

### 설치

1. **저장소 클론**
```bash
git clone https://github.com/yourusername/grantscouter.git
cd grantscouter
```

2. **환경 변수 설정**
```bash
cp .env.example .env
# .env 파일에 필요한 API 키 입력
```

3. **Flutter 패키지 설치**
```bash
flutter pub get
```

4. **Firebase 설정**
```bash
# Firebase 프로젝트 생성 후
flutterfire configure
```

5. **개발 서버 실행**
```bash
flutter run -d chrome
```

## 프로젝트 구조

```
grantscouter/
├── lib/
│   ├── main.dart              # 앱 진입점
│   ├── screens/               # 화면 컴포넌트
│   │   ├── login_screen.dart
│   │   ├── home_screen.dart
│   │   ├── analysis_screen.dart
│   │   └── profile_screen.dart
│   ├── services/              # 비즈니스 로직
│   │   ├── auth_service.dart
│   │   ├── firestore_service.dart
│   │   └── gemini_service.dart
│   ├── models/                # 데이터 모델
│   │   ├── user.dart
│   │   ├── grant.dart
│   │   └── analysis_result.dart
│   └── widgets/               # 재사용 컴포넌트
├── functions/                 # Cloud Functions
│   ├── src/
│   │   ├── index.ts
│   │   ├── gemini/
│   │   └── pdf/
│   └── package.json
├── test/                      # 테스트 코드
├── web/                       # 웹 빌드 설정
└── firebase.json              # Firebase 설정
```

## 개발 가이드

### 코드 스타일
```bash
# 코드 포맷팅
dart format .

# 정적 분석
flutter analyze

# 테스트 실행
flutter test
```

### 브랜치 전략
- `main` - 프로덕션 배포
- `develop` - 개발 브랜치
- `feature/*` - 기능 개발
- `hotfix/*` - 긴급 수정

### 커밋 메시지 규칙
```
feat: 새로운 기능 추가
fix: 버그 수정
docs: 문서 수정
style: 코드 포맷팅
refactor: 코드 리팩토링
test: 테스트 코드
chore: 빌드 업무 수정
```

## 배포

### 웹 배포
```bash
# 프로덕션 빌드
flutter build web --release

# Firebase 호스팅 배포
firebase deploy --only hosting
```

### 모바일 배포
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## 보안

### 보안 정책
1. **인증**: 모든 API 요청은 인증 필요
2. **권한**: 사용자는 자신의 데이터만 접근 가능
3. **암호화**: 민감한 데이터는 암호화 저장
4. **검증**: 모든 입력값 검증

### 보안 규칙
- Firestore: 사용자별 데이터 격리
- Storage: 파일 크기 및 타입 제한
- Functions: Rate limiting 적용

## 기여하기

### 기여 방법
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### 이슈 리포트
- [Issue Template](.github/ISSUE_TEMPLATE.md) 사용
- 재현 가능한 단계 포함
- 스크린샷 첨부 (가능한 경우)

## 라이선스

MIT License - 자세한 내용은 [LICENSE](LICENSE) 파일 참조

## 연락처

- 프로젝트 관리자: [이름](mailto:email@example.com)
- 프로젝트 링크: [https://github.com/yourusername/grantscouter](https://github.com/yourusername/grantscouter)

---

<div align="center">
  Made with ❤️ by GrantScout Team
</div>