@echo off
chcp 936 >nul
rem 本脚本已按 GBK(ANSI)编码保存,请勿转存为 UTF-8,否则中文会乱码
setlocal

fltmc >nul 2>&1
if %errorlevel% neq 0 (
    echo 正在申请管理员权限...
    powershell -NoProfile -Command "Start-Process cmd -ArgumentList '/c ""%~f0""' -Verb RunAs" >nul
    exit /b
)

rem ============ 路径设置:全部用脚本自身目录,避免自提权后跑到 System32 ============
set "SCRIPT_DIR=%~dp0"
set "BACKUP_REG=%SCRIPT_DIR%ProxyBackup.reg"
set "ENV_BACKUP=%SCRIPT_DIR%EnvBackup.reg"
set "SYS_ENV_BACKUP=%SCRIPT_DIR%SysEnvBackup.reg"
set "HOSTS_BACKUP=%SCRIPT_DIR%hosts_backup.txt"
set "CERT_LIST=%SCRIPT_DIR%RootCertList.txt"
set "HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts"

echo ======================================
echo   Windows 系统代理彻底重置工具 v3
echo ======================================
echo.

echo [1/8] 备份注册表代理配置、环境变量与 hosts 文件
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" "%BACKUP_REG%" /y >nul 2>&1
reg export "HKCU\Environment" "%ENV_BACKUP%" /y >nul 2>&1
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "%SYS_ENV_BACKUP%" /y >nul 2>&1
copy /y "%HOSTS_FILE%" "%HOSTS_BACKUP%" >nul 2>&1
echo    备份位置:%SCRIPT_DIR%
echo.

echo [2/8] 关闭手动代理与 WPAD 自动检测
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoDetect /t REG_DWORD /d 0 /f >nul
echo.

echo [3/8] 清除代理地址、绕过列表、PAC 脚本
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoConfigURL /f >nul 2>&1
echo.

echo [4/8] 清除 Connections 二进制代理残留
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" /v DefaultConnectionSettings /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" /v SavedLegacySettings /f >nul 2>&1
echo.

echo [5/8] 重置 WinHTTP 代理、刷新 DNS
netsh winhttp reset proxy >nul
ipconfig /flushdns >nul
echo.

echo [6/8] 清除环境变量中的代理配置(会话 + 用户级 + 系统级)
set HTTP_PROXY=
set HTTPS_PROXY=
set ALL_PROXY=
reg delete "HKCU\Environment" /v HTTP_PROXY /f >nul 2>&1
reg delete "HKCU\Environment" /v HTTPS_PROXY /f >nul 2>&1
reg delete "HKCU\Environment" /v ALL_PROXY /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v HTTP_PROXY /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v HTTPS_PROXY /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v ALL_PROXY /f >nul 2>&1
echo.

echo [7/8] 检查仍在运行的代理客户端进程
tasklist | findstr /i "clash verge mihomo v2ray xray sing hiddify nekoray shadowsocks ssr warp" >nul 2>&1
if errorlevel 1 (
    echo    [OK] 未发现代理客户端在运行
) else (
    tasklist | findstr /i "clash verge mihomo v2ray xray sing hiddify nekoray shadowsocks ssr warp"
    echo    [!!] 以上进程仍在运行,若是你正在用的请忽略,否则请手动退出
)
echo.

echo [8/8] 导出受信任根证书列表供人工审查
certutil -store Root > "%CERT_LIST%" 2>nul
for /f %%n in ('type "%CERT_LIST%" ^| find /c "===="') do set certcount=%%n
echo    当前受信任根证书数量:%certcount% 个,列表已导出到 %CERT_LIST%
echo.

echo ======================================
echo   清理完成,当前状态检测:
echo ======================================
echo.

echo 1. 手动代理开关:
for /f "tokens=3" %%a in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable 2^>nul') do set pe=%%a
if /i "%pe%"=="0x0" (echo    [OK] 已关闭) else if "%pe%"=="" (echo    [OK] 不存在,默认关闭) else (echo    [!!] 异常值:%pe%)

echo.
echo 2. WPAD 自动检测:
for /f "tokens=3" %%a in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoDetect 2^>nul') do set ad=%%a
if /i "%ad%"=="0x0" (echo    [OK] 已关闭) else if "%ad%"=="" (echo    [OK] 不存在,默认关闭) else (echo    [!!] 异常值:%ad%)

