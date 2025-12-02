# withgoogle.md

## 1차 회의: 프로젝트 기반 인프라 설정

### [구글 개발팀 제안]
- Firebase 콘솔에서 프로젝트(grantscout-dev) 생성
- Authentication(Google), Firestore, Storage, (선택) Cloud Functions 활성화
- Flutter 개발 환경 준비 및 Flutter 프로젝트 생성
- Firebase CLI로 Flutter와 연동
- main.dart에서 Firebase 초기화
- 이 기반 작업이 모든 기능의 토대이므로, 확실히 해둘 것
- 1번(Firebase 프로젝트 생성)은 이미 완료

### [실행팀(커서팀) 피드백 및 실행 계획]
- 1번(Firebase 프로젝트 생성)은 이미 완료된 상태임을 확인
- 즉시 실행할 다음 단계:
  1. Firebase Authentication(Google 로그인) 활성화
  2. Firestore Database 생성(테스트 모드, 추후 보안 강화)
  3. Cloud Storage 버킷 설정
  4. Flutter 개발 환경 점검(Flutter SDK, IDE, 플러그인)
  5. Flutter 프로젝트 생성 및 firebase_core 등 패키지 추가
  6. Firebase CLI로 Flutter 프로젝트와 Firebase 연동
  7. main.dart에 Firebase 초기화 코드 추가
- 실행팀 의견:
  - 이 순서가 매우 합리적이며, 실제 개발 효율을 높임
  - Authentication, Firestore, Storage는 필수이므로 반드시 활성화
  - Cloud Functions는 추후 필요 시 설정
  - Flutter와 Firebase 연동이 완료되면, Google 로그인 UI/UX 논의로 바로 넘어갈 수 있음
  - 각 단계별로 진행상황을 docs/project_plan.md에도 기록 예정 

## 2차 회의: Firebase 설정 완료 및 Flutter 연동 계획

### [구글 개발팀 공식 안내]

#### 1. 지금까지 완료된 Firebase 설정 작업 요약
- Firebase 프로젝트 'grantscout' 생성 완료
- 핵심 서비스 활성화 및 기본 설정 완료
  - Authentication: Google 로그인 제공업체 활성화(앱 레벨 설정은 추후)
  - Firestore Database: 테스트 모드로 생성, 리전 설정(보안 규칙 추후 강화)
  - Cloud Storage: 기본 스토리지 버킷 설정(보안 규칙 추후 강화)
- 결론: GrantScout 앱 운영에 필요한 기본 Firebase 백엔드 인프라 준비 완료

#### 2. 앞으로 수행할 작업 (Flutter 연동)
- Flutter 개발 환경 점검(Flutter SDK, IDE, 플러그인)
- Flutter 프로젝트 생성(`flutter create grantscout_app`)
- pubspec.yaml에 필수 Firebase 패키지 추가 및 설치
  - firebase_core, firebase_auth, cloud_firestore, firebase_storage, google_sign_in
- Firebase CLI 연동 및 설정 파일 생성(`flutterfire configure`)
- main.dart에 Firebase 초기화 코드 추가
- 앱 실행 및 정상 동작 확인

#### 3. 다음 단계 예고
- Flutter 연동 완료 후 Google 로그인 기능 구현 예정
- 로그인 화면 UI 설계 및 로그인 로직 개발 예정 

## 3차 회의: Firebase 연동 1차 완료 보고 및 Google 로그인 기능 제안

### [커서팀 보고]
GrantScout Flutter 앱과 Firebase 연동 1차 작업이 성공적으로 완료되었습니다.
- Flutter 프로젝트(grantscout_app) 생성 및 환경 세팅
- pubspec.yaml에 firebase_core, firebase_auth, cloud_firestore, firebase_storage, google_sign_in 등 필수 패키지 추가 및 설치
- Firebase CLI, FlutterFire CLI, 환경 변수 문제 해결
- Firebase 프로젝트(grantscout)와 Flutter 앱 연동(firestore configure)
- main.dart에 Firebase 초기화 코드 적용
- 크롬(웹)에서 "Firebase 연동 완료!" 화면 정상 출력 확인
- 환경 변수 문제, Windows 데스크탑 빌드 오류 등 이슈 발생 → 모두 해결, 웹 개발 우선 결정

### [구글 개발팀 피드백 및 Google 로그인 기능 제안]
- 꼼꼼한 진행 상황 및 이슈 해결 과정에 감사, 성공적인 연동 완료 축하
- 공식 회신 내용 명확, 구글팀 내부에도 공유 예정
- withgoogle.md 등 공식 문서 기록 권장

