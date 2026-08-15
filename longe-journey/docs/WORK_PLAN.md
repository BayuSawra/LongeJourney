# Longe Journey Godot 迁移工作交接计划

> 本文档是后续线程的“唯一工作参考”。上下文有限时，请先读本文件，再按需查阅
> `docs/Phase0_Content_Tools.md` 与 `docs/Dialogic_Implementation_Guide.md`。
> 凡涉及新线程，以本文档为准，不要凭记忆修改命名或结构。

## 1. 项目快速启动与现状

### 1.1 环境

- 引擎：Godot 4.6，渲染后端为 GL Compatibility。
- 项目路径：`D:\LongeJourney\longe-journey`
- 启动方式：用 Godot 打开 `project.godot` 即可。

### 1.2 入口流程

```text
scenes/mianMenu.tscn
  -> scenes/scene_1.tscn
  -> Dialogic.start("timeline1_0")
```

注意：`mianMenu.tscn` 是原工程拼写，不要“纠正”。

### 1.3 已完成内容

阶段 0 已完成并提交：

- 提交 `8eb04bb`：feat: add Phase 0 lore tools and content pipeline
- 在此之前有 `f1da61b`、`cf38ade`。
- 已落地的插件：`addons/longe_lore_tools`（LoreDock）。
- Godot 编辑器右侧上栏有 `LongeLoreDock`，页签为 `编辑 / 预览 / 校验 / 索引`。

GameState 与 HUD 已完成并提交：

- 提交 `1d24874`：feat: add GameState autoload for shared variables
- 提交 `c0243f5`：fix: fix GameState parser error for property lookup
- 提交 `3b05895`：feat: add persistent HUD for core stats
- 提交 `<hash>`：feat: add ending manager and debug panel（hash 提交成功后补填）

当前工作区状态：

- 当前工作区干净，GameState 与 HUD 已完成并提交，无需处理 Godot 编辑器写入的 `project.godot` 改动。
- 计划文档最近一次更新：`837d64d`（docs: update work plan with GameState and HUD progress）。

### 1.4 最近检查记录（2026-08-15）

- `tools/check_lore_canon.py`：通过（exit 0）。
- `tools/update_lore_index.py`：通过（exit 0），`lore/INDEX.md` 无新增 diff。
- 登记检查：`project.godot` 已注册 `Dialogic`、`GameState` 与 `EndingManager` autoload；`longe_lore_tools` 插件已启用；`scenes/scene_1.tscn` 已挂载 `HUD` 与 `EndingDebugPanel`；`scenes/hud.tscn` 已挂 `scripts/hud.gd`。
- 工作区：本次 3 个文件（`ending_manager.gd`、`ending_debug_panel.gd`、`ending_debug_panel.tscn`）已提交。

## 2. 目录结构与工具说明

### 2.1 顶层目录

```text
addons/      # dialogic、godot_dotnet_mcp、longe_lore_tools
art/         # 美术资源
character/   # Dialogic 角色（character/我.dch，已登记为“我”）
docs/        # 本文档与设计/实现文档
font/        # 字体
lore/        # 剧情设定数据（canon）
scenes/      # 场景（mianMenu、scene_1 等）
scripts/     # 脚本
timelines/   # Dialogic timeline
tools/       # Python 内容工具
```

### 2.2 Lore 数据与工具

- `lore/` 存设定正文，`lore/INDEX.md` 是汇总索引。
- `tools/check_lore_canon.py`：校验 canon 一致性。
- `tools/update_lore_index.py`：重建 `lore/INDEX.md`。
- `addons/longe_lore_tools`：Godot 编辑器内的 LoreDock 插件，含编辑、预览、校验、索引四个页签。

PowerShell 命令行等价操作：

```powershell
& "C:\Users\yu\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools/check_lore_canon.py
& "C:\Users\yu\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools/update_lore_index.py
```

## 3. 日常内容新增流程

### 3.1 新增/修改 Lore 设定

1. 在 LoreDock `编辑` 页修改 `lore/` 内容，或直接编辑对应 md 文件。
2. 运行 `tools/check_lore_canon.py` 校验。
3. 运行 `tools/update_lore_index.py` 更新 `lore/INDEX.md`。
4. 若变更影响剧情设定，检查 Dialogic timeline 中的对白、选项与变量是否仍一致。

### 3.2 新增 Dialogic Timeline

1. 先在 Dialogic 编辑器创建 timeline 文件（位于 `timelines/`），命名沿用推荐编号。
2. 在场景中登记 timeline：通常通过 `Dialogic.start("timeline_id")` 或对话触发器引用。
3. 必须“先建文件，再登记引用”，不要凭空写引用。
4. 新 timeline 涉及的对话样式沿用 `res://chat_styel.tres`（原工程拼写，不要改）。

### 3.3 新增角色

1. 在 `character/` 新建 `.dch`，并登记角色名。
2. 样式与头像路径在 `.dch` 中维护。
3. 校验 `character/我.dch` 等既有文件不要被误改。

## 4. 全局变量清单（当前基线）

```text
energy=100
calm=100
money=20
earthworm=0
flower=0
wife=0
hualan=false
jiahua=false
player_name="无名王"
visit_huadian=0
visit_shiling=0
visit_luyuan=0
visit_ting_shifang=0
```

变量一律使用英文命名；不要在 timeline 文本里散落中文变量名。

## 5. 推荐 Timeline 迁移顺序

```text
00_start.dtl
01_hospital.dtl
02_ward.dtl
03_crossroads.dtl
04_flower_shop.dtl
05_shiling.dtl
06_luyuan.dtl
07_maze.dtl
08_wife_room.dtl
09_ending.dtl
```

