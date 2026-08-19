@echo off & chcp 936 >nul
setlocal

echo ==============================================
echo   网络代理环境快速检测
echo   只读检测，不会修改任何设置
echo ==============================================
echo.

echo [1] WinINET 代理开关 (ProxyEnable):
for /f "tokens=3" %%a in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable 2^>nul') do set pe=%%a
if /i "%pe%"=="0x0" (
    echo     [OK] 已禁用
) else if "%pe%"=="" (
    echo     [OK] 不存在，默认禁用
) else (
    echo     [!!] 异常值：%pe%
)
echo.

echo [2] WinINET 代理地址 (ProxyServer):
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer >nul 2>&1
if %errorlevel% equ 0 (echo     [!!] 存在代理地址) else (echo     [OK] 不存在)
echo.

echo [3] PAC 脚本 (AutoConfigURL):
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoConfigURL >nul 2>&1
if %errorlevel% equ 0 (echo     [!!] 存在 PAC 地址) else (echo     [OK] 不存在)
echo.

echo [4] WPAD 自动检测 (AutoDetect):
for /f "tokens=3" %%a in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoDetect 2^>nul') do set ad=%%a
if /i "%ad%"=="0x0" (
    echo     [OK] 已禁用
) else if "%ad%"=="" (
    echo     [OK] 不存在，默认禁用
) else (
    echo     [!!] 异常值：%ad%
)
echo.

echo [5] WinHTTP 系统代理（原始输出如下）:
netsh winhttp show proxy
echo     人工检查：上面列出了代理地址 = 已配置代理
echo.

echo [6] 环境变量 HTTP/HTTPS/ALL_PROXY:
if "%HTTP_PROXY%"=="" (echo     [OK] HTTP_PROXY 未设置) else (echo     [!!] HTTP_PROXY 已设置：%HTTP_PROXY%)
if "%HTTPS_PROXY%"=="" (echo     [OK] HTTPS_PROXY 未设置) else (echo     [!!] HTTPS_PROXY 已设置：%HTTPS_PROXY%)
if "%ALL_PROXY%"=="" (echo     [OK] ALL_PROXY 未设置) else (echo     [!!] ALL_PROXY 已设置：%ALL_PROXY%)
echo.

echo [7] 当前 DNS 服务器:
powershell -NoProfile -Command "Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object {$_.ServerAddresses} | Select-Object @{n='接口别名';e={$_.InterfaceAlias}},@{n='DNS 服务器';e={$_.ServerAddresses -join ', '}} | Format-Table -AutoSize"
echo.

echo [8] DNS 对比：本机 DNS vs 公共 DNS (223.5.5.5):
powershell -NoProfile -Command "$a=(Resolve-DnsName www.baidu.com -Type A -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress} | Select-Object -First 1 -ExpandProperty IPAddress); $b=(Resolve-DnsName www.baidu.com -Server 223.5.5.5 -Type A -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress} | Select-Object -First 1 -ExpandProperty IPAddress); if(!$a){'     [!!] 本机 DNS 解析失败'} elseif(!$b){'     [!!] 公共 DNS 解析失败'} elseif($a -eq $b){'     [OK] 一致：'+$a} else {'     [!!] 不一致，CDN 分流通常属正常现象：本机 '+$a+' / 公共 '+$b}"
echo.

echo [9] hosts 文件：非注释、非 localhost 条目:
powershell -NoProfile -Command "$h=@(Get-Content $env:SystemRoot\System32\drivers\etc\hosts -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object { $t=$_.Trim(); $t -and $t -notmatch '^#' -and $_ -notmatch 'localhost|::1|127\.0\.0\.1' }); if($h.Count){$h}else{'     [OK] 无可疑条目'}"
rem    [OK] 提示由上面的 PowerShell 命令内部处理
echo.

echo ==============================================
echo   检测完成
echo ==============================================
pause
