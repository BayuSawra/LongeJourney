# 阶段0 内容工具使用指南

本文档面向后续在 Longe Journey 中持续添加故事内容的工作流，覆盖 Godot 编辑器内的 Lore 工具、命令行校验/索引工具，以及 Dialogic 对白入口。

## 1. LoreDock：Godot 编辑器内的正文工具

用 Godot 打开 `project.godot` 后，右侧上栏会出现 `LongeLoreDock`，其中包含四个页签：

- `编辑`：新建、打开、保存、删除 lore 条目。
- `预览`：查看当前条目的 Markdown 源码和渲染后的预览。
- `校验`：一键运行正文校验。
- `索引`：一键重建 `lore/INDEX.md` 索引。

编辑页签支持以下字段：

- 名称：条目唯一标识，文件名会以它命名。
- 状态：草稿 / 正典 / 已废弃 等。
- 已知信息：每行一条，格式为 `事实（来源：出处）`。
- 来源、时间、地点、角色（逗号分隔）、结果。

建议在每次新增或修改条目后依次做：`校验` -> `索引`，保证数据文件与索引一致。

## 2. 命令行脚本

在 Windows PowerShell 中可使用 Codex 内置 Python 运行：

```powershell
& "C:\Users\yu\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools/check_lore_canon.py
& "C:\Users\yu\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools/update_lore_index.py
```

普通 Python 环境直接使用：

```powershell
python tools/check_lore_canon.py
python tools/update_lore_index.py
```

`check_lore_canon.py` 校验失败时以非零状态退出，适合接入 CI 或提交前检查；`update_lore_index.py` 会重新生成 `lore/INDEX.md`。

## 3. Dialogic 内容入口

- 启动对白：`Dialogic.start("timeline1_0")`。
- 建议按地点拆分成独立 timeline，例如 `timeline1_0` 作为第一章/地点 1 的入口。
- 已知变量：`energy`、`calm`、`money`、`flower`、`earthworm`、`jiahua`、`hualan`、`visit_shiling`。
- 角色：`res://character/我.dch` 已登记为 `我`。
- 样式：`res://chat_styel.tres`（注意文件名拼写沿用原工程）。

## 4. 新增一段故事的推荐流程

1. 在 LoreDock `编辑` 页签新建条目，填写事实与来源。
2. 点击 `校验` 修正格式问题，再点击 `索引` 更新索引。
3. 在 Dialogic 中新建或编辑对应地点的 timeline。
4. 使用变量、`我.dch` 和 `chat_styel.tres` 组织对白与跳转。
5. 运行游戏，检查变量读写、条件跳转和结局分支是否符合预期。

