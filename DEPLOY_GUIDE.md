# GrantScout 전역 배포 시스템 가이드

## 🎯 개요
GrantScout 프로젝트에서 "배포", "업로드" 등 일반적인 요청을 자동으로 GitHub과 Firebase에 배포하는 전역 시스템입니다.

## 🚀 사용법

### 기본 배포 (GitHub + Firebase)
```powershell
# 기존 방법
.\deploy.ps1

# 새로운 전역 방법
.\global_deploy.ps1 --both
```

### 특정 대상만 배포
```powershell
# GitHub만
.\global_deploy.ps1 --github-only

# Firebase만  
.\global_deploy.ps1 --firebase-only
```

### 정책 확인
```powershell
.\global_deploy.ps1 --check
```

## 🤖 자동 인식 시스템

이 시스템은 다음과 같은 키워드들을 자동으로 인식합니다:

### 키워드별 자동 행동
| 키워드 | 자동 행동 | 설명 |
|---------|-----------|------|
| `배포`, `deploy` | GitHub + Firebase | 기본 배포 |
| `업로드`, `upload` | GitHub + Firebase | 소스코드 + 라이브 배포 |
| `커밋`, `commit` | GitHub만 | 코드만 GitHub에 |
| `라이브`, `live`, `실시간` | Firebase만 | 라이브 환경에만 |
| `빌드`, `build` | Firebase만 | 빌드 후 배포 |
| `푸시`, `push` | GitHub만 | 코드 동기화 |

### 파일 유형별 자동 배포
```json
{
  "frontend": ["grantscout_web/src/**", "*.tsx", "*.css"] → GitHub + Firebase
  "backend": ["functions/**", "*.js"] → GitHub + Firebase  
  "config": ["*.json", "deploy.ps1"] → GitHub + Firebase
}
```

## 📁 파일 구조
```
.
├── deploy_rules.json      # 배포 정책 정의
├── global_deploy.ps1      # 전역 배포 관리자
├── deploy.ps1            # 기존 배포 스크립트
└── grantscout_web/       # 프론트엔드 프로젝트
    ├── src/             # React 소스코드
    ├── dist/            # 빌드 결과물
    └── package.json     # 의존성
```

## ⚙️ 정책 설정

### deploy_rules.json 구조
- **projectName**: 프로젝트명
- **deploymentRules**: 배포 규칙
  - **github**: GitHub 관련 설정
  - **firebase**: Firebase 관련 설정
- **fileTypeRules**: 파일 유형별 배포 대상
- **urls**: 최종 배포 URL

## 🎮 고급 기능

### 파일 패턴 매칭
```json
{
  "include": [
    "src/**/*.{tsx,ts,js,jsx}",
    "public/**/*",
    "*.json",
    "*.md"
  ],
  "exclude": [
    "node_modules/**",
    "dist/**",
    ".git/**"
  ]
}
```

### 조건부 배포
- 변경사항이 있을 때만 GitHub 푸시
- dist 폴더가 없을 때 자동 빌드
- 배포 실패 시 롤백 알림

## 🔧 트러블슈팅

### 일반적인 오류
1. **Git 연결 오류**: SSH 키 확인 필요
2. **Firebase 인증**: `npx firebase-tools login`
3. **빌드 실패**: dependencies 확인

### 로그 확인
```powershell
# 상세 로그 출력
.\global_deploy.ps1 --both --verbose
```

## 🎯 향후 개선 계획

- [ ] CI/CD 파이프라인 통합
- [ ]Slack/Discord 알림 연동
- [ ]배포 히스토리 추적
- [ ]자동 테스트 실행
- [ ]멀티 브랜치 지원