echo.
echo 3. PAC 自动脚本地址:
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoConfigURL >nul 2>&1
if %errorlevel% equ 0 (
    echo    [!!] 仍存在 PAC 地址,请手动检查
) else (
    echo    [OK] 已清空
)

echo.
echo 4. 系统级 WinHTTP 代理:
netsh winhttp show proxy > "%TEMP%\winhttp_check.txt" 2>nul
findstr /i /c:"://" "%TEMP%\winhttp_check.txt" >nul 2>&1
if %errorlevel% equ 0 (
    echo    [!!] 检测到 WinHTTP 代理,当前内容如下:
    powershell -NoProfile -Command "Get-Content $env:TEMP\winhttp_check.txt -Encoding UTF8"
) else (
    echo    [OK] 无代理（直接访问）
)

echo.
echo 5. hosts 文件可疑条目(非注释、非 localhost):
powershell -NoProfile -Command "$h=@(Get-Content $env:SystemRoot\System32\drivers\etc\hosts -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object { $t=$_.Trim(); $t -and $t -notmatch '^#' -and $_ -notmatch 'localhost|::1|127\.0\.0\.1' }); if($h.Count){$h | ForEach-Object {'    [!!]  '+$_}}else{'    [OK] 无异常条目'}"

echo.
echo 6. DNS 污染快速对比(www.baidu.com;CDN 域名结果不同属正常,多个域名都不一致才需警惕):
powershell -NoProfile -Command "$a=(Resolve-DnsName www.baidu.com -Type A -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress} | Select-Object -First 1 -ExpandProperty IPAddress); $b=(Resolve-DnsName www.baidu.com -Server 223.5.5.5 -Type A -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress} | Select-Object -First 1 -ExpandProperty IPAddress); if(!$a){'   [!!] 本机 DNS 解析失败(可能断网或被污染)'} elseif(!$b){'   [!!] 本机解析: '+$a+' 但公共 DNS(223.5.5.5)解析失败'} elseif($a -eq $b){'   [OK] 本机 DNS 与公共 DNS 结果一致: '+$a} else {'   [!!] 不一致! 本机: '+$a+' / 公共 DNS: '+$b}"

echo.
echo 7. 当前网卡配置的 DNS 服务器(与 223.5.5.5 / 119.29.29.29 等公共 DNS 对照):
ipconfig /all | findstr /i /c:"DNS Servers" /c:"DNS 服务器"

echo.
echo 8. 根证书审查提醒:
echo    列表已导出: %CERT_LIST%
echo    人工检查:Win+R 输入 certmgr.msc → 受信任的根证书颁发机构
echo    正常来源包括 Microsoft、DigiCert、GlobalSign、Let's Encrypt 等
echo    出现不认识的证书 = 高危信号,请删除

echo.
echo 9. 环境变量代理残留(用户级与系统级):
set "env_ok=1"
for %%v in (HTTP_PROXY HTTPS_PROXY ALL_PROXY) do (
    reg query "HKCU\Environment" /v %%v >nul 2>&1 && set "env_ok=0"
    reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v %%v >nul 2>&1 && set "env_ok=0"
)
if "%env_ok%"=="1" (echo    [OK] 均已清空) else (echo    [!!] 仍有残留,请手动检查)

echo.
echo ======================================
echo   重要提醒
echo ======================================
echo 1. 本脚本仅清理系统层面代理,无法清理浏览器扩展代理
echo 2. 登录重要账号前:确认地址栏为 https 且证书锁正常,绝不忽略证书警告
echo 3. 绝不安装任何机场/软件提供的根证书(装了它就能解密你的 HTTPS)
echo 4. 清理后浏览器需重启或刷新,代理设置才完全生效
echo 5. 环境变量清理后,已打开的终端/IDE 需重开才会生效
echo 6. 仍有网页跳转:查浏览器扩展、查 hosts(已自动备份)、全盘杀毒
echo 7. 恢复:双击 ProxyBackup.reg / EnvBackup.reg / SysEnvBackup.reg 可还原对应配置
echo.
pause
exit
