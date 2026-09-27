# 任务检查点

## 当前开发底座（2026-09-13）

- 已选择性迁入 gdUnit4；新增固定环境安装、隔离验证、业务回归和 Windows CI。
- 本地验证通过：17 项 Python 工具测试、16 项游戏回归、lore/资源检查、无缓存导入及主菜单冒烟。
- 开发入口见 `DEVELOPMENT.md`；依赖和兼容补丁见 `THIRD_PARTY.md`。
- 未提交、未推送，GitHub Actions 尚未远端执行。
- 下述阶段记录仅作历史背景；旧“直接执行下一步/自动提交”约定不作为当前授权。

## 历史任务

- 目标：阶段 9：lore 运行时只读设定数据
- 已完成：9.1 lore 运行时导入（`scripts/autoload/lore_runtime.gd`：读取 `lore/INDEX.md` 与正典条目，解析索引条目并按 canon/plot-thread 章节匹配，提供 `get_all_entries()`/`get_category()`/`get_detail()`/`has_entry()`，返回值为深拷贝，运行时数据只读；已在 `project.godot` 注册为 `LoreRuntime` 自动加载单例）
- [完成] 9.2.2 图鉴主界面与分类列表：图鉴主界面与地点/事件/角色等分类入口及列表展示（scenes/lore_browser.tscn + scripts/lore_browser.gd，含返回/关闭/空态/字号适配；主菜单脚本已加载，9.2.5 负责游戏内 HUD 接入）
- 注意事项：新线程只读本文件“下一步”后直接执行；一个线程只做一个执行块；动工前先写完成定义；一块完成即提交；英文文件名；中文只放显示文本

## 完成定义

- 一个执行块完成即提交，提交信息写明阶段与块号（如 `feat(phase8): ...`）
- 存档覆盖 `GameState`、当前 timeline 与场景；读档可恢复
- 设置覆盖文字速度、音量、全屏
- [完成] 9.2.1 图鉴数据模型与分类索引：`LoreRuntime` 提供 `get_index()`/`get_categories()`/`search()`/`search_by_category()`，按分类与标题稳定排序，支持对标题/摘要/分类/路径/字段/已知设定的大小写不敏感检索，返回均为深拷贝，运行时数据保持只读；9.2.1 为纯数据层，不含 UI。
- [完成] 10.1.1 统一 CLI/接口与输入输出格式、路径约定：命令入口为 tools/lj_cli.py，子命令 check-lore/update-index，支持 --root 参数化项目根，输入输出与目录约定写入 tools/README.md；旧脚本保留为兼容包装。
- [完成] 9.2.3 图鉴搜索与分类筛选：图鉴列表支持关键词搜索与分类筛选，空查询/空结果/清除搜索/返回状态一致。

## 相关文档

- `docs/07_maze_sources.md`：07_maze 场景摘要，后续回合只读此文件，不整读原文
- `lore/events/wife-room-reunion.md`、`lore/locations/wife-room.md`：09 相关 lore
- `docs/WORK_PLAN.md`：阶段 4.1 的拆分与验证要求
- `tools/_twine_extract.txt`：原始 Twine 文本（大文件，不整读）

## 本次规则清单 / 校验速查

- 规则已在开头读一次并浓缩进本清单；后续只查本清单，不重读 `SKILL.md` / `WORK_PLAN.md` 原文。
- 本次是 timeline 迁移，不做 lore 逐条规则重查。
- `[已检查] 范围=lore正典无修改 结果=不跑 tools/update_lore_index.py 登记=2026-08-17 23:54 线程=主线程`
- `[已检查] 范围=08_wife_room 内容/project.godot登记/07_maze 出口 jump 08_wife_room 结果=通过 登记=2026-08-17 23:54 线程=主线程`
- `[已检查] 范围=全链 jump 一致性（06_luyuan -> 03_crossroads -> 06_luyuan -> 07_maze_entry -> 07_maze_left/right -> 07_maze_middle -> 07_maze_exit -> 08_wife_room -> 09_ending，含 project.godot 登记） 结果=通过 登记=2026-08-18 线程=主线程`
- `[已检查] 范围=07/08/09 timeline 变量/标签/jump 迁移（07_maze_entry/middle/right/exit） 结果=通过 登记=2026-08-18 线程=主线程`
- `[已检查] 范围=阶段6背景资源/切换点/BGM占位 结果=通过 登记=2026-08-19 19:21 线程=主线程`
- `[已检查] 范围=Phase 7 统一文字速度/打字机跳过/淡入淡出/选项动画 结果=通过 登记=2026-08-19 线程=主线程`
- `[已检查] 范围=8.2.1 save_manager.gd 槽位数据结构与存储层（diff 通读） 结果=通过 登记=2026-08-22 线程=主线程`
- `[验证] Godot 4 运行时未找到（Get-Command godot*、Program Files/用户目录深度 3 均无结果），未做 headless smoke test；风险点：`DirAccess.dir_exists_absolute()` 传 `user://` 路径，找到运行时后需实测保存/读取/get_slots/重命名/删除`
- `[已检查] 范围=8.2.2 存档 UI 静态检查 结果=通过 登记=2026-08-22 线程=主线程`
- 后续回合/新线程先读本清单；命中已登记范围且对应文件未变更、阶段未切换时直接沿用，不重读、不重推演。
- 中途只在切换阶段或需要特定规范时查本清单；提交前做一次统一校验。
- 提交前运行 `tools/check_lore_canon.py`，并按 `docs/WORK_PLAN.md` 第 7 节规范校验；校验失败不提交。
- [已检查 范围=8.2.3 读档 UI 静态检查 结果=通过 登记=2026-08-22 线程=主线程]
- [已检查 范围=8.2.4 自动存档触发点 结果=通过 登记=2026-08-22 线程=主线程]
- [已检查 范围=8.2.5 存读档与场景导航闭环 结果=通过 登记=2026-08-22 线程=主线程]
- [已检查 范围=8.5 主菜单设置/退出接入 结果=通过 登记=2026-08-23 线程=主线程]
- [验证] 范围=9.2.2 图鉴主界面与分类列表 结果=通过 登记=2026-08-23 线程=主线程（静态检查：唯一节点名、分类/详情/返回/空态逻辑、主菜单加载引用；Godot 运行时未找到，未做 headless smoke test）
- [验证] 范围=9.2.5 场景/HUD 集成验证 结果=通过 登记=2026-08-23 线程=主线程（静态核对：HUD 入口加载图鉴，图鉴关闭仅 queue_free() 保留场景状态；Godot headless 冒烟启动通过）
- [验证] 范围=9.3 图鉴接入 lore/INDEX.md 与 canon 校验 结果=通过 登记=2026-08-23 线程=主线程（tools/check_lore_canon.py 退出码 0；LoreRuntime 运行时读取 lore/INDEX.md 并按 canon 条目/plot-threads 解析；图鉴入口 scripts/lore_browser.gd 使用 LoreRuntime；Godot headless 冒烟通过）
- [验证] 范围=9.2.3 图鉴搜索与分类筛选 结果=通过 登记=2026-08-23 线程=主线程（静态检查：search/分类过滤/清空/返回与空态逻辑一致；Godot 运行时未找到，未做 headless smoke test）
- [验证] 范围=10.1.4b 资源引用分析 结果=通过 登记=2026-08-23 线程=主线程（输出 docs/resource_references.json，引用数 57，未解析 22）