#### Google 로그인 기능 구현 제안
- **UI 구성**: 로그인 상태에 따라 다른 화면(로그인 전: 버튼, 로그인 후: 사용자 정보/대시보드) 분기, StreamBuilder와 FirebaseAuth.instance.authStateChanges() 활용
- **로그인 로직**: google_sign_in 패키지로 Google 계정 인증 → firebase_auth의 signInWithCredential로 Firebase 로그인, try-catch로 예외 처리, 로딩 상태 표시
- **상태 관리**: User 객체 전역 접근 필요시 Provider 등 상태 관리 도입 고려, 초기에는 FirebaseAuth.instance.currentUser 직접 접근도 가능
- **플랫폼별 설정**: 웹은 승인된 도메인 등록 확인, 모바일 빌드 시 Android/iOS 별도 설정 필요
- **제안**: 우선 간단한 로그인 버튼 및 Google 로그인 플로우 구현부터 시작, 이후 UI 분기/상태 관리 점진적 개선

- 커서팀에서 Google 로그인 기능 구현 중 궁금한 점이 있으면 언제든 문의 바랍니다. 구글팀은 계속 적극적으로 지원 예정 

---

2024-05-06
- 회사 프로필 입력 화면 임시 비활성화(로그인 후 바로 이동하지 않음)
- 지원사업 분석 기능 1단계(파일 업로드, Storage 업로드, Cloud Functions, Gemini API 연동, Firestore 저장) 개발 준비 시작
- 프로젝트 우선순위 변경: 지원사업 분석 > 회사 프로필 관리
- 실제 코드(main.dart)에서 ProfileScreen 네비게이션 주석 처리
- 다음 단계: 파일 업로드 UI 및 Storage 연동 구현 예정 

## GrantScout PDF 텍스트 추출 기능 장애 분석 및 해결 과정 (withgoogle.md)

### 1. 문제 현상 요약
- Firebase Functions에서 PDF 파일의 텍스트를 추출해 Firestore에 저장하는 기능이 정상 동작하지 않음.
- 주요 증상:
  - `pdf-parse` 사용 시 일부 PDF에서 텍스트 추출이 거의 되지 않음(빈 문자열, 짧은 텍스트 등).
  - `pdfjs-dist`로 교체 후, 모듈 로딩/환경 호환성 문제로 함수 실행 자체가 실패하거나, 텍스트 추출이 실패함.

### 2. 주요 오류 및 로그
- `MODULE_NOT_FOUND: Cannot find module 'pdfjs-dist/legacy/build/pdf.js'`
- `ReferenceError: DOMMatrix is not defined`
- `TypeError: Cannot read properties of undefined (reading 'getDocument')`
- `Cannot polyfill Path2D, rendering may be broken`
- `Cannot access the require function: TypeError: process.getBuiltinModule is not a function`

### 3. 원인 분석
- pdfjs-dist 최신 버전은 Node.js 환경에서 브라우저 API(DOMMatrix, Path2D 등)와 워커, require 등 다양한 환경 의존성이 있음.
- node-canvas 등 polyfill이 필요하지만, 자동 적용되지 않거나, import/require 방식이 맞지 않으면 여전히 오류 발생.
- pdfjs-dist의 import 경로 및 방식이 Node.js/Firebase Functions 환경에 따라 달라야 함.

### 4. 시도한 해결책 및 결과
1. **pdf-parse → pdfjs-dist로 교체**  
   - 모듈 로딩 오류(MODULE_NOT_FOUND) 발생 → npm install, node_modules 정리, 경로 확인 등으로 해결
2. **pdfjs-dist/legacy/build/pdf.mjs 동적 import**  
   - getDocument가 undefined, import 관련 linter 경고 등 발생
3. **node-canvas 설치 및 global polyfill(DOMMatrix, ImageData, Path2D)**  
   - DOMMatrix 오류는 해결, 그러나 getDocument undefined 오류 발생
4. **require('pdfjs-dist') vs require('pdfjs-dist/legacy/build/pdf.js')**  
   - require('pdfjs-dist')는 getDocument가 undefined
   - require('pdfjs-dist/legacy/build/pdf.js')로 해야 getDocument가 정상적으로 노출됨
5. **워커 경로 설정, global.document.createElement('canvas') 등 추가 polyfill**  
   - 필요시 추가 적용 가능

### 5. 최종 적용해야 할 코드(핵심 부분)
```js
// 상단에 추가
const { DOMMatrix, ImageData, Path2D } = require("canvas");
global.DOMMatrix = DOMMatrix;
global.ImageData = ImageData;
global.Path2D = Path2D;

// PDF.js는 반드시 legacy 경로로 require
const pdfjsLib = require("pdfjs-dist/legacy/build/pdf.js");

// (필요시) 워커 경로 설정
// pdfjsLib.GlobalWorkerOptions.workerSrc = require.resolve('pdfjs-dist/legacy/build/pdf.worker.js');
```
- PDF 추출부:
```js
const data = new Uint8Array(fs.readFileSync(tempFilePath));
const pdf = await pdfjsLib.getDocument({ data }).promise;
let textContent = "";
for (let i = 1; i <= pdf.numPages; i++) {
  const page = await pdf.getPage(i);
  const content = await page.getTextContent();
  const pageText = content.items.map((item) => item.str).join(" ");
  textContent += pageText + "\n";
}
```

