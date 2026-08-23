# Longe Journey Godot 迁移工作交接计划

> 新线程开始工作时，先读 `docs/task_checkpoint.md` 的“下一步”并直接执行；需要背景或规范时，
> 再按需查阅本文档与 `docs/Phase0_Content_Tools.md`、`docs/Dialogic_Implementation_Guide.md`。
> 凡涉及新线程，以实际文件为准，不要凭记忆修改命名或结构。

## 1. 项目快速启动与现状

### 1.1 环境

- 引擎：Godot 4.6，渲染后端为 GL Compatibility。
- 项目路径：`D:\LongeJourney\longe-journey`
- 启动方式：用 Godot 打开 `project.godot` 即可。

### 1.2 入口流程

```text
scenes/mianMenu.tscn
  -> scenes/scene_1.tscn
  -> Dialogic.start("00_start")
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
- 提交 `8d88040`：feat: add ending manager and debug panel

当前工作区状态：

- 阶段 4 第二批已提交（`6a46e04`）。
- `tools/_twine_extract.txt` 与 `tools/extract_twine.py` 是只读/参考辅助文件，保持未跟踪，禁止提交。
- `07_maze_entry.dtl` 已创建、已登记 `project.godot` 并提交（`f6c9a37`）；`07_maze_left.dtl`、`07_maze_middle.dtl`、`07_maze_right.dtl` 已创建并提交（`15b09ba`、`6574e80`、`6554e3f`），下一步创建 `07_maze_exit.dtl`，再接 `08_wife_room`。
- 已存在的 `timelines/timeline1_0.dtl` 与其 `.uid` 不要误删，本次不提交。

### 1.4 最近检查记录（2026-08-15）

- `tools/check_lore_canon.py`：通过（exit 0）。
- `tools/update_lore_index.py`：通过（exit 0），`lore/INDEX.md` 无新增 diff。
- 登记检查：`project.godot` 已注册 `Dialogic`、`GameState` 与 `EndingManager` autoload；`longe_lore_tools` 插件已启用；`scenes/scene_1.tscn` 已挂载 `HUD` 与 `EndingDebugPanel`；`scenes/hud.tscn` 已挂 `scripts/hud.gd`。
- 工作区：本次 3 个文件（`ending_manager.gd`、`ending_debug_panel.gd`、`ending_debug_panel.tscn`）已提交。

阶段 4.1 迷宫链路检查（2026-08-16）：

- `07_maze_entry.dtl` 已创建、已登记 `project.godot`，提交 `f6c9a37`；`06_luyuan` 出口已接 `jump 07_maze_left`；`07_maze_left.dtl`、`07_maze_middle.dtl`、`07_maze_right.dtl` 已创建并提交（`15b09ba`、`6574e80`、`6554e3f`）。
- 相关提交：`53098be`（uid 跟踪）、`eec88c9`（docs 浓缩）。
- 下一步：创建 `07_maze_exit.dtl`，统一校验后提交。

阶段 4 第一批检查（2026-08-15）：

- `tools/check_lore_canon.py`：通过（exit 0）。
- 入口脚本 `scripts/start.gd`：已从 `timeline1_0` 改为 `Dialogic.start("00_start")`。
- 新增 `timelines/00_start.dtl`（公交车上，跳转 `01_hospital`）与 `01_hospital.dtl`（医院楼下，跳转 `02_ward` / `03_crossroads`）。
- `02_ward.dtl`、`03_crossroads.dtl` 为占位 TODO，尚未做真实迁移。
- 提交：`feat: migrate opening and hospital timelines`。

阶段 4 第二批检查（2026-08-15）：

- `tools/check_lore_canon.py`：通过（exit 0）。
- `project.godot` 的 `directories/dtl_directory` 已登记 `04_flower_shop`、`05_shiling`、`06_luyuan`，插在 `03_crossroads` 之后、`timeline1_0` 之前。
- 新增 `timelines/04_flower_shop.dtl`、`05_shiling.dtl`、`06_luyuan.dtl`；`02_ward.dtl`、`03_crossroads.dtl` 已从占位 TODO 实现为真实迁移。
- 提交：`feat: implement ward, crossroads, flower shop, shiling, and luyuan timelines`。

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

迁移顺序 = 玩家游玩顺序。每个阶段/提交完成后跑一次完整游戏流程验证入口、选项、变量变化与结局条件。

## 6. 后续阶段候选与推荐顺序

> 阶段 4 及以后是“候选/建议”，不是已完成内容；已定稿的迁移任务以 docs/task_checkpoint.md 的“下一步”为准，先完成内容，提交前再按校验清单检查。

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
- 当前进度：`02_ward` 至 `06_luyuan` 已实现并通过校验；`07_maze_entry.dtl`、`07_maze_left.dtl`、`07_maze_middle.dtl`、`07_maze_right.dtl` 已创建并提交（`f6c9a37`、`15b09ba`、`6574e80`、`6554e3f`），下一步继续 `07_maze_exit.dtl`。
- 对应提交：阶段 4 第一批与第二批（见 1.4）。

### 阶段 4.1：修复 07_maze 跳转链路

- 现状：`07_maze_entry.dtl`、`07_maze_left.dtl`、`07_maze_middle.dtl`、`07_maze_right.dtl` 已完成并提交（`f6c9a37`、`15b09ba`、`6574e80`、`6554e3f`），`06_luyuan.dtl` 出口已接 `jump 07_maze_left`；下一步创建 `07_maze_exit.dtl`。
- 目标链路：`06_luyuan -> 07_maze -> 08_wife_room`，缺任何一个节点都会断；先修 `06_luyuan.dtl` 的出口，再保证迷宫所有分支最终走到 `08_wife_room`。
- jump 规则：目标必须是真实 timeline ID，或同文件内的 label；不要写 Twine 风格 passage 名或中文名（如 `jump 迷宫1`、`jump 左1`）。
- 文件组织：延续仓库现有的“按地点分文件”模式，再按分支粒度拆小：
  - `07_maze_entry.dtl`：进入迷宫、第一层岔路。
  - `07_maze_left.dtl`：左侧分支。
  - `07_maze_middle.dtl`：中央女人线。
  - `07_maze_right.dtl`：右侧分支。
  - `07_maze_exit.dtl`：拿到花/逃离后的收束，最后 `jump 08_wife_room`。
- 备选组织：按剧情拍拆为 `07_maze_flower_cactus`、`07_maze_flower_xiuqiu`、`07_maze_eavesdrop`、`07_maze_flee`；若迷宫较短，也可用单个 `07_maze.dtl` 配合 Dialogic 内部 label。
- 命名：文件名继续用英文，对齐现有 `06_luyuan`、`08_wife_room` 风格，中文只放在显示文本里。
- 完成定义：每个分支文件最后都有明确下一跳，迷宫出口统一为 `jump 08_wife_room`；从 `06_luyuan` 出发的整条链可从头走到尾。
- 验证：逐分支走通 `06_luyuan -> 07_maze -> 08_wife_room`，并检查所有 jump/选择目标都指向真实 timeline ID 或同文件 label。

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

- 8.1 存档数据结构/序列化：`GameState` + 当前 timeline/场景，可写入可恢复。
- 8.2 存档/读档 UI 与自动存档：提供存档、读档入口，关键节点自动存档。
  - 8.2.1 存档槽位数据结构与存储层：槽位列表、时间/命名元数据，读写文件。
  - 8.2.2 存档 UI：槽位选择、覆盖确认、时间/命名展示与空槽位处理。
  - 8.2.3 读档 UI 与恢复流程：恢复 `GameState`、当前 timeline/场景。
  - 8.2.4 自动存档触发点：定义关键节点并接入自动存档。
  - 8.2.5 与 Dialogic Save / HUD / 场景导航集成验证：走通存读档闭环。
- 8.3 历史记录/回放 UI：查看已播文本，可跳回历史节点。
- [x] 8.4 设置面板：文字速度、音量、全屏等设置并可持久化。
- 8.5 与场景导航/GameState 集成：存档/读档/设置接入现有入口与场景切换。
- 存档覆盖 `GameState`、当前 timeline 与场景；提供读档恢复。
- 设置覆盖文字速度、音量、全屏等。

### 阶段 9：游戏内 lore 查询与浏览

- 9.1 从 `lore/INDEX.md`/canon 导入运行时数据，形成只读设定数据。验证通过就执行，不需要来回反复验证，收窄你的工作流。
- 9.2 图鉴/设定浏览 UI：分类列出地点、事件、角色等，支持搜索、筛选与详情查看。
  - 9.2.1 图鉴数据模型与分类索引：把 9.1 的运行时数据组织成可分类、可检索的索引。验证通过就执行，不需要来回反复验证，收窄你的工作流。
  - 9.2.2 图鉴主界面与分类列表：地点、事件、角色等分类入口与列表展示。验证通过就执行，不需要来回反复验证，收窄你的工作流。
  - 9.2.3 搜索/筛选：按关键词或分类查找条目。验证通过就执行，不需要来回反复验证，收窄你的工作流。
  - 9.2.4 详情查看：展示所选条目的完整原文。验证通过就执行，不需要来回反复验证，收窄你的工作流。
  - 9.2.5 场景/HUD 集成验证：从游戏内入口进入图鉴，返回后场景状态不丢。验证通过就执行，不需要来回反复验证，收窄你的工作流。
- 9.3 校验流程：与 `tools/check_lore_canon.py` 的结果保持一致。
- 把 `lore/INDEX.md` 或 canon 数据接入游戏内“图鉴/设定”界面。
- 验证：内容与 `tools/check_lore_canon.py` 结果一致。验证通过就执行，不需要来回反复验证，收窄你的工作流。后续如需测试，godot安装在E:\Godot\Godot_v4.6.2-stable_mono_win64

### 阶段 10：批量导入 / 导出 / 备份规范

- 10.1 timeline/lore/资源导入导出脚本：输入输出格式与文件路径明确。
  - 10.1.1 统一 CLI/接口与输入输出格式、路径约定：先定命令入口、文件格式与目录约定。验证通过就执行，不需要来回反复验证，收窄你的工作流。后续如需测试，godot安装在E:\Godot\Godot_v4.6.2-stable_mono_win64
  - 10.1.2 timeline 导入导出：支持批量导出/导入 `timelines/`，保持引用与 label 有效。验证通过就执行，不需要来回反复验证，收窄你的工作流。后续如需测试，godot安装在E:\Godot\Godot_v4.6.2-stable_mono_win64
  - [x] 10.1.3 lore 导入导出：支持批量导出/导入 `lore/` 与 `INDEX.md`。验证通过就执行，不需要来回反复验证，收窄你的工作流。后续如需测试，godot安装在E:\Godot\Godot_v4.6.2-stable_mono_win64
  - 10.1.4 资源清单与引用校验导入导出：拆为 10.1.4a~10.1.4e，每个子任务单独开线程执行，完成即提交，线程内不做下一个子任务。
    - 10.1.4a 资源清单生成：扫描 `art/`、`art/icon/`、`font/` 及配套 `.import` 文件，生成资源清单文件。验证：清单文件生成且条目完整。验证通过就执行，不需要来回反复验证，收窄你的工作流。
    - 10.1.4b 资源引用分析：扫描 lore/docs/scenes/scripts 中的资源引用，输出引用清单与未解析引用。验证：输出文件与引用计数正确。验证通过就执行，不需要来回反复验证，收窄你的工作流。
    - 10.1.4c 资源引用校验器：对照资源清单与引用清单，输出缺失、孤立、不一致项。验证：校验结果与手工抽查一致。验证通过就执行，不需要来回反复验证，收窄你的工作流。
    - [x] 10.1.4d 资源导入器：按清单重建/补齐资源与 `.import` 文件，导入后运行校验器。验证：导入后校验通过。验证通过就执行，不需要来回反复验证，收窄你的工作流。后续如需测试，godot安装在E:\Godot\Godot_v4.6.2-stable_mono_win64
      - [x] 10.1.4e 导出/备份与文档：按清单导出/备份资源并做往返校验，把用法写回计划/工具文档。命令：`powershell -ExecutionPolicy Bypass -File scripts/resource_export_backup.ps1`；备份输出至 `backups/resources/<时间戳>/`，含 `backup_manifest.json`（SHA256），往返校验通过后输出 `roundtrip=passed validation=passed`。验证：往返校验通过、文档已更新。验证通过就执行，不需要来回反复验证，收窄你的工作流。
- 10.2 备份目录规范：备份位置、命名与保留规则明确。验证通过就执行，不需要来回反复验证，收窄你的工作流。
- 10.3 往返验证：复用 10.1 的导出/导入/校验命令与 resource_references.json / resource_validation.json 等已有产物，做一次端到端导出->导入->校验；发现不一致时修复后重跑一次，不反复扫描全量语料。验证：导出的内容可重新导入且校验通过。如需测试，godot安装在E:\Godot\Godot_v4.6.2-stable_mono_win64
- 10.4 文档：同步更新本计划与 docs/ 工具文档，记录脚本用法、备份目录/命名/保留规则及 10.3 的往返验证命令。验证：文档已更新且命令与实际 CLI 一致。
- 建立 timeline、lore、资源的批量导入导出脚本与备份目录规范。
- 验证：导出的内容可重新导入且校验通过。验证通过就执行，不需要来回反复验证，收窄你的工作流。

## 7. 提交规范

1. 提交前必须运行 `tools/check_lore_canon.py`，校验失败不提交。
2. 涉及 `lore/` 变更时，先运行 `tools/update_lore_index.py` 再提交。
3. 提交信息使用类型化前缀：`feat:`、`fix:`、`docs:`、`chore:`、`refactor:`。
4. 提交前检查 `git status`，不要提交无关文件。
5. `project.godot` 若由 Godot 编辑器写入而产生未提交修改，提交前人工确认；不盲目 revert。
6. 不删除、不覆盖用户已有修改；不执行破坏性 git 命令。

## 7.1 防空转规则

- 新线程只做一件事：读 `docs/task_checkpoint.md` 的“下一步”后直接执行。
- 一个线程只执行一个执行块（如 8.1 至 8.5 之一）；该块完成并提交后再开下一个线程。
- 动工前先把该块的完成定义写入 `docs/task_checkpoint.md`。
- 一块完成即提交，提交信息写明阶段与块号（如 `feat(phase8): ...`）。
- 不做开放式多文件重构；顺带发现的问题另记，不在本块里扩大范围。
- “下一步”已明确时不再重读 `SKILL.md` / `WORK_PLAN.md` 原文，也不重查已验证的 lore/技能约定。

## 8. 常见坑与注意事项

- Dialogic 2.0-Alpha-20 的 API 仍在变化，先查当前版本用法，再写新代码。
- timeline 必须先建文件，再在场景中登记引用。
- 对话样式文件名为 `chat_styel.tres`，是原工程拼写，不要“纠正”。
- PowerShell 控制台输出乱码不影响文件本身；文件统一 UTF-8。
- 不要在 `project.godot`、`chat_styel.tres` 等既有命名上做无谓“规范化”。
- 变量名用英文，且与第 4 节清单保持一致。
- Dialogic 的 jump/选择目标必须是真实 timeline ID 或同文件 label，不要写 Twine 风格 passage 名或中文名（如 `迷宫1`、`左1`），否则运行时找不到下一步。
- 每次大改后跑一遍完整游戏流程，确认入口 `mianMenu.tscn -> scene_1.tscn -> 00_start` 不被破坏。

## 9. 新线程启动检查单

1. 读 `docs/WORK_PLAN.md` 与 `docs/task_checkpoint.md`。
2. 按需读 `docs/Phase0_Content_Tools.md` 与 `docs/Dialogic_Implementation_Guide.md`。
3. 运行 `git status`，确认工作区当前改动。
4. 先读 `docs/task_checkpoint.md` 的“下一步”并直接执行；仅当出现新事实或矛盾时才重查 lore/技能约定。校验放在内容完成、提交之前例行执行。
5. 启动时把本次相关规则浓缩成短清单写入 `docs/task_checkpoint.md`；后续路由只读清单，不整读 `SKILL.md` / `WORK_PLAN.md` 原文，阶段切换或需要特定规范时才回头查。
6. 动手执行第 4 步任务，完成后按第 7 节规范统一验证并提交。
7. 需要历史检查记录时再看第 1.4 节；timeline 迁移按阶段 4.1 的完成定义验证，不单独逐条跑 lore 校验，提交前按第 7 节统一执行。
