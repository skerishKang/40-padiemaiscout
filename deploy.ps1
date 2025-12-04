# GrantScout 프로젝트 전용 Firebase 배포 스크립트
# 사용 방법 예시:
#   1) 한 번만 Firebase CLI 로그인
#        npx firebase-tools login
#   2) 이후에는
#        .\deploy.ps1
#      만 실행하면, 현재 로그인된 계정으로 grantscout-af8da 프로젝트를 배포합니다.

# 프론트엔드 빌드 (grantscout_web)
Write-Host "grantscout_web 빌드를 실행합니다..." -ForegroundColor Cyan
npm --prefix "./grantscout_web" run build

if ($LASTEXITCODE -ne 0) {
    Write-Host "빌드가 실패했습니다. 배포를 중단합니다." -ForegroundColor Red
    exit $LASTEXITCODE
}

# Firebase 배포 (프로젝트 ID: grantscout-af8da)
Write-Host "Firebase에 배포를 시작합니다..." -ForegroundColor Cyan
# PowerShell에서는 콤마가 특별히 해석되므로, --only 인자는 반드시 따옴표로 감싼다.
npx firebase-tools deploy --only "hosting,functions" --project grantscout-af8da
