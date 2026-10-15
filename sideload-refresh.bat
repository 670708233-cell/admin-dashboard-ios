@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set APPLE_ID=%~1
set APP_PASSWORD=%~2
set DEVICE_IP=%~3
set IPA_PATH=%~4

if "%APPLE_ID%"=="" (
    echo 错误：缺少 Apple ID 参数
    echo.
    echo 用法: sideload-refresh.bat ^<AppleID^> ^<AppPassword^> [DeviceIP] [IPAPath]
    echo.
    echo 示例:
    echo   sideload-refresh.bat myemail@gmail.com abcd-efgh-ijkl-mnop
    echo   sideload-refresh.bat myemail@gmail.com abcd-efgh-ijkl-mnop 192.168.1.100
    pause
    exit /b 1
)

if "%APP_PASSWORD%"=="" (
    echo 错误：缺少 App Password 参数
    pause
    exit /b 1
)

powershell -ExecutionPolicy Bypass -File "%~dp0sideload.ps1" -AppleID "%APPLE_ID%" -AppPassword "%APP_PASSWORD%" %if defined DEVICE_IP% -DeviceIP "%DEVICE_IP%" %if not defined IPA_PATH% -SkipDownload%if defined IPA_PATH% -IPAPath "%IPA_PATH%"

endlocal
pause
