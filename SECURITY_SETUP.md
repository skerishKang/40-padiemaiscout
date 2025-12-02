# 🔐 GrantScout 보안 설정 가이드

## 🚨 중요: Firebase 및 Google OAuth 설정

이 프로젝트는 Flutter 앱으로 Firebase와 Google OAuth를 사용합니다. 보안을 위해 다음 단계를 따라주세요.

## 📋 필수 설정 파일들

### 1. Android용 Google Services 설정
**파일 위치**: `grantscout_app/android/app/google-services.json`

```json
{
  "project_info": {
    "project_number": "YOUR_PROJECT_NUMBER",
    "project_id": "YOUR_PROJECT_ID",
    "storage_bucket": "YOUR_PROJECT_ID.appspot.com"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "YOUR_ANDROID_APP_ID",
        "android_client_info": {
          "package_name": "com.example.grantscout"
        }
      },
      "oauth_client": [
        {
          "client_id": "YOUR_ANDROID_CLIENT_ID",
          "client_type": 1,
          "android_info": {
            "package_name": "com.example.grantscout",
            "certificate_hash": "YOUR_SHA1_HASH"
          }
        }
      ],
      "api_key": [
        {
          "current_key": "YOUR_ANDROID_API_KEY"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": [
            {
              "client_id": "YOUR_WEB_CLIENT_ID",
              "client_type": 3
            }
          ]
        }
      }
    }
  ],
  "configuration_version": "1"
}
```

### 2. iOS용 설정 (필요시)
**파일 위치**: `grantscout_app/ios/Runner/GoogleService-Info.plist`

### 3. 웹/데스크톱용 OAuth 설정
**파일 위치**: `client_secret.json`

## 🛠️ Firebase 프로젝트 설정

### 1. Firebase Console에서 새 프로젝트 생성
1. [Firebase Console](https://console.firebase.google.com/)에 접속
2. "프로젝트 추가" 클릭
3. 프로젝트 이름: `grantscout-app` (또는 원하는 이름)
4. Google Analytics 활성화 (선택사항)

### 2. Android 앱 추가
1. Android 아이콘 클릭
2. 패키지 이름: `com.example.grantscout`
3. 앱 닉네임: `GrantScout`
4. SHA-1 인증서 지문 추가:
   ```bash
   keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore
   ```
5. `google-services.json` 다운로드하여 `android/app/` 폴더에 저장

### 3. Authentication 설정
1. Firebase Console > Authentication > Sign-in method
2. Google 제공업체 활성화
3. 프로젝트 공개용 이름 설정
4. 지원 이메일 추가

### 4. Firestore Database 설정
1. Firebase Console > Firestore Database
2. 데이터베이스 만들기
3. 보안 규칙 설정:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // 인증된 사용자만 자신의 데이터에 접근
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
       
       // 공개 지원금 정보는 모든 사용자가 읽기 가능
       match /grants/{grantId} {
         allow read: if true;
         allow write: if request.auth != null;
       }
     }
   }
   ```

### 5. Firebase Storage 설정
1. Firebase Console > Storage
2. 시작하기 클릭
3. 보안 규칙 설정:
   ```javascript
   rules_version = '2';
   service firebase.storage {
     match /b/{bucket}/o {
       match /users/{userId}/{allPaths=**} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
     }
   }
   ```

## 🔑 Google OAuth 설정

### 1. Google Cloud Console 설정
1. [Google Cloud Console](https://console.cloud.google.com/)에 접속
2. Firebase 프로젝트와 동일한 프로젝트 선택
3. API 및 서비스 > 사용자 인증 정보

### 2. OAuth 2.0 클라이언트 ID 생성
1. "사용자 인증 정보 만들기" > "OAuth 클라이언트 ID"
2. 애플리케이션 유형: "데스크톱 애플리케이션"
3. 이름: "GrantScout Desktop"
4. 생성 후 JSON 파일 다운로드
5. 파일명을 `client_secret.json`으로 변경

### 3. 승인된 리디렉션 URI 추가
- `http://localhost:8080`
- `http://localhost:3000`
- `http://127.0.0.1:8080`

## 📱 Flutter 앱 설정

### 1. 의존성 추가 확인
`pubspec.yaml`에서 다음 패키지들이 포함되어 있는지 확인:

```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  firebase_storage: ^11.5.6
  google_sign_in: ^6.1.6
```

### 2. Firebase 초기화
`lib/main.dart`에서 Firebase 초기화:

```dart
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}
```

### 3. Android 설정
`android/app/build.gradle`에 추가:

```gradle
dependencies {
    implementation 'com.google.firebase:firebase-auth'
    implementation 'com.google.android.gms:play-services-auth'
}
```

## 🔒 보안 체크리스트

### ✅ 완료해야 할 항목들
- [ ] Firebase 프로젝트 생성 및 설정
- [ ] `google-services.json` 파일 배치
- [ ] `client_secret.json` 파일 생성
- [ ] `.env` 파일에 환경변수 설정
- [ ] `.gitignore`에 민감한 파일들 추가
- [ ] Firebase 보안 규칙 설정
- [ ] Google OAuth 리디렉션 URI 설정
- [ ] 프로덕션용 SHA-1 인증서 등록

### ⚠️ 주의사항
1. **절대로 실제 인증 파일을 Git에 커밋하지 마세요**
2. 개발용과 프로덕션용 Firebase 프로젝트를 분리하세요
3. 정기적으로 API 키를 로테이션하세요
4. Firebase 보안 규칙을 엄격하게 설정하세요

## 🧪 테스트

### Firebase 연결 테스트
```dart
void testFirebaseConnection() async {
  try {
    await Firebase.initializeApp();
    print('✅ Firebase 연결 성공');
  } catch (e) {
    print('❌ Firebase 연결 실패: $e');
  }
}
```

### Google 로그인 테스트
```dart
void testGoogleSignIn() async {
  try {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    final GoogleSignInAccount? account = await googleSignIn.signIn();
    
    if (account != null) {
      print('✅ Google 로그인 성공: ${account.email}');
    }
  } catch (e) {
    print('❌ Google 로그인 실패: $e');
  }
}
```

## 📞 문제 해결

### 일반적인 오류들

1. **`google-services.json` 파일을 찾을 수 없음**
   - 파일이 `android/app/` 디렉토리에 있는지 확인
   - 파일명이 정확한지 확인

2. **SHA-1 인증서 오류**
   - 디버그/릴리즈 인증서를 모두 Firebase에 등록했는지 확인
   - 새 인증서 생성 후 Firebase에 업데이트

3. **OAuth 클라이언트 오류**
   - 리디렉션 URI가 정확히 설정되었는지 확인
   - 클라이언트 ID가 올바른지 확인

## 🚀 배포 전 체크리스트

- [ ] 프로덕션 Firebase 프로젝트 설정
- [ ] 프로덕션용 인증서로 SHA-1 업데이트
- [ ] Google Play Console에서 SHA-1 확인
- [ ] Firebase 보안 규칙 최종 검토
- [ ] API 사용량 제한 설정
- [ ] 모니터링 및 알림 설정

---

**보안은 선택이 아닌 필수입니다!** 🛡️