# ResetProxy — Windows 系统代理清理工具

## 项目作用

清理 Windows 系统层面残留的代理配置。常见场景：代理软件（Clash、v2ray、加速器等）卸载或异常退出后，系统代理/环境变量/DNS 设置没被还原，导致网页打不开、DNS 异常、证书告警等。

- **覆盖范围**：WinINET 系统代理开关与地址、PAC 脚本、WPAD 自动检测、WinHTTP 系统代理、HTTP(S)/ALL 环境变量代理、DNS 缓存、hosts 文件检查、受信任根证书审查
- **不处理**：浏览器扩展代理（如 SwitchyOmega），需在浏览器内自行清理

## 三个脚本

| 脚本 | 类型 | 说明 |
|---|---|---|
| `exam\examination.bat` | 只读体检 | 不改任何设置。检查：代理开关、代理地址、PAC、WPAD、WinHTTP、环境变量、DNS 服务器、DNS 对比、hosts |
| `jiaqiang\ResetProxy-2.bat` | 一键重置 v2 | 7 步清理（备份→关代理→删残留→清 Connections→重置 WinHTTP→查代理进程→导证书列表），清理后做 8 项状态检测 |
| `final\ResetProxy-3.bat` | 一键重置 v3 | v2 增强版：额外清除并检测**环境变量代理残留**（HKCU 用户级 + HKLM 系统级注册表），共 8 步清理 + 9 项检测 |

## 修复的问题（三个脚本通用）

### 1. 延迟扩展吞字符（最严重）
`setlocal enabledelayedexpansion` 开启时 `!` 是特殊字符。脚本里 `if(!$a)`、`[!!]` 中的 `!` 被当成变量定界符配对，整段 PowerShell 命令被拦腰截断——DNS 对比永远输出残缺行。
**修复**：去掉 `enabledelayedexpansion`，`!var!` 改为 `%var%`（for 循环结果都在下一行消费，本就不需要延迟扩展）。

### 2. chcp 65001 + UTF-8 行截断
cmd 在 `chcp 65001` 下解析含中文的 .bat 有已知 bug：中文与 `(`、`]`、`-` 等 ASCII 符号相邻时随机断行，报"不是内部或外部命令"。
**修复**：全部改为 **GBK 编码 + `chcp 936`**（中文 Windows 批处理的标准做法，实测稳定）。

### 3. emoji 无法保存
✅⚠️ 是 Unicode 字符，GBK 字符集里不存在（这也是记事本保存 ANSI 时提示"该字符将丢失"的原因）。
**修复**：换成 `[OK]` / `[!!]` 标记。

### 4. 检测项误报"异常值"
注册表值不存在（如未设置 WPAD 自动检测）时变量为空，却落入"异常值"分支，每次运行都误报。
**修复**：增加第三分支——不存在时显示"不存在,默认关闭"。

### 5. WinHTTP 检查永远误报
netsh 输出到文件时写的是 UTF-8（与代码页无关），findstr 的中文模式永远匹配不上，导致"检测到代理"误报或乱码。
**修复**：改用 ASCII 特征 `://` 判断是否有代理地址；读 netsh 输出用 `Get-Content -Encoding UTF8`。

### 6. hosts 文件 BOM 泄漏
Windows 自带 hosts 文件带 UTF-8 BOM，`eol=#` 匹配不到注释行首，`# Copyright...` 注释行以乱码形式漏出。
**修复**：改用 PowerShell `-Encoding UTF8` 读取（自动剥离 BOM）。

### 7. if 块内英文括号
`(echo ...(默认关闭))` 括号配对错乱，报"此时不应有 )"。
**修复**：块内不用英文括号，改用全角（）或逗号。

### 8. 行尾损坏
文件行尾曾被工具写坏（`\r\r\n` 混合），cmd 会把多字节中文行乱切。
**修复**：统一为纯 CRLF 行尾。

## 使用说明

- 双击运行；自动申请管理员权限（弹 UAC 确认）
- 运行前自动备份到脚本所在目录：`ProxyBackup.reg`（代理注册表）、`EnvBackup.reg` / `SysEnvBackup.reg`（环境变量）、`hosts_backup.txt`（hosts）
- 恢复：双击对应的 .reg 文件即可还原
- `examination.bat` 是只读检测，可随时运行
- 清理后浏览器需重启才生效；环境变量变化需要重开已打开的终端/IDE

## 编辑注意事项（重要）

- 三个 .bat **必须保持：GBK(ANSI) 编码 + 首行 `chcp 936` + CRLF 行尾 + 无 emoji**
- 记事本保存时保持默认编码（中文系统 ANSI 即 GBK）；若弹出"Unicode 字符将丢失"警告，说明文件里有 GBK 装不下的字符（emoji 等），删除该字符或改存 UTF-8
- 不要用会自动转 UTF-8 的编辑器保存这些 .bat