### 6. 추가 권고 및 참고사항
- pdfjs-dist, canvas, Node.js, Firebase Functions 버전 호환성에 주의
- 최신 버전에서 문제가 지속될 경우, pdfjs-dist 2.x/3.x 등 안정화된 구버전 테스트 권장
- Functions 에뮬레이터와 실제 GCP Functions 환경의 차이도 염두에 둘 것 

## 2024-06 최신 협업 내역 및 결정사항
- 커서팀은 PDF 업로드, Firestore 저장, Gemini API(2.0 Flash) 호출, 구조화 정보 추출, analysisResult JSON 저장, UI 표시까지 전체 파이프라인을 완성함
- 구글팀은 정책/보안 우려, PoC 목표, API 키 관리 등 다양한 의견을 제시했고, 커서팀은 실시간으로 이를 반영하며 기술적 지원에 집중하도록 협의
- Gemini 모델명을 최신화(2.0 Flash), Python 스크립트로 실제 사용 가능한 모델 목록 확인, API 키 순환 구조 적용 등 자동화
- 환경변수, 포트, 패키지 등 각종 환경 이슈를 실시간으로 자동 감지 및 해결하는 구조로 개선
- Cloud Function 프롬프트 및 Firestore 저장 구조를 구조화 JSON으로 수정, Flutter UI에서 analysisResult를 표 형태로 표시하는 방향으로 결정 

- 모든 코드/환경 수정은 묻지 않고 바로 적용, 변경사항은 즉시 문서(project_plan.md, withgoogle.md)에 기록
- 추가 기능, 확장, 최적화, UI 개선 등 요청 시 즉시 반영 가능한 체계 구축
- 테스트 및 검증은 MCP 도구를 활용하여 브라우저에서 각 메뉴를 클릭하고, 전체 파이프라인을 실제로 검증하는 방식으로 진행
- 로그 정보는 logs 폴더에 쌓이도록 개발, 오류 발생 시 logs 폴더의 내용을 통해 원인 분석
- 자바스크립트 작성 시 이벤트마다 콘솔에 로그를 남겨, 디버깅 및 오류 추적이 용이하도록 함
- 구글팀의 피드백, 결정사항, 실행팀의 대응 및 의견은 withgoogle.md에 상세히 기록하여 협업의 투명성과 신속성을 높임 

### [구글 개발팀(실행팀) 답변 및 실행 계획]
- 커서팀의 대화형 시나리오 및 적합성 분석 기능 제안은 PoC의 가치를 높이는 훌륭한 방향임을 확인, 기술적으로 충분히 실현 가능함을 안내
- Gemini API의 미세 조정보다, 시스템(Flutter+Cloud Function+Firestore) 아키텍처와 프롬프트 설계/개선이 핵심임을 강조
- 1단계: PDF 업로드 시 핵심 정보 추출 및 Firestore 저장, Flutter에서 표 형태로 표시(현재 구현 중, 곧 완성)
- 2단계: 회사 정보 관리 기능 추가(Flutter/Firestore), '적합성 분석' Cloud Function(checkSuitability) 신설, Gemini 시스템 프롬프트 활용해 분석 결과 반환
- 3단계: 적합성 점수화(명확한 기준/가중치 정의, 프롬프트 개선, 결과 검증 및 튜닝)로 확장
- 각 단계별로 완성도와 안정성을 높이며, 실험과 반복적 개선을 통해 프롬프트와 분석 품질을 지속적으로 향상시킬 계획

- 회사 정보 관리: Flutter 앱에 회사 정보 입력/수정 UI 및 Firestore 저장 구조 설계, 사용자별 정보 관리 기능 구현
- checkSuitability 함수: 회사 정보와 PDF 분석 결과를 받아 Gemini API(system prompt 활용)로 적합성 분석, 결과를 Firestore에 저장 및 Flutter에 반환
- 시스템 프롬프트 예시: "너는 지원사업 공고와 회사 정보를 비교하여 적합성을 분석하는 전문가야. 지원 대상, 시기, 금액, 제외 대상 등 기준을 중점적으로 평가하고, 0~100점의 적합성 점수를 매겨줘."
- 적합성 점수화: 평가 기준/가중치 정의, 프롬프트에 명확히 반영, Gemini 결과 검증 및 반복적 튜닝
- 각 단계별로 UI/UX, 데이터 흐름, 프롬프트, 분석 결과의 품질을 실험과 피드백을 통해 지속적으로 개선
- 모든 변경 및 논의 결과는 project_plan.md, withgoogle.md에 즉시 기록하여 협업의 투명성과 실행력을 강화

