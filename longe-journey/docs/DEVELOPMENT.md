# 开发底座

## 环境与入口

Windows、Python 3.10+、PowerShell，验证固定使用 Godot **4.7 standard**。
保留项目 4.7 / GL Compatibility 配置，不要求 .NET SDK。资源导入固定串行，避免本机冷导入字体时观察到的并发崩溃。

在仓库根目录首次安装引擎（已存在的目录会明确报错，不覆盖）：

```powershell
$env:GODOT_PATH = & ./longe-journey/tools/setup_env.ps1
```

后续会话直接指定已安装的引擎：

```powershell
$env:GODOT_PATH = "$PWD/.local-tools/godot-4.7/Godot_v4.7-stable_win64_console.exe"
python -m unittest discover -s longe-journey/tools/tests -v
if ($LASTEXITCODE -ne 0) { throw "Tool tests failed" }
python longe-journey/tools/verify.py
if ($LASTEXITCODE -ne 0) { throw "Verification failed" }
```

编辑器打开 `longe-journey/project.godot`。gdUnit4 已注册为编辑器插件。
**存档/设置集成测试只通过 verify.py 运行**，不直接从原项目运行测试套件。

## 2.0 分支的 Godot 4.7 升级

- 固定引擎：`4.7.stable.official.5b4e0cb0f`，Windows standard；安装器与 CI 使用相同 SHA512。
- 图形编辑器：仓库 `.local-tools/godot-4.7/Godot_v4.7-stable_win64.exe`。
- 保留 Dialogic、gdUnit4、Godot .NET MCP、Longe Lore Tools 的现有版本和本地补丁。
- 4.7 验证：54 项 Python 工具测试、50 项 Godot 回归、冷导入与启动冒烟通过。
- MCP 图形验收：15 个工具、场景分析、主场景运行/停止、实时错误回传及编辑器正常退出通过。
- MCP 的 4.7 接口兼容补丁见 `THIRD_PARTY.md`；无需 .NET SDK。

## 验证内容

- 单语言单 PO 本地化检查（key/占位符/审核戳/资源引用）、lore 正典检查、timeline 注册/jump/主线可达性检查、资源引用扫描与一致性验证。
- 复制源码到临时目录，从无 `.godot` 缓存状态导入。
- gdUnit4 回归：双向变量同步、结局、存档、自动存档、设置、图鉴和场景。
- 启动真实入口主菜单的 120 个物理帧 headless 冒烟测试，释放场景后等待音频清理。
- 每步超时/非零退出/引擎错误日志均失败；JUnit 缺失、空跑、失败、跳过或 flaky 均失败。

临时项目使用独立 `user://`，不改真实存档、设置及原项目导入缓存。
CI 副本禁用 MCP **编辑器**插件，避免启动开发 HTTP 服务；原项目配置与运行时桥保持不变。
报告写入 `longe-journey/reports/verify-*/`，包含日志、JUnit/HTML、资源报告与 summary.json。
资源 orphan 数量只是报告，不把历史数字锁成错误门槛。

`.github/workflows/verify.yml` 在 Windows 执行同一套检查并上传报告。
这不是画面、音频和全剧情人工验收；相关改动仍需编辑器实际游玩。

## 迁移边界

采用模板的 gdUnit4、环境固定和统一验证/CI 思路。
不迁移 zfoo、GodotFramework、EventBus 示例、模板测试示例、批量 skills；
不替换 GameState / SaveManager / SettingsManager 等业务单例，不升级渲染后端。
来源与必要兼容补丁见 `THIRD_PARTY.md`。旧阶段计划只作为历史背景，以当前用户任务为准。


## MCP 集成验收（Windows 图形桌面）

在游戏根目录运行：

```powershell
$env:PYTHONUTF8 = "1"
python tools/verify_mcp.py --godot <Godot-4.7-console.exe绝对路径>
```

测试复制工程、隔离用户数据并使用临时本机端口，不操作真实存档。
覆盖冷导入、HTTP 握手、15 个工具暴露、项目盘点、场景校验/分析、主场景运行/停止、
错误回传与停止后读取；检查实时 debugger 内存事件，不能用已有文件回传冒充成功。
报告写入 `reports/mcp-*`（不提交）；编辑器日志错误或退出泄漏均判失败。
此项需要 Windows 图形桌面，独立于现有 headless CI。

验收使用 console 程序检查版本/导入，图形阶段直接跟踪同目录实际编辑器 `.exe`，
避免 console 启动器与子进程退出状态混淆。退出前保存隔离副本中的场景，再走编辑器
正常关闭流程；不修改真实工程、不用强退获得通过。超时强制清理仍判失败。

## 本地化

中英文文案均集中在 `localization/<locale>.po`。编辑、新增语言、严格校验及 V3 存档兼容边界见 `LOCALIZATION.md`。
