# 任务检查点

## 当前任务

- 目标：`06_luyuan -> 07_maze -> 08_wife_room -> 09_ending` 链路
- 已完成：拆分方案定稿（`docs/WORK_PLAN.md` 阶段 4.1）；`07_maze_entry.dtl` 已创建、已登记 `project.godot`、已提交（`f6c9a37`）；`07_maze_left.dtl` 已创建、已登记 `project.godot`、已提交（`15b09ba`）；`07_maze_middle.dtl` 已创建、已登记 `project.godot`、已提交（`6574e80`）；`07_maze_right.dtl` 已创建、已登记 `project.godot`、已提交（`6554e3f`）；`08_wife_room.dtl` 已创建、已登记 `project.godot`、已提交
- 下一步：创建 `09_ending.dtl`
- 注意事项：英文文件名；中文只放显示文本；jump 目标必须是真实 timeline ID 或同文件 label；写完不逐条跑校验，提交前统一按 `docs/WORK_PLAN.md` 第 7 节校验

## 完成定义

- 每个分支文件最后都有明确下一跳，ending 统一结束整个 ending 链路
- 从 `06_luyuan` 出发的整条链可从头走到尾
- 所有 jump/选择目标都指向真实 timeline ID 或同文件 label

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
- 后续回合/新线程先读本清单；命中已登记范围且对应文件未变更、阶段未切换时直接沿用，不重读、不重推演。
- 中途只在切换阶段或需要特定规范时查本清单；提交前做一次统一校验。
- 提交前运行 `tools/check_lore_canon.py`，并按 `docs/WORK_PLAN.md` 第 7 节规范校验；校验失败不提交。
