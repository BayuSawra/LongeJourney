---
name: lore
description: Manage story continuity for the LongeJourney project: maintain the canonical story bible (characters, locations, factions, items, timeline, plot threads, established facts) and keep dialogue, Dialogic timelines (.dtl), scenes, and worldbuilding consistent. Use when writing or editing story content, checking continuity, tracking foreshadowing and payoffs, or resolving lore contradictions.
---

# Lore

维护 LongeJourney 的剧情连续性。所有剧情内容都必须与项目内唯一的 lore 正典保持一致。

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

1. 编写或修改任何剧情内容前（Dialogic `.dtl` 时间线、对话、场景、角色台词），先读取 `lore/INDEX.md`，再读取本次涉及的角色、地点、事件、伏笔条目。
2. 对照正典检查：名字与拼写、年龄与状态、关系、所在地、当前时间、已知信息、物品归属。
3. 新事实一旦成为正典，立即更新对应条目，记录事实来源（如 `timelines/timeline1_0.dtl`），并同步更新索引。
4. 发现矛盾时不要擅自改写既有设定：指出冲突双方、引用来源，并给出最合理的解决方案，由用户确认后修改。
5. 时间推进后新增事件条目，并更新角色/地点状态与 `plot-threads.md`（伏笔埋设、回收）。

## 约定

- 一个条目一个文件，文件名使用小写连字符（如 `alice-reed.md`）。
- 条目保持简短、只写事实；状态值只使用：`unknown`、`alive`、`dead`、`missing`、`sealed`、`destroyed`。
- 不删除已确立的事实；事实变化时用 `superseded_by:` 标记新条目并保留旧记录。
- 只修改 `lore/` 与剧情相关文件，不改动无关项目代码。

## 参考资料

- `references/lore-schema.md`：条目模板与字段定义，创建或更新条目时读取。
