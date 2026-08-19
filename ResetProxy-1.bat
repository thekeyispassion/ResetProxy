@echo off
chcp 65001 >nul
echo ======================================
echo Reset Windows System Proxy
echo ======================================
echo.
echo [1/3] Disable ProxyEnable
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f >nul
powershell -Command "Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 0" >nul

echo [2/3] Clear proxy address
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride /f >nul 2>&1

echo [3/3] Flush DNS
ipconfig /flushdns >nul

echo.
echo Done. Check proxy via inetcpl.cpl
echo.
timeout /t 3 >nul
exit