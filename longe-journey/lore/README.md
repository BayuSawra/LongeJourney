# Longe Journey 故事规范库（lore）

这里是游戏重置到 Godot 后唯一的故事事实来源。写剧情、做关卡、写对话之前，先查这里；发现新事实，先改这里。

## 目录结构

- `characters/` 角色
- `locations/` 地点
- `items/` 物品
- `factions/` 势力（暂未启用）
- `events/` 事件
- `plot-threads.md` 伏笔总表
- `INDEX.md` 自动生成的总索引

## 常用操作

1. 新增角色：复制 `characters/protagonist.md` 的格式，新建 `characters/英文名.md`。
2. 新增地点、物品、事件：同样复制同类目下已有文件的格式。
3. 更新事实：保留旧事实，在旧值旁加 `superseded_by: 新值或新条目名`，不要直接删除。
4. 埋新伏笔：在 `plot-threads.md` 末尾新增一个 `## 伏笔名` 小节。
5. 更新索引：运行 `python tools/update_lore_index.py`。
6. 检查规范：运行 `python tools/check_lore_canon.py`。

## 铁律

- 状态只能写：`unknown`、`alive`、`dead`、`missing`、`sealed`、`destroyed`。
- 每个事实都要写来源，例如 `docs/Dialogic_Implementation_Guide.md`、`timelines/*.dtl`、场景文件或对话文本。
- 不删旧事实，只用 `superseded_by:` 标记被取代。
- 文件名小写英文连字符，一个条目一个文件。
- 文件内部链接一律相对 `lore/` 目录写，例如 `[花店](locations/flower-shop.md)`。

## 当前迁移用名词对照

| 规范条目 | 对应现有内容 |
| --- | --- |
| 医院 | `00_start`、`01_hospital` |
| 住院部/停尸房 | `02_ward` |
| 路口 | `03_crossroads` |
| 花店 | `04_flower_shop` |
| 狮岭 | `05_shiling` |
| 露园 | `06_luyuan` |
| 假山迷宫 | `07_maze` |
| 病房 | `08_wife_room` |
| 结局 | `09_ending` |

目前主要来源是 `docs/Dialogic_Implementation_Guide.md`。以后每个 Godot 场景和 Dialogic 时间线落地后，把来源逐步细化为对应文件。
