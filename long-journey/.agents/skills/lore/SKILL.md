---
name: lore
description: >-
  Maintains LongeJourney canon files under lore/. Use only when the user
  explicitly asks to query, add, edit, or validate lore, 正典, or story canon.
  Do not use for code, UI, scenes, timelines, dialogue, bugs, or general
  game development.
disable-model-invocation: true
---

# Lore

`lore/` 是剧情正典。本 Skill **禁止自动启用**；用户没有点名查/改正典时，不要读本文件、不要读 `lore/`。

## 防空转 / 防压缩

每个对话对本文件只读一次。读完立刻干活，禁止再读 SKILL.md。

禁止为了“判断要不要用 Lore”去读 `docs/task_checkpoint.md`、`lore/INDEX.md` 或任何条目。没有明确正典任务就停。

单次任务上限：

1. 不知道文件名时，才读 `lore/INDEX.md`（一次）
2. 只读当前问题直接相关的条目，通常 1–3 个文件
3. 不要全库扫描，不要因“可能有隐藏冲突”扩大读取
4. 改完最多跑一次 `tools/check_lore_canon.py`
5. `INDEX.md` 过期时最多跑一次 `tools/update_lore_index.py`
6. 校验失败：只修报告项，再跑一次，然后停。禁止校验循环

本轮没有改 lore 文件：不要校验、不要写日志、不要重读。

## 目录

- `lore/INDEX.md` — 定位用，不是强制入口
- `lore/characters/`、`locations/`、`factions/`、`items/`、`events/`
- `lore/plot-threads.md`
- 条目模板：`references/lore-schema.md`（仅在新建/改字段时读）

已知道路径就直接打开该文件。上下文里已有的事实直接用，不要重读。

## 工作方式

查询：打开目标条目，回答后停。

新增/修改：按 `references/lore-schema.md` 改对应文件；旧事实保留并标 `superseded_by:`。状态只用 `unknown` / `alive` / `dead` / `missing` / `sealed` / `destroyed`。

然后按上面的上限跑脚本，通过就停。
