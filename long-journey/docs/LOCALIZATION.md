# 本地化

## 存储约定

界面、角色名、图鉴和本地化 UI 文案存放在 `localization/<locale>.po`，使用 UTF-8、
稳定 `msgid` + 该语言的 `msgstr`。当前 `zh_CN.po` 有 199 条共享原文；
`en.po` 另有 336 条 Dialogic 译文，共 535 条。

Dialogic 的剧情与选项原文直接写在 `timelines/*.dtl`，不再复制到 `zh_CN.po`。
稳定 `#id` 仍保留在事件行末尾，英文及后续语言只把对应译文放进 PO。
不把中文当 key，不在业务脚本里放另一套翻译字典。

```po
msgid "settings.language"
msgstr "语言"
```

- `zh_CN.po` 是界面、图鉴等共享文案的中文源；英文及后续语言必须具有完全相同的共享 key。
- `.dtl` 同时保存剧情原文、稳定 `#id` 和控制流；目标语言 PO 必须覆盖全部 Dialogic ID。
  当前支持 `Text/<id>/text`、`Choice/<id>/text` 与 `Choice/<id>/disabled_text`。
- `.dch` 的角色名使用原生 `Character/<id>/name`，仍由 PO 提供各语言值。
- `localization/lore.json` 只含稳定 slug、分类、路径和翻译 key，不含面向玩家的文案。
  它以 Godot JSON 资源预加载，属于导出资源依赖，而不是导出后再寻找外部文件。
- `lore/**/*.md` 保留开发正典，不再由游戏作为中文兜底读取。修改设定时同步修改中文 PO 对应条目。
- 开发日志、代码注释、资源标识、玩家输入的名字/存档名不是翻译文案。

## 运行行为

默认首次启动使用简体中文；设置中的 Language/语言可立即切换并持久保存。
语言选项显示各语言文件的 `locale.name`（自称），不是固定写死的中英文枚举。
切换会刷新 UI、当前对话和后续段落、选项、历史记录、图鉴详情与搜索。
不重启时间线，不重新判断选项条件，不重置打字进度，也不触发剧情副作用。

`Localization.text(key)` 取当前语言文本；`format_text(key, values)` 使用命名占位符。
Dialogic 继续使用自己的翻译与事件系统，不引入新的业务框架。启动时从已登记 timeline
收集 Dialogic 原文，中文直接使用 `.dtl` 正文，目标语言使用对应 PO 的 `msgstr`。
空 `player_name` 表示默认名称，由当前语言显示；自定义姓名和存档名保持原样。
历史记录与存档保存稳定 key 和变量快照，不把中文渲染结果当成跨语言文本来源。
历史面板维持原有会话内历史/回看语义，不新增跨会话历史档案。

**没有翻译回退**：关闭 Godot fallback；缺语言/缺 key/空翻译运行时会报告原因并退出。
检查失败不能靠显示 key、中文、英文或空串继续运行。
设置中的未知语言同样报错，而不是改回默认语言。

## 编辑器预览

业务插件 `editor/localization_preview/` 在未选择预览语言时，通过 Godot 4.7 原生翻译预览菜单启用简体中文。
场景画布显示翻译后的中文，节点属性仍保存稳定 key；仍可通过「视图 > 预览翻译」切换语言或关闭预览，已选择的其他语言会保留。
这不修改 Godot 编辑器界面语言，不依赖运行语言的 `internationalization/locale/test`，也不覆盖玩家已保存的语言设置。
插件不修改第三方代码；Godot 原生预览接口或中文资源缺失时明确报错。

## 编辑已有文案

1. 共享界面/图鉴文案只修改 `zh_CN.po` 的中文 `msgstr`，再修改目标语言 PO；不要重命名已有 key。
2. Dialogic 剧情和选项直接在 Godot 的 Dialogic 编辑器中修改 `.dtl` 正文，不要改已有 `#id`。
3. 保留 `{player_name}`、`{count}` 等命名参数、BBCode、链接目标、Dialogic `[n]`/`[n+]` 的数量与次序。
4. 中文源变化后，工具会按 `source-sha256` 标记旧译文待审；人工核对译文后显式确认：

