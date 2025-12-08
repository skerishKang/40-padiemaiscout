# GrantScout 프로젝트 전용 배포 스크립트 (GitHub + Firebase 동시 배포)
# 사용 방법 예시:
#   1) 한 번만 Firebase CLI 로그인
#        npx firebase-tools login
#   2) 이후에는
#        .\deploy.ps1
#      만 실행하면, GitHub 커밋 및 Firebase 배포를 동시에 진행합니다.

# 프론트엔드 빌드 (grantscout_web)
Write-Host "grantscout_web 빌드를 실행합니다..." -ForegroundColor Cyan
npm --prefix "./grantscout_web" run build

if ($LASTEXITCODE -ne 0) {
    Write-Host "빌드가 실패했습니다. 배포를 중단합니다." -ForegroundColor Red
    exit $LASTEXITCODE
}

# GitHub 푸시 (변경사항이 있을 경우에만)
Write-Host "GitHub에 변경사항을 푸시합니다..." -ForegroundColor Cyan
git add . 2>$null

# 변경사항 있는지 확인
$hasChanges = -not (git diff --quiet) -or -not (git diff --cached --quiet)

if ($hasChanges) {
    Write-Host "변경사항이 발견되어 GitHub에 푸시합니다..." -ForegroundColor Green
    $commitMessage = "Update: 자동 배포 - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    git commit -m $commitMessage 2>$null
    git push origin main
} else {
    Write-Host "변경사항이 없어 GitHub 푸시를 건너뜁니다." -ForegroundColor Yellow
}

# Firebase 배포 (프로젝트 ID: grantscout-af8da)
Write-Host "Firebase에 배포를 시작합니다..." -ForegroundColor Cyan
# PowerShell에서는 콤마가 특별히 해석되므로, --only 인자는 반드시 따옴표로 감싼다.
npx firebase-tools deploy --only "hosting,functions,firestore" --project grantscout-af8da

Write-Host "배포 완료! 🎉" -ForegroundColor Green
Write-Host "- GitHub: https://github.com/skerishKang/40-padiemaiscout" -ForegroundColor Cyan
Write-Host "- Firebase: https://grantscout-af8da.web.app" -ForegroundColor Cyan
