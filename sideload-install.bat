@echo off
chcp 65001 >nul
echo ==========================================
echo  抖数君后台 iOS - Sideloadly 安装
echo ==========================================
echo.
echo 首次安装（需要 Apple ID）：
echo   sideload-install.bat "你的邮箱@gmail.com" "应用密码"
echo.
echo 续期安装（IPA 已保留）：
echo   sideload-refresh.bat "你的邮箱@gmail.com" "新应用密码"
echo.
echo 局域网安装（iPhone 和 PC 同 WiFi）：
echo   sideload-install.bat "你的邮箱@gmail.com" "应用密码" "192.168.x.x"
echo.
echo ==========================================
pause
