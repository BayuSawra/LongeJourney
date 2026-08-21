# 任务检查点

## 当前任务

- 目标：阶段 8：存档 / 历史 / 设置
- 已完成：阶段 7 收尾（统一文字速度/打字机跳过/淡入淡出/选项动画）；`docs/WORK_PLAN.md` 已将阶段 8/9/10 拆成 commit 级执行块并加入防空转规则
- 下一步：8.1 存档数据结构/序列化（`GameState` + 当前 timeline/场景，可写入可恢复）
- 注意事项：新线程只读本文件“下一步”后直接执行；一个线程只做一个执行块；动工前先写完成定义；一块完成即提交；英文文件名；中文只放显示文本

## 完成定义

- 一个执行块完成即提交，提交信息写明阶段与块号（如 `feat(phase8): ...`）
- 存档覆盖 `GameState`、当前 timeline 与场景；读档可恢复
- 设置覆盖文字速度、音量、全屏

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
- 后续回合/新线程先读本清单；命中已登记范围且对应文件未变更、阶段未切换时直接沿用，不重读、不重推演。
- 中途只在切换阶段或需要特定规范时查本清单；提交前做一次统一校验。
- 提交前运行 `tools/check_lore_canon.py`，并按 `docs/WORK_PLAN.md` 第 7 节规范校验；校验失败不提交。
