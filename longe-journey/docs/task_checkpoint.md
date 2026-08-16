# 任务检查点

## 当前任务

- 目标：`06_luyuan -> 07_maze -> 08_wife_room` 链路
- 已完成：拆分方案定稿（`docs/WORK_PLAN.md` 阶段 4.1）
- 下一步：创建 `07_maze_entry.dtl`，出口 `jump 07_maze_left`
- 注意事项：英文文件名；中文只放显示文本；写完不逐条跑校验，提交前统一按 `docs/WORK_PLAN.md` 第 7 节校验

## 完成定义

- 每个分支文件最后都有明确下一跳，迷宫出口统一为 `jump 08_wife_room`
- 从 `06_luyuan` 出发的整条链可从头走到尾
- 所有 jump/选择目标都指向真实 timeline ID 或同文件 label

## 相关文档

- `docs/07_maze_sources.md`：07_maze 场景摘要，后续回合只读此文件，不整读原文
- `docs/WORK_PLAN.md`：阶段 4.1 的拆分与验证要求
- `tools/_twine_extract.txt`：原始 Twine 文本（大文件，不整读）

## 本次规则清单 / 校验速查

- 规则已在开头读一次并浓缩进本清单；后续只查本清单，不重读 `SKILL.md` / `WORK_PLAN.md` 原文。
- 本次是 timeline 迁移，不做 lore 逐条规则重查。
- 已确认：无 `lore/` 修改 → 不跑 `tools/update_lore_index.py`；后续不再重新推演。
- 已确认：入口内容、`project.godot` 登记、`06_luyuan` 出口 `jump 07_maze_left` 已验证；后续不重复核对。
- 中途只在切换阶段或需要特定规范时查本清单；提交前做一次统一校验。
- 提交前运行 `tools/check_lore_canon.py`，并按 `docs/WORK_PLAN.md` 第 7 节规范校验；校验失败不提交。
