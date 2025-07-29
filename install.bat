@echo off
chcp 65001 >nul
echo.
echo ========================================
echo  🏆 매물 자동화 시스템 설치 프로그램
echo ========================================
echo.

REM 관리자 권한 확인
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ❌ 관리자 권한이 필요합니다.
    echo 우클릭 → "관리자 권한으로 실행"을 선택해주세요.
    pause
    exit /b 1
)

echo 📋 시스템 요구사항 확인 중...

REM Python 설치 확인
python --version >nul 2>&1
if %errorLevel% neq 0 (
    echo ❌ Python이 설치되지 않았습니다.
    echo 📥 https://www.python.org/downloads/ 에서 Python 3.8 이상을 설치해주세요.
    pause
    exit /b 1
)

echo ✅ Python 설치 확인됨

REM Git 설치 확인
git --version >nul 2>&1
if %errorLevel% neq 0 (
    echo ❌ Git이 설치되지 않았습니다.
    echo 📥 https://git-scm.com/downloads 에서 Git을 설치해주세요.
    pause
    exit /b 1
)

echo ✅ Git 설치 확인됨

REM 작업 디렉토리 생성
echo.
echo 📁 작업 폴더 생성 중...
cd /d "%USERPROFILE%\Desktop"
if not exist "cursor" mkdir cursor
cd cursor

REM 로컬 클라이언트 다운로드
echo.
echo 📥 로컬 클라이언트 다운로드 중...

REM PowerShell을 사용하여 최신 릴리즈 다운로드
powershell -Command "& {
    try {
        $latestRelease = Invoke-RestMethod -Uri 'https://api.github.com/repos/small-creator/property-automation-client/releases/latest'
        $downloadUrl = $latestRelease.assets | Where-Object { $_.name -eq 'property-automation-client.zip' } | Select-Object -ExpandProperty browser_download_url
        
        if ($downloadUrl) {
            Write-Host '📦 최신 버전 다운로드 중...' -ForegroundColor Green
            Invoke-WebRequest -Uri $downloadUrl -OutFile 'property-automation-client.zip'
            
            Write-Host '📂 압축 해제 중...' -ForegroundColor Green
            Expand-Archive -Path 'property-automation-client.zip' -DestinationPath 'property_ad_auto_git' -Force
            
            Remove-Item 'property-automation-client.zip'
            Write-Host '✅ 로컬 클라이언트 설치 완료' -ForegroundColor Green
        } else {
            Write-Host '❌ 다운로드 파일을 찾을 수 없습니다.' -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host '❌ 다운로드 실패:' $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}"

if %errorLevel% neq 0 (
    echo ❌ 로컬 클라이언트 다운로드 실패
    pause
    exit /b 1
)

echo ✅ 로컬 클라이언트 설치 완료

REM GitHub Actions 저장소 클론
echo.
echo 📥 GitHub Actions 저장소 다운로드 중...
if not exist "github_repos" mkdir github_repos
cd github_repos

echo.
echo 📋 GitHub Actions 설정 방법:
echo 1. https://github.com/small-creator/naverland-automation-template 접속
echo 2. Fork 버튼 클릭하여 자신의 계정으로 복사
echo 3. Settings → Secrets and variables → Actions에서 설정:
echo    - LOGIN_ID: 로그인 아이디
echo    - LOGIN_PASSWORD: 로그인 비밀번호
echo.
set /p USER_CHOICE="Fork 완료했습니까? (y/n): "

if /i "%USER_CHOICE%"=="y" (
    set /p USER_NAME="GitHub 사용자명을 입력하세요: "
    set FORK_URL=https://github.com/!USER_NAME!/naverland-automation-template
    
    echo.
    echo 📥 Fork된 저장소 클론 중...
    git clone !FORK_URL! user-automation
    
    if exist "user-automation" (
        cd user-automation
        echo ✅ GitHub Actions 저장소 클론 완료
    ) else (
        echo ❌ 저장소 클론 실패. 사용자명을 확인해주세요.
        pause
        exit /b 1
    )
) else (
    echo ❌ Fork를 먼저 완료해주세요.
    pause
    exit /b 1
)

cd ..

REM Python 패키지 설치
echo.
echo 📦 Python 패키지 설치 중...
cd property_ad_auto_git

python -m pip install --upgrade pip
pip install python-dotenv==1.0.0
pip install playwright==1.40.0
pip install requests==2.31.0
pip install beautifulsoup4==4.12.2

echo.
echo 🎭 Playwright 브라우저 설치 중...
playwright install chromium

REM .env 파일 생성
echo.
echo 🔧 환경변수 설정 파일 생성 중...
if not exist ".env" (
    echo # 로그인 정보 > .env
    echo LOGIN_ID=여기에_로그인_ID_입력 >> .env
    echo LOGIN_PASSWORD=여기에_비밀번호_입력 >> .env
    echo. >> .env
    echo # 부동산 중개업소 ID >> .env
    echo REALTOR_ID=여기에_중개업소_ID_입력 >> .env
    echo. >> .env
    echo # GitHub 저장소 경로 (자동 설정됨) >> .env
    echo GITHUB_REPO_PATH=%USERPROFILE%\Desktop\cursor\github_repos\%REPO_NAME% >> .env
    
    echo ✅ .env 파일이 생성되었습니다.
    echo ⚠️  .env 파일을 편집하여 로그인 정보를 입력해주세요.
) else (
    echo ℹ️  .env 파일이 이미 존재합니다.
)

REM 실행 배치 파일 생성
echo.
echo 🚀 실행 파일 생성 중...
echo @echo off > run.bat
echo cd /d "%USERPROFILE%\Desktop\cursor\property_ad_auto_git" >> run.bat
echo python complete_automation_system.py >> run.bat
echo pause >> run.bat

REM 바탕화면 바로가기 생성
echo.
echo 🔗 바탕화면 바로가기 생성 중...
set "shortcut_path=%USERPROFILE%\Desktop\매물자동화시스템.lnk"
powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%shortcut_path%'); $Shortcut.TargetPath = '%USERPROFILE%\Desktop\cursor\property_ad_auto_git\run.bat'; $Shortcut.WorkingDirectory = '%USERPROFILE%\Desktop\cursor\property_ad_auto_git'; $Shortcut.IconLocation = 'shell32.dll,137'; $Shortcut.Save()"

echo.
echo ========================================
echo  🎉 설치 완료!
echo ========================================
echo.
echo 📍 설치 위치: %USERPROFILE%\Desktop\cursor\
echo 🚀 실행 방법: 바탕화면의 "매물자동화시스템" 바로가기 클릭
echo.
echo ⚠️  다음 단계:
echo 1. .env 파일 편집 (로그인 정보 입력)
echo 2. Git 사용자 설정:
echo    git config --global user.email "your_email@example.com"
echo    git config --global user.name "Your Name"
echo.
echo 📖 자세한 사용법은 README.md 파일을 참고하세요.
echo.
pause
