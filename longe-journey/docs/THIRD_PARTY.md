# 开发底座来源与补丁

## gdUnit4

- 版本：6.2.1；许可证：MIT，保留 `addons/gdUnit4/LICENSE`。
- 来源：本地 `godot-template`，提交 `c6deed32401857233efeb476932c5d25c2656f04`。
- 上游：`godot-gdunit-labs/gdUnit4`。
- 迁入：`src/`、`bin/`、插件入口、运行脚本、许可证；不含框架自身测试。
- 游戏测试独立放在 `tests/`；以下为最小生命周期补丁：
  - `src/core/writers/GdUnitRichTextMessageWriter.gd`：析构释放自行创建的报告 Panel；
    不释放调用者传入的 RichTextLabel。
  - `src/network/GdUnitServer.gd`：显式预加载 RPCMessage / RPCGdUnitEvent 后再编译类型判断。
    在固定 Godot 4.6.2 图形编辑器中，原全局类引用方式可复现脚本资源残留和退出访问冲突；
    该补丁保持消息分发语义，不停用服务、不清空全局缓存、不升级引擎。
  - 回归：`tests/editor_lifecycle_test.gd`；图形退出由 `tools/verify_mcp.py` 覆盖。

## Dialogic（原有依赖）

保留当前 `2.0-Alpha-20 WIP (Godot 4.4+)`，不整体升级。

- `Modules/Wait/subsystem_wait.gd`：`clear_game_state` 默认参数改成显式 `int = 0`
  （`ClearFlags.FULL_CLEAR` 的原值），解除首次导入时单例循环类型推断。

- `Modules/Variable/subsystem_variables.gd`：两个 `_get()`（子系统与 `VariableFolder`）
  分支外补显式 `return null`。GDScript 落尾本就隐式返回 null，语义不变；
  兼容 Godot 4.7 解析器将“并非所有路径都有返回值”升格为错误，4.6.2 不受影响。

- `Modules/Text/node_name_label.gd`：`_set()` 未处理属性时补显式 `return false`。
  兼容 Godot 4.7 解析器的全路径返回检查；属性处理和名称标签行为不变。

- `Core/DialogicResourceUtil.gd`：目录清理按文件是否存在判断，避免冷导入时自定义
  资源加载器尚未注册，误删全部 timeline/角色目录。

- `Core/DialogicGameHandler.gd` 与 `Core/DialogicUtil.gd`：子系统访问器使用脚本类型
  常量，不再构造永不入树/释放的占位 Node；同步修复编辑器代码生成，防止重写后复发。

- `Modules/Text/event_text.gd`：用布尔访问方法读取 AutoSkip 状态，避免挂起的文本协程
  持有 RefCounted 临时引用，修复中途读档后的退出泄漏；不改变跳过逻辑。

- `Editor/TimelineEditor/VisualEditor/timeline_editor_visual.gd` 与
  `Modules/Variable/variables_editor/variable_tree.gd`：析构时释放自行创建的 UndoRedo，
  修复编辑器退出对象泄漏，不改变撤销行为。

- 本地化追加的 `Modules/Text/event_text.gd` 最小补丁：
  - 每个 `[n]`/`[n+]` 段落开始时重新取当前语言，避免提前缓存旧语言后续段落；
  - 原有分段规则提取为 `_split_translated_text()`，保留原生换行配置；
  - 文本执行增加代数检查，取消时间线后不恢复旧协程；清理时释放自身 `advance` 等待并停止挂起的文本框动画；
  - 不改 Dialogic 翻译键协议、不复制子系统、不升级插件。回归在 `tests/localization_test.gd`。

业务布局 `chat_style.tres` 仅显示项目自己的可重译历史面板，移除重复的原生历史渲染层；
原生 History 子系统及访问记录、自动跳过保留。文本输入层使用项目继承场景，不修改第三方 UI。

## 已有 MCP 插件

`plugin/runtime/mcp_runtime_bridge.gd`：仅在刷新定时器仍处于场景树时启动它，
避免退出事件尝试重启已退出场景树的子定时器。原有退出写盘行为保留。
未迁移模板 MCP，也未启用新的服务。

- `tools/intelligence/atomic_bridge.gd`：扫描显式传入 `res://`；解析依赖的 UID/type/path 编码。
- `tools/intelligence/impl_project.gd`：项目盘点失败向上传递，不伪装成空工程。
- `tools/intelligence/impl_scene.gd`、`tools/scene_tools.gd`：从目标 PackedScene 统计节点及脚本，
  分析/校验的原子调用失败直接返回，不再返回成功的零值结果。
- `plugin/runtime/mcp_runtime_bridge.gd`、`mcp_editor_debugger_bridge.gd`：调试消息使用
  `godot_mcp:` 分隔与 capture 前缀契约。
- `tools/core/tool_loader.gd`、`plugin/runtime/mcp_http_server.gd`：加载器重建及退出时
  清除执行器上下文，打断循环引用并释放诊断服务。
- 回归：`tests/mcp_test.gd`；独立编辑器集成验收：`tools/verify_mcp.py`。

## 环境与自有工具

Godot 固定为 `4.6.2.stable.official.71f334935` standard Windows，安装脚本校验
官方发行 ZIP 的 SHA512。工程验证、测试和 CI 按本项目重写，不复制模板业务逻辑。
