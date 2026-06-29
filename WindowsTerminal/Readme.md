# Windows Terminal / 智能终端 右键菜单安装器

把 **Windows Terminal** 或微软的官方 fork **智能终端 (IntelligentTerminal)** 集成到 Windows 资源管理器右键菜单，自动列出 `settings.json` 中所有可见 Profile 并使用各自图标。

基于 [lextm/windowsterminal-shell](https://github.com/lextm/windowsterminal-shell) 改造，增加：

- `-Edition simple|intelligent` 参数，**两套右键菜单可共存**
- 智能终端 AI 侧栏伪 Profile (`Agent Pane`) 自动跳过
- Default 布局卸载时连父级 `ContextMenus\Menu*` 一并删除，无空壳残留

---

## 1. 环境要求

| 项 | 要求 |
| --- | --- |
| Windows | Windows 10 1809+ / Windows 11 |
| PowerShell | **7+ (pwsh)**，脚本里 `#Requires -Version 6` 已强制 |
| 权限 | **管理员**，脚本里 `#Requires -RunAsAdministrator` 已强制 |
| 不支持 | Microsoft Store 版的 PowerShell |
| 前置 | 对应终端 (Windows Terminal / 智能终端) 至少启动过一次，确保 `settings.json` 已生成 |

---

## 2. 快速上手

打开**以管理员身份运行**的 `pwsh`，切到本目录。

### 2.1 安装 Windows Terminal 菜单

```powershell
# 默认布局 (推荐) —— 右键 / 右键空白处会出现一个一级菜单,内含所有 Profile 子菜单
pwsh -File .\TerminalMenuGenerater.ps1

# 等价完整写法
pwsh -File .\TerminalMenuGenerater.ps1 -Edition simple -Layout Default
```

### 2.2 安装智能终端菜单

```powershell
pwsh -File .\TerminalMenuGenerater.ps1 -Edition intelligent
```

> 两个 Edition **可同时安装**，菜单注册表键名不同 (`MenuTerminal` vs `MenuIntelligentTerminal`)，互不干扰。

### 2.3 卸载

参数必须和当初安装时一致 (Edition + Layout)：

```powershell
pwsh -File .\Uninstall.ps1                                      # 卸 WT 默认布局
pwsh -File .\Uninstall.ps1 -Edition intelligent                 # 卸智能终端默认布局
pwsh -File .\Uninstall.ps1 -Edition intelligent -Layout Mini    # 卸智能终端 Mini 布局
```

---

## 3. 参数说明

### `TerminalMenuGenerater.ps1` / `Uninstall.ps1` 通用参数

| 参数 | 取值 | 默认 | 说明 |
| --- | --- | --- | --- |
| `-Layout` | `Default` / `Flat` / `Mini` | `Default` | 菜单布局，见 §4 |
| `-Edition` | `simple` / `intelligent` | `simple` | 目标终端：Windows Terminal / 智能终端 |
| `-PreRelease` | switch | 关 | 仅 `simple` 有效，扫描 Windows Terminal Preview 包；`intelligent` 无 Preview 通道，传入会 warning 后忽略 |

### 三种布局的差异

| Layout | 右键体验 | 注册表落点 |
| --- | --- | --- |
| **Default** | 一级菜单 "在此处打开 ..."，鼠标悬停展开所有 Profile 子菜单；另有一个 "以管理员身份打开 ..." 一级菜单 | `Directory\shell\Menu*` + `Directory\ContextMenus\Menu*` |
| **Flat** | 每个 Profile 直接平铺到右键一级菜单 ("PowerShell here", "PowerShell here as administrator" 等) | `Directory\shell\Menu*_{guid}` |
| **Mini** | 只有两个一级菜单 ("在此处打开 ..." / "以管理员身份打开 ...")，不展开 Profile | `Directory\shell\Menu*Mini` |

---

## 4. 安装位置一览

| 资源 | 路径 |
| --- | --- |
| 注册表 (Windows Terminal) | `HKCU\SOFTWARE\Classes\Directory\(Background\)shell\MenuTerminal[Admin][Mini]` |
| 注册表 (智能终端) | `HKCU\SOFTWARE\Classes\Directory\(Background\)shell\MenuIntelligentTerminal[Admin][Mini]` |
| 图标 / VBS 缓存 | `%LOCALAPPDATA%\Microsoft\WindowsApps\Cache\` |
| WT settings.json | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |
| 智能终端 settings.json | `%LOCALAPPDATA%\Packages\Microsoft.IntelligentTerminal_8wekyb3d8bbwe\LocalState\settings.json` |

注：脚本只写 HKCU (HKEY_CURRENT_USER)，不污染 HKLM。

---

## 5. 智能终端的 Agent Pane 处理

智能终端把 AI 侧栏注册成了 GUID 为 `{fd19208a-412b-4857-8a2d-9ca592b4b16e}` 的常规 Profile，但它不是 shell 会话，从右键启动没有意义。

脚本在 `Get-EditionMeta` 的 `intelligent` 分支里把这个 GUID 写进 `ExcludeProfileGuids` 黑名单，安装时自动跳过并输出：

```
Skip built-in profile 'Agent Pane' ({fd19208a-412b-4857-8a2d-9ca592b4b16e}).
```

未来如果智能终端再注册其他类似的"伪 Profile"，直接把 GUID 追加到这个数组即可：

```powershell
# TerminalMenuGenerater.ps1 内
ExcludeProfileGuids = @(
    '{fd19208a-412b-4857-8a2d-9ca592b4b16e}',   # Agent Pane
    '{...}'                                     # 其他伪 Profile
)
```

---

## 6. 常见问题

### Q1：跑脚本提示 "Please execute uninstall.old.ps1 to remove previous installation"

历史遗留：脚本检测到 HKCR (老安装位置) 还有 `MenuTerminal` 项。先跑：

```powershell
pwsh -File .\Uninstall.old.ps1
```

注意：`Uninstall.old.ps1` 仅清理 `HKEY_CLASSES_ROOT\Directory\shell\MenuTerminal` 等旧位置，不接受 `-Edition` 参数（智能终端无历史遗留）。

### Q2：菜单装好了但右键看不到

- 重启 `explorer.exe`：任务管理器找到 "Windows 资源管理器" → 重新启动
- 或注销重新登录

### Q3：图标都是 wt 主图标，没有各 Profile 自己的图标

通常是 `settings.json` 里某些 Profile 的 `icon` 字段写了无效路径或不支持的协议。重新跑脚本前确认 Profile 的 `icon` 是以下之一：
- 本地绝对路径 (`.png` / `.ico`)
- `ms-appdata:///Roaming/...` 或 `ms-appdata:///Local/...`
- `ms-appx:///...`
- 带环境变量的路径 (例如 `%LOCALAPPDATA%\...`)

### Q4：智能终端的 `wtai.exe` 启动 Profile 时报错

脚本假设 `wtai.exe` 兼容 `wt.exe` 的 `-p` 和 `-d` 参数。如果智能终端将来改了 CLI，需要相应修改 `Get-EditionMeta` 的 `Executable` 字段或菜单命令模板。

### Q5：卸载只清了菜单，缓存目录还在

是设计如此。`%LOCALAPPDATA%\Microsoft\WindowsApps\Cache\` 下的：
- `wt.ico` / `wt.png` —— 由 `-Edition simple` 的卸载清理
- `wtai.ico` / `wtai.png` —— 由 `-Edition intelligent` 的卸载清理
- `helper.vbs` 和各 `{guid}.ico` —— 两个 Edition 共享，**不**自动清理

如果两个 Edition 都已卸载、想彻底清干净：

```powershell
Remove-Item "$Env:LOCALAPPDATA\Microsoft\WindowsApps\Cache" -Recurse -Force
```

---

## 7. 文件清单

| 文件 | 说明 |
| --- | --- |
| `TerminalMenuGenerater.ps1` | 安装脚本 |
| `Uninstall.ps1` | 卸载脚本（对应当前版本写入的 HKCU 注册表） |
| `Uninstall.old.ps1` | 旧版清理脚本（HKCR 历史遗留，仅 simple Edition） |
| `Readme.md` | 本文档 |
