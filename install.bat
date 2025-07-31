@echo off
REM ================================================================
REM 매물 자동화 시스템 설치 프로그램 (개선된 버전)
REM - 한글 깨짐 방지 다중 인코딩 지원
REM - 버전 하드코딩 제거로 유연한 다운로드
REM ================================================================

REM 다중 인코딩 설정으로 한글 깨짐 방지
chcp 65001 >nul 2>&1
if %errorLevel% neq 0 chcp 949 >nul 2>&1

REM 콘솔 폰트 설정 (Windows 10/11)
reg add "HKCU\Console" /v "FaceName" /t REG_SZ /d "맑은 고딕" /f >nul 2>&1

REM 콘솔 창 제목 설정
title 매물 자동화 시스템 설치 프로그램

echo.
echo ========================================
echo  🏆 매물 자동화 시스템 설치 프로그램
echo ========================================
echo.

REM 시스템 정보 표시
for /f "tokens=2 delims==" %%a in ('wmic os get locale /value 2^>nul ^| find "="') do set SYSTEM_LOCALE=%%a
echo [시스템 정보]
echo - 현재 코드페이지: %~1
echo - 시스템 로케일: %SYSTEM_LOCALE%
echo - 실행 위치: %~dp0
echo.

REM 관리자 권한 확인
echo [확인] 관리자 권한 확인 중...
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [오류] 관리자 권한이 필요합니다.
    echo 파일을 우클릭하여 "관리자 권한으로 실행"을 선택해주세요.
    echo.
    pause
    exit /b 1
)
echo [확인] 관리자 권한 확인됨
echo.

echo [확인] 시스템 요구사항 확인 중...

REM Python 설치 확인
echo [확인] Python 설치 상태 확인 중...
python --version >nul 2>&1
if %errorLevel% neq 0 (
    echo [오류] Python이 설치되지 않았습니다.
    echo 다운로드 링크: https://www.python.org/downloads/
    echo Python 3.8 이상을 설치한 후 다시 실행해주세요.
    echo.
    pause
    exit /b 1
)

for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
echo [확인] Python %PYTHON_VERSION% 설치됨

REM Git 설치 확인
echo [확인] Git 설치 상태 확인 중...
git --version >nul 2>&1
if %errorLevel% neq 0 (
    echo [오류] Git이 설치되지 않았습니다.
    echo 다운로드 링크: https://git-scm.com/downloads
    echo Git을 설치한 후 다시 실행해주세요.
    echo.
    pause
    exit /b 1
)

for /f "tokens=3" %%i in ('git --version 2^>^&1') do set GIT_VERSION=%%i
echo [확인] Git %GIT_VERSION% 설치됨
echo.

REM 작업 디렉토리 생성
echo [진행] 작업 폴더 설정 중...
set "WORK_DIR=%USERPROFILE%\Desktop\property_automation"

if not exist "%WORK_DIR%" (
    mkdir "%WORK_DIR%"
    echo [완료] 작업 폴더 생성: %WORK_DIR%
) else (
    echo [정보] 기존 작업 폴더 사용: %WORK_DIR%
)

cd /d "%WORK_DIR%"
echo.

