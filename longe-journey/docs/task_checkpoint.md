# 任务检查点

## 当前任务

- 目标：阶段 9：lore 运行时只读设定数据
- 已完成：9.1 lore 运行时导入（`scripts/autoload/lore_runtime.gd`：读取 `lore/INDEX.md` 与正典条目，解析索引条目并按 canon/plot-thread 章节匹配，提供 `get_all_entries()`/`get_category()`/`get_detail()`/`has_entry()`，返回值为深拷贝，运行时数据只读；已在 `project.godot` 注册为 `LoreRuntime` 自动加载单例）
- 下一步：9.2.2 图鉴主界面与分类列表
- 注意事项：新线程只读本文件“下一步”后直接执行；一个线程只做一个执行块；动工前先写完成定义；一块完成即提交；英文文件名；中文只放显示文本

## 完成定义

- 一个执行块完成即提交，提交信息写明阶段与块号（如 `feat(phase8): ...`）
- 存档覆盖 `GameState`、当前 timeline 与场景；读档可恢复
- 设置覆盖文字速度、音量、全屏
- [完成] 9.2.1 图鉴数据模型与分类索引：`LoreRuntime` 提供 `get_index()`/`get_categories()`/`search()`/`search_by_category()`，按分类与标题稳定排序，支持对标题/摘要/分类/路径/字段/已知设定的大小写不敏感检索，返回均为深拷贝，运行时数据保持只读；9.2.1 为纯数据层，不含 UI。

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
