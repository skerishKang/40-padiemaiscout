# GrantScout 프로젝트 전용 Firebase 배포 스크립트
# 사용 방법 예시:
#   .\deploy.ps1 -Token "1//...FirebaseCIToken..."
# 또는 PowerShell 세션에서 먼저:
#   $env:FIREBASE_TOKEN = "1//...FirebaseCIToken..."
#   .\deploy.ps1

param(
    [string]$Token = $env:FIREBASE_TOKEN
)

if (-not $Token) {
    Write-Host "FIREBASE_TOKEN 이 설정되어 있지 않습니다. Firebase CI 토큰을 입력해 주세요." -ForegroundColor Yellow
    $Token = Read-Host "Firebase CI Token"
}

$env:FIREBASE_TOKEN = $Token

# 프론트엔드 빌드 (grantscout_web)
Write-Host "grantscout_web 빌드를 실행합니다..." -ForegroundColor Cyan
npm --prefix "./grantscout_web" run build

if ($LASTEXITCODE -ne 0) {
    Write-Host "빌드가 실패했습니다. 배포를 중단합니다." -ForegroundColor Red
    exit $LASTEXITCODE
}

# Firebase 배포 (프로젝트 ID: grantscout-af8da)
Write-Host "Firebase에 배포를 시작합니다..." -ForegroundColor Cyan
npx firebase-tools deploy --only hosting,functions --project grantscout-af8da --token $Token