REM 로컬 클라이언트 다운로드 (개선된 버전 - 하드코딩 제거)
echo [진행] GitHub에서 최신 버전 다운로드 중...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "& {
    # 인코딩 설정
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $Host.UI.RawUI.OutputEncoding = [System.Text.Encoding]::UTF8
    
    try {
        Write-Host '[진행] GitHub API 호출 중...' -ForegroundColor Green
        $latestRelease = Invoke-RestMethod -Uri 'https://api.github.com/repos/small-creator/naver_ad_auto_pc/releases/latest'
        
        Write-Host \"[정보] 최신 릴리즈 버전: $($latestRelease.tag_name)\" -ForegroundColor Cyan
        Write-Host \"[정보] 릴리즈 날짜: $($latestRelease.published_at)\" -ForegroundColor Cyan
        Write-Host \"[정보] 사용 가능한 파일 목록:\" -ForegroundColor Cyan
        $latestRelease.assets | ForEach-Object { 
            Write-Host \"  - $($_.name) ($([math]::Round($_.size/1024/1024, 2)) MB)\" -ForegroundColor Gray
        }
        Write-Host
        
        # 우선순위별 파일 검색 패턴
        $patterns = @(
            '매물자동화시스템*.zip',
            'property_automation*.zip',
            'naver_ad_auto*.zip',
            '*automation*.zip',
            '*.zip'
        )
        
        $selectedAsset = $null
        $selectedPattern = $null
        
        foreach ($pattern in $patterns) {
            $matchingAssets = $latestRelease.assets | Where-Object { $_.name -like $pattern }
            if ($matchingAssets) {
                $selectedAsset = $matchingAssets | Select-Object -First 1
                $selectedPattern = $pattern
                break
            }
        }
        
        if ($selectedAsset) {
            $fileName = $selectedAsset.name
            $downloadUrl = $selectedAsset.browser_download_url
            
            Write-Host \"[선택] 다운로드 파일: $fileName\" -ForegroundColor Green
            Write-Host \"[선택] 매칭 패턴: $selectedPattern\" -ForegroundColor Green
            Write-Host \"[진행] 파일 크기: $([math]::Round($selectedAsset.size/1024/1024, 2)) MB\" -ForegroundColor Green
            Write-Host
            
            Write-Host '[진행] 다운로드 시작...' -ForegroundColor Green
            Invoke-WebRequest -Uri $downloadUrl -OutFile $fileName -UseBasicParsing
            
            Write-Host '[진행] 압축 해제 중...' -ForegroundColor Green
            
            # 기존 폴더가 있으면 백업
            if (Test-Path 'property_ad_auto_git') {
                $backupName = \"property_ad_auto_git_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')\"
                Write-Host \"[정보] 기존 폴더를 $backupName 으로 백업합니다.\" -ForegroundColor Yellow
                Rename-Item 'property_ad_auto_git' $backupName
            }
            
            Expand-Archive -Path $fileName -DestinationPath 'property_ad_auto_git' -Force
            
            Write-Host '[정리] 압축 파일 삭제 중...' -ForegroundColor Green
            Remove-Item $fileName
            
            Write-Host '[완료] 로컬 클라이언트 설치 완료!' -ForegroundColor Green
            Write-Host \"[완료] 설치된 버전: $($latestRelease.tag_name)\" -ForegroundColor Green
            
        } else {
            Write-Host '[오류] 다운로드 가능한 .zip 파일을 찾을 수 없습니다.' -ForegroundColor Red
            Write-Host '[오류] 다음 링크에서 수동으로 다운로드해주세요:' -ForegroundColor Red
            Write-Host \"[링크] https://github.com/small-creator/naver_ad_auto_pc/releases/latest\" -ForegroundColor Cyan
            exit 1
        }
        
    } catch {
        Write-Host '[오류] 다운로드 실패:' $_.Exception.Message -ForegroundColor Red
        Write-Host '[대안] 네트워크 연결을 확인하고 다시 시도하거나' -ForegroundColor Yellow
        Write-Host '[대안] 다음 링크에서 수동 다운로드하세요:' -ForegroundColor Yellow
        Write-Host '[링크] https://github.com/small-creator/naver_ad_auto_pc/releases/latest' -ForegroundColor Cyan
        exit 1
    }
}"

if %errorLevel% neq 0 (
    echo [오류] 로컬 클라이언트 다운로드 실패
    echo [대안] 수동 다운로드 후 property_ad_auto_git 폴더에 압축 해제하세요.
    echo.
    pause
    exit /b 1
)

echo.

REM GitHub Actions 설정 확인 (사전 작업 완료 여부 체크)
echo [선택] GitHub Actions 연동 설정
echo.
echo ⚠️  GitHub Actions를 사용하려면 다음 작업을 먼저 완료해야 합니다:
echo.
echo 📋 사전 준비 작업:
echo 1. GitHub 계정 로그인
echo 2. https://github.com/small-creator/naver_ad_auto_template 접속
echo 3. 우상단 "Fork" 버튼 클릭하여 본인 계정으로 복사
echo 4. Fork된 저장소에서 Settings → Secrets and variables → Actions 이동
echo 5. "New repository secret" 버튼으로 다음 항목들 추가:
echo    - Name: LOGIN_ID, Secret: [네이버 로그인 아이디]
echo    - Name: LOGIN_PASSWORD, Secret: [네이버 로그인 비밀번호]
echo    - Name: REALTOR_ID, Secret: [중개업소 ID]
echo.

