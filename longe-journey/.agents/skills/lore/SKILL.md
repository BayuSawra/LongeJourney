---
name: lore
description: Manage LongeJourney story canon and continuity. Use only when the task explicitly targets lore entries, story-canon facts, or continuity checks; do not trigger for routine development, timeline migration, or scene-writing work that only touches lore incidentally.
---

# Lore

维护 LongeJourney 的剧情连续性。所有剧情内容都必须与项目内唯一的 lore 正典保持一致。

## 加载规则

`docs/task_checkpoint.md` 已浓缩并登记的规则视为本 skill 指令已加载：命中已登记范围且对应条目未变更、阶段未切换时，直接复用，不重读本文、`lore/` 原文或 `references/` 模板。仅首次启用、阶段切换、相关规范变化，或需要创建/更新条目而查阅模板时，才重读对应部分。

## 正典来源

剧情唯一事实来源是项目根目录的 `lore/` 文件夹：

- `lore/INDEX.md`：全部条目索引与一句话摘要
- `lore/characters/<name>.md`：角色
- `lore/locations/<name>.md`：地点
- `lore/factions/<name>.md`：势力
- `lore/items/<name>.md`：物品
- `lore/events/<name>.md`：按时间顺序排列的事件
- `lore/plot-threads.md`：开放伏笔、已回收伏笔

条目模板见 `references/lore-schema.md`。

## 工作流程

执行迁移或已有明确计划的任务时，以 `docs/task_checkpoint.md` 的“下一步”为准，先推进实现；内容完成后按“校验与提交（终止式）”收尾。不要在动手前做全量 lore 重读/冲突重审。非 lore 任务（常规开发、文档整理、与正典无关的编辑）不触发正典校验。

1. 新增或修改 lore 条目、编写全新剧情内容前，先读取 `lore/INDEX.md` 及相关条目；已定稿的 timeline 迁移按 `docs/task_checkpoint.md` 的“下一步”先执行，提交前统一校验，不在动手前做全量重读。
2. 只检查本次变更涉及的增量范围（新增/修改条目及其直接依赖），核对：名字与拼写、年龄与状态、关系、所在地、当前时间、已知信息、物品归属。已登记过的范围不重读、不重推演。
3. 新事实一旦成为正典，立即更新对应条目，记录事实来源（如 `timelines/timeline1_0.dtl`），并同步更新索引。
4. 发现矛盾时不要擅自改写既有设定：指出冲突双方、引用来源，并给出最合理的解决方案，由用户确认后修改。
5. 时间推进后新增事件条目，并更新角色/地点状态与 `plot-threads.md`（伏笔埋设、回收）。

## 校验与提交（终止式）

校验不是每回合动作，而是内容完成后的最后一次收尾动作，每个提交周期只执行一轮：

1. 本回合没有修改任何 lore 相关文件时，不校验、不登记、不重读，直接继续或结束。
2. 内容完成后、提交前，统一运行一次 `tools/check_lore_canon.py`；索引需要同步时运行 `tools/update_lore_index.py`。
3. 校验通过后，仅当登记范围确需更新时写入登记，然后立即提交并结束，不重复校验。
4. 校验失败时，只修复脚本报出的问题并重新运行一次；仍未通过则停止并报告，不进入修复-校验循环。

## 约定

- 一个条目一个文件，文件名使用小写连字符（如 `alice-reed.md`）。
- 条目保持简短、只写事实；状态值只使用：`unknown`、`alive`、`dead`、`missing`、`sealed`、`destroyed`。
- 不删除已确立的事实；事实变化时用 `superseded_by:` 标记新条目并保留旧记录。
- 只修改 `lore/` 与剧情相关文件，不改动无关项目代码。
- 跨回合成本控制：任务开始时把本次相关规则缩成短清单写入 `docs/task_checkpoint.md`；读完即落盘，后续回合只读摘要，不再整读原文，只在阶段切换或需要特定规范时查清单。
- 检查登记：登记只发生在提交前，不当作每回合动作。`docs/task_checkpoint.md` 已登记且条目未变更、阶段未切换时直接沿用，不重读、不重推演、不重复登记；本回合无 lore 变更时不校验、不登记。确需登记时格式为 `[已检查] 范围=<范围> 结果=<结果> 登记=<YYYY-MM-DD HH:mm> 线程=<线程标识>`。

## 参考资料

- `references/lore-schema.md`：条目模板与字段定义，创建或更新条目时读取。