```powershell
$env:PYTHONUTF8 = "1"
python tools/localization.py approve en settings.language
python tools/localization.py check
```

命令从游戏根目录运行。`approve` 只确认指定 key 对应的当前中文版本，不翻译、不批量掩盖缺漏。
确认前会检查占位符、段落顺序及 BBCode 嵌套。`fuzzy`、空白、重复/多余/遗漏 key 都无法通过。

共享文案：先在中文 PO 建立稳定 key，业务/场景引用它；运行 `sync en` 添加缺失的空条目，
填写译文并 `approve`。Dialogic 文案：直接在 `.dtl` 写正文并添加唯一 `#id`，
再运行 `sync en`、填写译文并 `approve`。`sync` 不覆盖已有译文、不更新旧审核戳、
不静默删除退休 key；原生属性完整性由 Godot 测试检查。

## 新增语言

例如法语：

```powershell
python tools/localization.py init fr --plural-forms "nplurals=2; plural=(n > 1);"
```

1. 在新建的 `localization/fr.po` 填完全部 `msgstr`，包括 `locale.name`；文件已存在时拒绝覆盖。
2. 人工审核并使用 `approve fr <key> ...` 逐条或按明确审核范围确认。
3. 在 `project.godot` 的 `internationalization/locale/translations` 添加 `res://localization/fr.po`。
4. 运行 `check`、Python 测试和 `verify.py`。未完成/未注册的新文件会让检查失败，不能带病发布。
5. 语言选择器自动出现新语言，不需修改 GDScript 枚举。

使用 Godot 的规范代码，例如 `en`、`zh_CN`、`pt_BR`；目录穿越、`zh-CN` 等非规范写法会被工具拒绝。
Dialogic 或共享中文调整后，可运行 `sync fr` 添加新增 key，然后处理报告的待审条目。

当前格式**只支持 singular stable-ID PO**，明确拒绝 `msgctxt`、`msgid_plural` 等未实现语法；
当前计数文案采用数字+标签，不依赖英语复数。需要复杂复数、性别语法、RTL 排版时，
需增加相应实现与测试，不能仅添加文件就声称该语言的排版/语法已支持。

字体沿用项目现有字体，中英全部文案逐字符检查覆盖；原本缺字的装饰符 `⁜` 改为同用途的 `※`。
新增语言必须通过字体覆盖测试，并人工验证文本扩张、换行、按钮宽度和输入法。

## 存档兼容性

本地化存档格式为 **V3**，包含 `localized_dialogue` 的 key、变量快照、段落位置。
加载时使用当前设置语言，不用存档的旧语言覆盖用户设置。
V2 及无有效快照的存档明确提示不兼容/损坏，不静默转换，不覆盖旧文件；上线前要明确告知玩家。
默认名称不再以某一种语言的字面值保存在游戏状态中。

## 验证

```powershell
$env:PYTHONUTF8 = "1"
python -m unittest discover -s tools/tests -v
python tools/localization.py check
python tools/verify.py
```

`verify.py` 会复制工程并隔离 `user://`，不触碰真实存档和设置。
覆盖中英文原生翻译、Dialogic 内嵌原文与 PO 译文、全部时间线事件序列、设置持久化、动态 UI、图鉴搜索与历史、
切换时的打字/选项/后续段落、跨语言读档、自定义名字、取消动画生命周期和字体覆盖。
`tests/fixtures/localization_flow.json` 是迁移前原生事件序列替换稳定 ID 后的哈希基线；
只规范化 CRLF/LF 差异。剧情有意修改时应核对变更后更新对应预期，不能为通过测试整份重算。
