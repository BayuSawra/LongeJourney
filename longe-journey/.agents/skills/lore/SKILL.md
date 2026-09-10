---
name: lore
description: Migration-only skill for importing and establishing LongeJourney story lore during the project migration phase. This skill is NOT for normal game development or post-migration maintenance. Once migration is complete, DO NOT activate or use this skill unless the user explicitly asks to perform migration-related lore work.
---
# Lore Migration

本 Skill 仅用于 LongeJourney 项目的“迁移阶段”。

它的职责是：

- 从旧项目提取剧情正典
- 整理旧项目 Lore
- 建立新的 lore/ 目录
- 检查迁移过程中的正典一致性
- 将旧项目剧情事实迁移到新项目

---

# 重要：迁移完成后停止使用

当用户明确表示：

> 游戏迁移已经完成

或者当前项目已经进入正常开发/修改阶段时：

**立即停止使用本 Skill。**

此后不得因为以下任何任务重新激活本 Skill：

- 修改代码
- 修改场景
- 修改 UI
- 修改 Timeline
- 修改 Dialogic
- 修改 Dialogue Manager
- 修改角色对话
- 修改剧情表现
- 修改游戏逻辑
- 修复 Bug
- 添加功能
- 删除功能
- 调整资源
- 普通剧情修改

即使这些任务涉及 Lore 中已经存在的角色、地点、事件，也不得使用本 Skill。

---

# 迁移阶段的结束条件

当满足以下任一条件：

1. 用户明确表示“迁移完成”
2. 用户明确表示“已经迁移好了”
3. 用户开始要求进行正常游戏开发/修改，而不是继续迁移

则视为：

> **Lore Migration Phase 已结束。**

从此以后，本 Skill 默认永久停止。

除非用户明确说：

> “重新进行 Lore 迁移”
> “继续迁移 Lore”
> “重新检查迁移结果”

否则不要使用本 Skill。

# Lore

维护 LongeJourney 的剧情正典与连续性。

`lore/` 是 LongeJourney 的唯一正式正典来源，但它是一个**按需读取的知识库**，不是每个任务或每个线程都必须重新加载的上下文。

核心原则：

> **只有需要 Lore 时才读取 Lore；已经读取并确认的信息视为当前任务缓存，不重复读取。**

---

## 触发门禁

本 Skill 默认不激活 Lore 读取。

只有满足以下任一条件时，才允许读取 `lore/`：

1. 用户明确要求：
   - 查询 Lore
   - 查询正典
   - 检查剧情连续性
   - 检查设定冲突
   - 确认角色、地点、势力、物品或事件的既有设定
   - 新增 Lore 条目
   - 修改 Lore 条目
   - 将新剧情事实正式纳入正典
   - 检查某个事实是否与正典冲突

2. 当前任务必须依赖某个正典事实，但该事实没有出现在：
   - 当前用户消息
   - 当前对话上下文
   - `docs/task_checkpoint.md` 已登记摘要
   - 当前任务已经读取并缓存的信息

3. 用户明确要求进行全量或批量正典核验。

除此之外，不读取 `lore/`。

### 以下任务默认不触发 Lore

- 普通剧情创作
- 场景描写
- 对白编写
- 任务设计
- 世界观扩写
- 根据当前上下文继续写剧情
- 普通代码开发
- Timeline 迁移
- 文档整理
- UI、系统、工具开发
- 与正典无关的项目维护

**仅仅因为任务中出现已有角色、地点、势力、物品或事件，不构成 Lore 触发条件。**

如果当前上下文已经提供完成任务所需的设定，直接使用，不重新读取 Lore。

---

# 正典来源

剧情唯一正式事实来源是项目根目录的 `lore/` 文件夹：

- `lore/INDEX.md`：全部条目索引与一句话摘要
- `lore/characters/<name>.md`：角色
- `lore/locations/<name>.md`：地点
- `lore/factions/<name>.md`：势力
- `lore/items/<name>.md`：物品
- `lore/events/<name>.md`：按时间顺序排列的事件
- `lore/plot-threads.md`：开放伏笔、已回收伏笔

条目模板：

- `references/lore-schema.md`

### 正典来源不等于自动读取

`lore/` 是正式正典来源，但不意味着每个任务都必须访问它。

如果当前上下文已经提供完成任务所需的正典事实：

> 直接使用当前信息，不重新读取 Lore。

只有当任务需要一个当前上下文中不存在的正典事实时，才读取 Lore。

---

# 加载规则

Lore 使用**按需加载 + 任务内缓存**机制。

## 1. 优先使用已有上下文

读取顺序：

1. 当前用户消息
2. 当前对话已经提供的信息
3. `docs/task_checkpoint.md` 中已经登记的 Lore 摘要
4. 当前任务已经读取并缓存的 Lore
5. `lore/INDEX.md`
6. 与问题直接相关的具体 Lore 条目
7. 仅在明确要求全量核验时进行更大范围读取

如果前面的信息已经足够完成任务，停止读取。

---

## 2. 最小读取原则

只读取解决当前问题所需的最小范围。

例如：

需要确认 Alice 的年龄：

只读取：

`lore/characters/alice.md`

不要因此读取：

- 所有角色
- 所有地点
- 所有事件
- `plot-threads.md`

需要确认 Alice 与 Bob 的关系：

读取：

- `alice.md`
- `bob.md`

必要时再读取直接相关事件。

不要因为“可能存在隐藏冲突”而主动扫描整个 Lore。

---

## 3. INDEX.md 的使用规则

`lore/INDEX.md` 主要用于**定位条目**，不是每次 Lore 任务的强制入口。

如果已经知道目标文件：

```text
lore/characters/alice.md