set /p FORK_DONE="위 사전 작업을 모두 완료했습니까? (y/n): "

if /i "%FORK_DONE%"=="y" (
    set /p USER_NAME="GitHub 사용자명을 입력하세요: "
    
    echo.
    echo [확인] GitHub 저장소 접근성 테스트 중...
    
    REM GitHub 저장소 존재 여부 확인
    powershell -Command "& {
        try {
            $response = Invoke-WebRequest -Uri 'https://github.com/!USER_NAME!/naver_ad_auto_template' -Method Head -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Host '[확인] Fork된 저장소 접근 가능' -ForegroundColor Green
                exit 0
            }
        } catch {
            Write-Host '[오류] Fork된 저장소에 접근할 수 없습니다.' -ForegroundColor Red
            Write-Host '[확인] GitHub 사용자명과 Fork 완료 여부를 확인해주세요.' -ForegroundColor Yellow
            exit 1
        }
    }"
    
    if !errorLevel! equ 0 (
        if not exist "github_repos" mkdir github_repos
        cd github_repos
        
        set FORK_URL=https://github.com/!USER_NAME!/naver_ad_auto_template
        
        echo [진행] Fork된 저장소 클론 중...
        git clone !FORK_URL! user-automation
        
        if exist "user-automation" (
            cd user-automation
            echo [완료] GitHub Actions 저장소 연동 완료
            cd ..\..
            set GITHUB_PATH=%WORK_DIR%\github_repos\user-automation
        ) else (
            echo [오류] 저장소 클론 실패
            cd ..
            set GITHUB_PATH=로컬전용모드
        )
    ) else (
        echo [오류] Fork된 저장소에 접근할 수 없습니다.
        echo [안내] 로컬 전용 모드로 설치를 계속합니다.
        set GITHUB_PATH=로컬전용모드
    )
) else (
    echo [선택] GitHub Actions 연동을 건너뜁니다.
    echo [안내] 로컬에서만 실행 가능한 모드로 설치합니다.
    echo.
    echo 💡 나중에 GitHub Actions를 사용하려면:
    echo 1. 위의 사전 작업을 완료한 후
    echo 2. 이 설치 프로그램을 다시 실행하세요
    set GITHUB_PATH=로컬전용모드
)

echo.

REM Python 패키지 설치
echo [진행] Python 패키지 설치 중...
cd "%WORK_DIR%\property_ad_auto_git"

echo [패키지] pip 업그레이드 중...
python -m pip install --upgrade pip --quiet

echo [패키지] 필수 라이브러리 설치 중...
pip install python-dotenv==1.0.0 --quiet
if %errorLevel% neq 0 echo [경고] python-dotenv 설치 실패

pip install playwright==1.40.0 --quiet
if %errorLevel% neq 0 echo [경고] playwright 설치 실패

pip install requests==2.31.0 --quiet
if %errorLevel% neq 0 echo [경고] requests 설치 실패

pip install beautifulsoup4==4.12.2 --quiet
if %errorLevel% neq 0 echo [경고] beautifulsoup4 설치 실패

echo [완료] Python 패키지 설치 완료

echo.
echo [진행] Playwright 브라우저 설치 중...
echo [정보] 이 과정은 시간이 걸릴 수 있습니다...
playwright install chromium
if %errorLevel% neq 0 (
    echo [경고] Playwright 브라우저 설치 실패
    echo [대안] 나중에 수동으로 'playwright install chromium' 명령을 실행하세요.
) else (
    echo [완료] Playwright 브라우저 설치 완료
)

echo.

REM .env 파일 설정
echo [진행] 환경 설정 파일 확인 중...

