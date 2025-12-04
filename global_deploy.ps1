# GrantScout 전역 배포 관리자 (GitHub + Firebase 자동 배포)
# 사용법: .\global_deploy.ps1 [options]
# 옵션들:
#   --github-only : GitHub만 푸시
#   --firebase-only : Firebase만 배포  
#   --both (기본값) : 둘 다
#   --check : 현재 설정된 정책 확인

param(
    [string]$target = "--both",
    [switch]$check = $false
)

# 전역 설정 파일 로드
$rulesPath = "./deploy_rules.json"
if (-Not (Test-Path $rulesPath)) {
    Write-Host "❌ 배포 정책 파일을 찾을 수 없습니다: $rulesPath" -ForegroundColor Red
    exit 1
}

$rules = Get-Content $rulesPath | ConvertFrom-Json

# 정책 확인 모드
if ($check) {
    Write-Host "📋 GrantScout 배포 정책 확인" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Gray
    Write-Host "프로젝트: $($rules.projectName)" -ForegroundColor White
    Write-Host "버전: $($rules.version)" -ForegroundColor White
    Write-Host ""
    Write-Host "GitHub:" -ForegroundColor Green
    Write-Host "  필수: $($rules.deploymentRules.github.required)" -ForegroundColor White
    Write-Host "  자동 푸시: $($rules.deploymentRules.github.autoPush)" -ForegroundColor White
    Write-Host "  레포지토리: $($rules.urls.github)" -ForegroundColor White
    Write-Host ""
    Write-Host "Firebase:" -ForegroundColor Blue  
    Write-Host "  필수: $($rules.deploymentRules.firebase.required)" -ForegroundColor White
    Write-Host "  호스팅: $($rules.deploymentRules.firebase.hosting)" -ForegroundColor White
    Write-Host "  Functions: $($rules.deploymentRules.firebase.functions)" -ForegroundColor White
    Write-Host "  프로젝트 ID: $($rules.deploymentRules.firebase.projectId)" -ForegroundColor White
    Write-Host "  웹사이트: $($rules.urls.firebase)" -ForegroundColor White
    Write-Host ""
    Write-Host "파일 유형별 배포 정책:" -ForegroundColor Yellow
    $rules.fileTypeRules | Get-Member -MemberType NoteProperty | ForEach-Object {
        $key = $_.Name
        $value = $rules.fileTypeRules.$key
        Write-Host "  ${key}:" -ForegroundColor White
        Write-Host "    대상: $($value.targets -join ', ')" -ForegroundColor Gray
        Write-Host "    패턴: $($value.patterns.Count)개" -ForegroundColor Gray
    }
    exit 0
}

# 로그 출력 함수
function Write-DeployLog {
    param([string]$message, [string]$color = "White")
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $message" -ForegroundColor $color
}

# GitHub 배포 함수
function Deploy-GitHub {
    Write-DeployLog "GitHub 배포를 시작합니다..." -Color Cyan
    
    # 변경사항 확인
    git add . 2>$null
    $hasChanges = -not (git diff --quiet) -or -not (git diff --cached --quiet)
    
    if ($hasChanges) {
        $commitMessage = "Update: $($rules.projectName) - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-DeployLog "변경사항이 발견되어 커밋합니다..." -Color Green
        git commit -m $commitMessage 2>$null
        
        Write-DeployLog "GitHub에 푸시합니다..." -Color Green
        git push origin main
        
        if ($LASTEXITCODE -eq 0) {
            Write-DeployLog "✅ GitHub 배포 완료!" -Color Green
        } else {
            Write-DeployLog "❌ GitHub 푸시 실패!" -Color Red
            return $false
        }
    } else {
        Write-DeployLog "ℹ️ 변경사항이 없어 GitHub 푸시를 건너뜁니다." -Color Yellow
    }
    return $true
}

# Firebase 배포 함수  
function Deploy-Firebase {
    Write-DeployLog "Firebase 배포를 시작합니다..." -Color Cyan
    
    # 빌드 확인
    if (-Not (Test-Path "grantscout_web/dist")) {
        Write-DeployLog "프론트엔드 빌드를 실행합니다..." -Color Yellow
        npm --prefix "./grantscout_web" run build
        if ($LASTEXITCODE -ne 0) {
            Write-DeployLog "❌ 프론트엔드 빌드 실패!" -Color Red
            return $false
        }
    }
    
    # Firebase 배포
    Write-DeployLog "Firebase에 배포합니다..." -Color Blue
    npx firebase-tools deploy --project $rules.deploymentRules.firebase.projectId --only "hosting,functions"
    
    if ($LASTEXITCODE -eq 0) {
        Write-DeployLog "✅ Firebase 배포 완료!" -Color Green
        return $true
    } else {
        Write-DeployLog "❌ Firebase 배포 실패!" -Color Red
        return $false
    }
}

# 메인 배포 로직
Write-Host "🚀 $($rules.projectName) 전역 배포 시작" -ForegroundColor Magenta
Write-Host "==================" -ForegroundColor Gray
Write-Host "타겟: $target" -ForegroundColor White
Write-Host ""

$success = $true

# 대상별 배포 실행
switch ($target.ToLower()) {
    "--github-only" {
        $success = Deploy-GitHub
    }
    "--firebase-only" {
        $success = Deploy-Firebase
    }
    "--both" {
        $success = (Deploy-GitHub) -and (Deploy-Firebase)
    }
    default {
        Write-Host "❌ 알 수 없는 타겟: $target" -ForegroundColor Red
        Write-Host "사용법: .\global_deploy.ps1 [--github-only|--firebase-only|--both|--check]" -ForegroundColor Yellow
        exit 1
    }
}

# 최종 결과
Write-Host ""
if ($success) {
    Write-Host "🎉 배포 완료!" -ForegroundColor Green
    Write-Host "==================" -ForegroundColor Gray
    if ($target -eq "--github-only" -or $target -eq "--both") {
        Write-Host "📁 GitHub: $($rules.urls.github)" -ForegroundColor Cyan
    }
    if ($target -eq "--firebase-only" -or $target -eq "--both") {
        Write-Host "🌐 Firebase: $($rules.urls.firebase)" -ForegroundColor Cyan
    }
} else {
    Write-Host "💥 배포 실패!" -ForegroundColor Red
    exit 1
}