迁移顺序 = 玩家游玩顺序。每完成一个 timeline，应跑一次游戏流程验证入口、选项、变量变化与结局条件。

## 6. 后续阶段候选与推荐顺序

> 阶段 4 及以后是“候选/建议”，不是已完成内容。每阶段先写清“完成定义”和“验证方式”，再动手。

### 阶段 1：GameState autoload

- 目标：把变量清单做成单一 `GameState` autoload，统一读写。
- 完成定义：所有现有 timeline 的变量读写都走 `GameState`；变量默认值与上文清单一致。
- 验证：启动游戏后检查变量初始值；推进剧情后检查数值变化持久。
- 当前进度：已完成。已创建并注册 `scripts/autoload/game_state.gd`；修复 `_has_property()`（Godot 4 无 `has_property()` 方法，改用遍历 `get_property_list()`）。
- 对应提交：`1d24874`、`c0243f5`。

### 阶段 2：HUD / 常驻状态

- 目标：显示 `energy`、`calm`、`money` 等核心状态。
- 完成定义：HUD 在主要场景常驻，数值随 `GameState` 实时更新。
- 验证：修改变量后 HUD 立即刷新；不同场景切换不丢状态。
- 当前进度：已完成。`scenes/hud.tscn` + `scripts/hud.gd` 已落地，并在 `scenes/scene_1.tscn` 挂载 HUD 实例；订阅 `GameState.value_changed` 实时刷新。
- 对应提交：`3b05895`。

### 阶段 3：结局监视

- 目标：定义结局条件并集中判定。
- 完成定义：结局判定逻辑集中在一个脚本/节点中，`wife`、`flower`、`earthworm`、`hualan`、`jiahua` 等关键分支可触发对应结局。
- 验证：用测试用变量组合逐一走到各结局。
- 当前进度：已完成基础监视。新增 `scripts/autoload/ending_manager.gd` autoload，监听 `GameState.value_changed`，定义 `ending_bankrupt`（money<0）、`ending_crazy`（calm<0）、`ending_exhausted`（energy<0）三个结局并去重触发；新增 `scripts/ending_debug_panel.gd` + `scenes/ending_debug_panel.tscn` 调试面板，已挂载到 `scenes/scene_1.tscn`，可写入 energy/calm/money 并实时查看触发结局。后续再把 wife/flower/earthworm/hualan/jiahua 分支结局接入同一管理器。

### 阶段 4：按地点迁移 timeline

- 按推荐顺序逐个把原剧情迁移为 `00_start.dtl` 至 `09_ending.dtl`。
- 每个 timeline 完成定义：可从头到尾走通，选项齐全，变量变化正确。

### 阶段 5：文本 / 变量迁移

- 把散落在 timeline 中的变量引用、条件、文本格式统一。
- 用脚本扫描 `timelines/` 中未登记变量与非法引用。

### 阶段 6：背景 / BGM

- 建立背景图与 BGM 资源清单，每个场景登记背景/BGM 切换点。
- 验证：场景切换时背景与音乐同步，暂停/继续不卡。

### 阶段 7：特效 / 文字动画

- 统一文字显示速度、打字机效果、淡入淡出与选项动画。
- 验证：不同分辨率与 GL Compatibility 下无错位。

### 阶段 8：存档 / 历史 / 设置

- 存档覆盖 `GameState`、当前 timeline 与场景；提供读档恢复。
- 设置覆盖文字速度、音量、全屏等。

### 阶段 9：游戏内 lore 查询与浏览

- 把 `lore/INDEX.md` 或 canon 数据接入游戏内“图鉴/设定”界面。
- 验证：内容与 `tools/check_lore_canon.py` 结果一致。

### 阶段 10：批量导入 / 导出 / 备份规范

- 建立 timeline、lore、资源的批量导入导出脚本与备份目录规范。
- 验证：导出的内容可重新导入且校验通过。

## 7. 提交规范

1. 提交前必须运行 `tools/check_lore_canon.py`，校验失败不提交。
2. 涉及 `lore/` 变更时，先运行 `tools/update_lore_index.py` 再提交。
3. 提交信息使用类型化前缀：`feat:`、`fix:`、`docs:`、`chore:`、`refactor:`。
4. 提交前检查 `git status`，不要提交无关文件。
5. `project.godot` 若由 Godot 编辑器写入而产生未提交修改，提交前人工确认；不盲目 revert。
6. 不删除、不覆盖用户已有修改；不执行破坏性 git 命令。

## 8. 常见坑与注意事项

- Dialogic 2.0-Alpha-20 的 API 仍在变化，先查当前版本用法，再写新代码。
- timeline 必须先建文件，再在场景中登记引用。
- 对话样式文件名为 `chat_styel.tres`，是原工程拼写，不要“纠正”。
- PowerShell 控制台输出乱码不影响文件本身；文件统一 UTF-8。
- 不要在 `project.godot`、`chat_styel.tres` 等既有命名上做无谓“规范化”。
- 变量名用英文，且与第 4 节清单保持一致。
- 每次大改后跑一遍完整游戏流程，确认入口 `mianMenu.tscn -> scene_1.tscn -> timeline1_0` 不被破坏。

## 9. 新线程启动检查单

1. 读 `docs/WORK_PLAN.md`。
2. 按需读 `docs/Phase0_Content_Tools.md` 与 `docs/Dialogic_Implementation_Guide.md`。
3. 运行 `git status`，确认工作区当前改动。
4. 明确本次要推进的阶段/子任务，先列“完成定义 + 验证方式”。
5. 动手改代码或内容，完成后跑校验、跑游戏流程、按第 7 节规范提交。
6. 可先看第 1.4 节最近检查记录；涉及 lore/timeline 的改动仍需重跑对应校验。