## 2024-06-XX (회사 정보 관리 UI/UX 및 적합성 분석 기능 개선)

### [구글팀 제안 및 피드백]
- 회사 정보 관리(ProfileScreen) 입력 폼의 UI/UX 완성도가 부족하다고 지적, 모든 TextFormField에 hintText, labelText, floatingLabelBehavior: always 적용을 강력히 요구.
- 설립일 입력 형식은 YYYYMMDD 8자리 숫자로 통일, validator 및 hintText도 이에 맞게 수정 지시.
- Firestore 연동 시 데이터 불러오기/저장, validation, 오류 처리, 로딩 상태 관리 등 코드 품질을 높일 것.
- 적합성 분석(checkSuitability) Cloud Function의 프롬프트는 역할, 입력, 평가 기준, 점수 산정, 결과 형식, 주의사항을 명확히 포함하도록 구체적으로 설계할 것.
- 프롬프트 내 JSON 데이터는 [지원사업 공고 분석 결과 JSON]\n{...}\n[회사 정보 JSON]\n{...} 형식으로 삽입할 것.
- 배포 및 테스트 방법, 포트 충돌(8080) 해결법, 테스트 계정 안내 등 문서화할 것.

### [커서팀 실행 및 개선 내역]
- ProfileScreen 내 모든 TextFormField에 hintText(입력 예시/가이드), labelText(필드명), floatingLabelBehavior: always를 적용.
- 설립일 입력 형식을 YYYYMMDD 8자리 숫자로 변경, validator 및 hintText를 수정.
- Firestore 연동: 프로필 데이터 불러오기/저장, validation, 오류 처리, 로딩 상태 관리 등 코드 품질을 개선.
- 누락된 필드(사업자번호 등)는 추후 개선 과제로 남김.
- 적합성 분석(checkSuitability) Cloud Function 프롬프트를 구글팀 예시에 맞춰 구체적으로 설계, 템플릿 리터럴 대신 문자열 연결 방식으로 문법 오류 해결.
- functions/index.js의 checkSuitability 함수 코드 개선 및 배포 완료.
- Firebase Functions 배포 및 테스트 방법, 포트 충돌(8080) 해결법, 테스트 계정 안내 등 문서화.
- 전체 파이프라인(프로필 입력→공고 분석→적합성 분석→결과 표시) 정상 동작 확인.

### [향후 계획 및 논의]
- 개선된 ProfileScreen UI의 실제 동작을 MCP로 테스트(초기 상태, 입력, 저장 등)
- 스크린샷(입력 전 hintText가 보이는 상태) 첨부 및 보고
- 구글팀 피드백 반영 여부 확인 및 추가 개선사항 논의
- 적합성 분석 결과의 품질 검증 및 프롬프트/로직 추가 개선
- 누락된 회사 정보 필드(사업자번호 등) 추가 및 UI/DB 확장

### [중요 사항]
- 모든 변경 및 논의 결과는 project_plan.md, withgoogle.md에 즉시 기록
- 사용자 입력 편의성, 직관적 안내, 실시간 피드백이 핵심
- 테스트 및 검증은 MCP 도구를 활용하여 실제 브라우저에서 각 메뉴를 클릭하고, 전체 파이프라인을 검증하는 방식으로 진행
- 로그 정보는 logs 폴더에 쌓이도록 개발, 오류 발생 시 logs 폴더의 내용을 통해 원인 분석
- 자바스크립트 작성 시 이벤트마다 콘솔에 로그를 남겨, 디버깅 및 오류 추적이 용이하도록 함

## 2024-06-XX (한글 문서 구조화 데이터 추출 검토)

### [커서팀 제안]
1. 한글 문서의 핵심 가치
   - 강력한 편집 기능 (표, 이미지, 수식 등)
   - 서식 및 레이아웃 관리
   - 복잡한 문서 구조 지원

2. 현재 한계
   - 단순 텍스트 추출만 가능
   - 서식/레이아웃 정보 손실
   - 표/이미지 등 복잡한 요소 처리 불가

3. 개선 방향
   - 구조화된 데이터 추출
   - 표 데이터 처리
   - 이미지/그림 처리
   - 서식 정보 보존

### [구글팀 검토 요청사항]
1. 구조화된 데이터 추출 가능성
2. 표/이미지 처리 방안
3. 서식 정보 보존 방법