- [验证] 范围=10.1.4c 资源引用校验器 结果=通过 登记=2026-08-23 线程=主线（输出 docs/resource_validation.json，与手工抽查一致）
- [验证] 范围=10.1.4d 资源导入器 结果=通过 登记=2026-08-23 线程=主线（Godot headless --import 退出码 0；校验 missing=0 inconsistency=0 orphan=13）
- [验证] 范围=10.1.4e 资源导出/备份 结果=通过 登记=2026-08-23 线程=主线（导出 40；往返 passed；校验 passed；Godot headless --import 完成 reimport，环境类退出警告不影响资源校验）
- [验证] 范围=10.2 备份目录规范 结果=通过 登记=2026-08-23 线程=主线（备份输出 backups/resources/<时间戳>/；命名 yyyyMMdd-HHmmss；manifest 字段与脚本输出一致；保留最近 3 份、脚本不自动清理；验证输出 roundtrip=passed validation=passed）
- [验证] 范围=10.3 往返验证 结果=通过 登记=2026-08-23 线程=主线（导出 40；roundtrip=passed；validation=passed；备份 backups/resources/20260823-232730）
- [验证] 范围=10.4 文档收尾 结果=通过 登记=2026-08-24 线程=主线（docs/Phase0_Content_Tools.md 与 tools/README.md 已记录脚本用法；备份 backups/resources/<时间戳>/；命名 yyyyMMdd-HHmmss；保留最近 3 份且脚本不自动清理；10.3 结果：导出 40；roundtrip=passed；validation=passed；备份 backups/resources/20260823-232730）


## 2026-09-13 MCP 最小修复验收

- 已修复：项目盘点空结果、UID 依赖误报、场景节点/脚本统计、debugger 消息前缀契约。
- 补充：原子失败透传、加载器重建/退出循环引用释放、Dialogic 两个 UndoRedo 析构释放。
- Python 工具测试 17 项通过；`verify.py` 25 项通过，含 MCP 回归 9 项。
- 图形 MCP 功能检查通过：15 工具、盘点非零、主菜单 12 节点/1 脚本、运行/停止、
  实时 debugger 内存事件与停止后错误读取。测试使用复制工程和隔离用户目录。
- **当时完整 MCP 验收失败（已由下节修复）**：编辑器退出出现 209 个资源残留和访问冲突退出码
  `3221225477`。根因未确认，不判通过；不以停用插件或忽略日志绕过。
- 本地证据：`reports/verify-7c229dcedf49/summary.json`、
  `reports/mcp-45395b905842/summary.json`、`live-events.json`、`editor.log`。
- 后续优先排查图形编辑器退出生命周期；不扩大为 template 整体替换。


## 2026-09-13 编辑器退出问题关闭

- gdUnit 报告 writer 析构释放自建 Panel；RPC 服务显式预加载两个消息子类，
  消除固定 Godot 4.6.2 图形编辑器的脚本资源残留与退出访问冲突。
- 仅改 gdUnit 两处；未采用诊断期间的全局缓存清空、命令类型改写、停用插件或引擎升级。
- MCP 验收直接跟踪实际编辑器进程，退出前保存隔离副本场景并正常关闭；失败检查保留。
- Python 工具测试 **20 项通过**；`verify.py` **27 项通过**，包括新增 writer 所有权与 RPC 分发回归。
- 完整 MCP 验收连续两次通过：15 工具、112 场景/617 脚本、菜单 12 节点/1 脚本、
  主场景运行/停止、实时 debugger 内存事件、停止后错误读取；编辑器退出码均为 **0**，无错误/退出泄漏。
- 证据：`reports/verify-b1d1f8b752c0/summary.json`、
  `reports/mcp-e74aa93437c4/summary.json`、`reports/mcp-be043f6051ff/summary.json`。
- 全部验证使用隔离项目和用户目录；未自动提交或推送。
