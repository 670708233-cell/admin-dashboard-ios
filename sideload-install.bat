@echo off
chcp 65001 >nul
echo ==========================================
echo  抖数君后台 iOS - Sideloadly 安装工具
echo ==========================================
echo.
echo 首次安装（需要 Apple ID）：
echo   .\sideload-install.bat install "your@email.com" "你的App密码"
echo.
echo 续期安装（IPA 已保留）：
echo   .\sideload-install.bat renew "your@email.com" "你的App密码"
echo.
echo 局域网安装（iPhone 和 PC 同一 WiFi）：
echo   .\sideload-install.bat install "your@email.com" "你的App密码" "192.168.1.100"
echo.
pause