if not exist ".env" (
    echo [정보] .env 파일이 없습니다. 템플릿을 생성합니다.
    echo # 매물 자동화 시스템 환경 설정 > .env
    echo # 로그인 정보 (필수) >> .env
    echo LOGIN_ID=your_login_id >> .env
    echo LOGIN_PASSWORD=your_password >> .env
    echo. >> .env
    echo # 중개업소 정보 (필수) >> .env
    echo REALTOR_ID=your_realtor_id >> .env
    echo. >> .env
    echo # GitHub 저장소 경로 (자동 설정됨) >> .env
    echo GITHUB_REPO_PATH=%GITHUB_PATH% >> .env
    echo.
    echo [생성] .env 템플릿 파일이 생성되었습니다.
) else (
    echo [확인] .env 파일이 이미 존재합니다.
    echo [업데이트] GitHub 저장소 경로를 업데이트합니다...
    
    REM PowerShell로 .env 파일 업데이트
    powershell -Command "& {
        $envPath = '.env'
        if (Test-Path $envPath) {
            $envContent = Get-Content $envPath -Raw
            $newPath = 'GITHUB_REPO_PATH=%GITHUB_PATH%'
            if ($envContent -match 'GITHUB_REPO_PATH=.*') {
                $envContent = $envContent -replace 'GITHUB_REPO_PATH=.*', $newPath
            } else {
                $envContent += \"`n$newPath\"
            }
            Set-Content $envPath $envContent -NoNewline -Encoding UTF8
        }
    }"
    echo [완료] .env 파일 업데이트 완료
)

echo.

REM 실행 배치 파일 생성
echo [진행] 실행 파일 생성 중...
(
echo @echo off
echo chcp 65001 ^>nul 2^>^&1
echo title 매물 자동화 시스템
echo cd /d "%WORK_DIR%\property_ad_auto_git"
echo echo [시작] 매물 자동화 시스템을 시작합니다...
echo echo.
echo python complete_automation_system.py
echo echo.
echo echo [완료] 프로그램이 종료되었습니다.
echo pause
) > "%WORK_DIR%\run.bat"

echo [완료] 실행 파일 생성: %WORK_DIR%\run.bat

REM 바탕화면 바로가기 생성
echo [진행] 바탕화면 바로가기 생성 중...
set "shortcut_path=%USERPROFILE%\Desktop\매물자동화시스템.lnk"

powershell -Command "& {
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut('%shortcut_path%')
    $Shortcut.TargetPath = '%WORK_DIR%\run.bat'
    $Shortcut.WorkingDirectory = '%WORK_DIR%'
    $Shortcut.IconLocation = 'shell32.dll,137'
    $Shortcut.Description = '매물 자동화 시스템 실행'
    $Shortcut.Save()
}"

if exist "%shortcut_path%" (
    echo [완료] 바탕화면 바로가기 생성 완료
) else (
    echo [경고] 바탕화면 바로가기 생성 실패
)

echo.
echo ========================================
echo  🎉 설치 완료!
echo ========================================
echo.
echo [설치 정보]
echo - 설치 위치: %WORK_DIR%
echo - Python 버전: %PYTHON_VERSION%
echo - Git 버전: %GIT_VERSION%
echo - GitHub Actions: %GITHUB_PATH%
echo.
echo [즉시 실행 방법]
echo 1. 바탕화면의 "매물자동화시스템" 바로가기 클릭
echo 2. 또는 %WORK_DIR%\run.bat 실행
echo.
echo [필수 설정 - 실행 전 반드시 수행]
echo 📝 %WORK_DIR%\property_ad_auto_git\.env 파일 편집:
echo    - LOGIN_ID=실제로그인아이디
echo    - LOGIN_PASSWORD=실제비밀번호  
echo    - REALTOR_ID=실제중개업소ID
echo.
if "%GITHUB_PATH%"=="로컬전용모드" (
    echo [GitHub Actions 사용 안함]
    echo - 현재 로컬 전용 모드로 설치되었습니다
    echo - 나중에 GitHub Actions 사용을 원하면:
    echo   1. https://github.com/small-creator/naver_ad_auto_template Fork
    echo   2. Settings → Secrets에서 LOGIN_ID, LOGIN_PASSWORD, REALTOR_ID 설정  
    echo   3. 이 설치 프로그램 다시 실행
) else (
    echo [GitHub Actions 연동 완료]
    echo - 자동 실행 기능이 활성화되었습니다
    echo - 추가 Git 설정 권장:
    echo   git config --global user.email "your_email@example.com"
    echo   git config --global user.name "Your Name"
)
echo.
echo [참고 문서 및 지원]
echo - 사용법: README.md 파일 참고
echo - 문제 신고: GitHub Issues 활용
echo - 한글 깨짐시: 콘솔 글꼴을 "맑은 고딕"으로 변경
echo.
echo ⚠️  중요: .env 파일 설정 없이는 프로그램이 실행되지 않습니다!
echo.
pause
