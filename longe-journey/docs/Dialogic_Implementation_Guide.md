# 《长路漫漫》Godot + Dialogic 功能实现指南

> 本文面向把 Twine（SugarCube）原版《长路漫漫》移植到 Godot 4.6 + Dialogic 2.0-Alpha-20 的后续开发。
> 按功能查方案，所有示例基于本仓库当前插件源码整理；Dialogic 仍是 Alpha 版，个别 API 可能随版本调整，以实际运行版本为准。

## 1. 结论速览

- Dialogic 原生事件能覆盖：变量、条件分支、选项、文本输入、等待、跳转、背景、音频、存档、历史、设置、随机数。
- 需要自己写 GDScript / 自定义控件的部分：常驻 HUD、全局结局监视、自定义文字动画、点击分段揭示。
- 不需要做的事：把 Twine 的 HTML/CSS/JS 原样搬进 Godot。玩法都能翻译，只是部分交互要换一种实现方式。

## 2. 当前工程现状

- Twine 原版：`D:\LongeJourney\长路漫漫\长路漫漫.html`，SugarCube 2.37.3，共 49 个 passage。
- Godot 工程现状：
  - 主菜单 `scenes/mianMenu.tscn` -> `scenes/scene_1.tscn` -> `Dialogic.start("timeline1_0")`。
  - `timelines/timeline1_0.dtl` 只是测试对话。
  - 角色只有 `character/我.dch`。
  - 图片素材已复制到 `art/` 和 `art/icon/`，字体已导入。
- 尚未迁移：医院、花店、路口、狮岭、露园、迷宫、病房、结局等地点内容，以及 HUD 和结局监视。

## 3. Dialogic 模块速查

| 模块 | 作用 | 本工程用途 |
| --- | --- | --- |
| Variable | 定义/修改/读取变量 | `energy`、`calm`、`money`、`flower` 等 |
| Condition | `if / elif / else` 条件分支 | 花店访问次数、花数门槛、结局检查 |
| Choice | 选项及选项条件 | 所有 `[[...]]` 和 `<<link>>` 选择 |
| TextInput | 文本框输入并存入变量 | 露园起名 |
| Wait / WaitInput | 延时 / 等待输入 | `<<timed>>` 的固定延时 |
| Jump | 跳转到另一个 timeline 或 label | passage 跳转 |
| Background | 背景图/场景切换 | 医院、狮岭、露园大图 |
| Character | 角色定义、名字、立绘 | 我、花店老板、护士、妻子 |
| LayeredPortrait / HighlightPortrait | 分层立绘 / 高亮立绘 | 后续角色演出 |
| Text | 对话文本、BBCode、文本效果 | 所有台词、颜色、特效 |
| Audio | 音乐/音效 | BGM、环境声 |
| Voice | 下一句台词配音 | 后续配音 |
| Call | 调用 autoload 方法 | 自定义面板、小游戏、外部逻辑 |
| Signal | 发出 Dialogic 信号 | 通知游戏脚本 |
| Save | 存档/读档/自动存档 | 后续存档系统 |
| History | 对话历史、事件访问记录 | 回看对话 |
| Glossary | 术语高亮与词条 | 世界观名词 |
| Settings | 设置面板 | 音量、文字速度等 |
| Style | 对话框样式/布局层 | `chat_styel.tres` |
| Clear / End / Comment | 清屏 / 结束 / 注释 | 场景切换、结局收尾 |

## 4. Twine 写法 -> Dialogic 对照

| Twine 写法 | 含义 | Dialogic 方案 |
| --- | --- | --- |
| `<<set $energy to 100>>` | 初始化变量 | 变量编辑器定义默认值，或 `set {energy} = 100` |
| `<<set $money -= 2>>` | 修改变量 | `set {money} -= 2` |
| `<<= $energy >>` | 显示变量 | 文本里写 `{energy}` |
| `<<if $flower < 5>> ... <<elseif>> ... <<endif>>` | 条件分支 | `if {flower} < 5:` / `elif ...:` / `else:` |
| `[[去花店\|花店][$energy -=5]]` | 带代价的跳转 | 选项分支里 `set {energy} -= 5`，再 `jump flower_shop` |
| `<<link>>` + `<<replace>>` | 原地展开文本 | 多步 Choice / 多段文本，或自定义面板 |
| `<<linkreplace>>` + `<<timed>>` | 点击后延时揭示 | 多步 Choice + `[wait]`，或自定义控件 |
| `<<textbox "$playerName">>` | 玩家输入名字 | `[text_input ...]` |
| `PassageVisitMacro` | 统计访问次数 | 变量计数，或用 History 判断是否访问过 |
| StoryCaption | 常驻状态栏 | 自定义 HUD 场景 + GDScript |
| CSS 动画（flicker/shake/fadein） | 文字特效 | BBCode + 自定义 `RichTextEffect` |
| `Config.history.controls = false` | 关闭历史按钮 | Dialogic History / Settings 设置 |
| `<img src="...">` | 内嵌图片 | `[img=res://...]` 或 Background 事件 |

## 5. 工程组织建议

建议按地点拆 timeline，而不是把所有内容塞进一个文件：

```text
timelines/
  00_start.dtl            # 开幕/公交车
  01_hospital.dtl         # 医院入口
  02_ward.dtl             # 住院部/停尸房
  03_crossroads.dtl       # 路口
  04_flower_shop.dtl      # 花店
  05_shiling.dtl          # 狮岭
  06_luyuan.dtl           # 露园
  07_maze.dtl             # 假山迷宫
  08_wife_room.dtl        # 病房
  09_ending.dtl           # 结局
character/*.dch           # 角色定义
styles/*.tres             # Dialogic 样式
scripts/autoload/game_state.gd
scripts/hud/hud.gd
scripts/hud/hud.tscn
scripts/text_effects/*.gd
```

推荐命名规则：

- timeline 标识符用英文小写：`flower_shop`、`shiling`、`luyuan`、`ending_bankrupt`。
- 变量名用英文：`energy`、`calm`、`money`、`earthworm`、`flower`、`hualan`、`jiahua`、`player_name`、`visit_huadian`。
- 素材路径统一 `res://art/...`、`res://art/icon/...`。

## 6. 分功能实现

### 6.1 变量、初始值、显示

在 Dialogic 的变量编辑器里声明以下变量（或用 autoload 变量）：

| 变量 | 类型 | 初始值 | 说明 |
| --- | --- | --- | --- |
| `energy` | int | 100 | 精力 |
| `calm` | int | 100 | 镇定 |
| `money` | int | 20 | 钱 |
| `earthworm` | int | 0 | 蚯蚓数量 |
| `flower` | int | 0 | 花数量 |
| `wife` | int | 0 | 妻子好感度（原版未实际使用） |
| `hualan` | bool | false | 是否有花篮 |
| `jiahua` | bool | false | 是否混入假花 |
| `player_name` | string | `无名王` | 玩家名字 |
| `visit_huadian` | int | 0 | 花店访问次数 |
| `visit_shiling` | int | 0 | 狮岭访问次数 |
| `visit_luyuan` | int | 0 | 露园访问次数 |
| `visit_ting_shifang` | int | 0 | 停尸房访问次数 |

事件语法：

```text
set {money} = 20
set {money} -= 2
set {flower} += 1
set {hualan} = true
```

文本里显示变量：

```text
我数了数，现在我有 {flower} 朵花。
```

Twine 里的 `$visitCount["花店"]` 也可以用 Dialogic 字典变量，但更推荐拆成独立变量，直观且编辑器支持更好：

```text
set {visit["花店"]} += 1
if {visit["花店"]} == 1:
    第一次来花店。
```

### 6.2 条件分支与选项

条件分支：

```text
if {flower} < 5:
    没带花别进去，护士拦住我。
    jump hospital
elif {flower} >= 5:
    护士放我进去。
    jump ward
else:
    ...
```

选项（Choice 事件）：

```text
- 去花店（精力-5）
    set {energy} -= 5
    jump flower_shop
- 乘车去狮岭（车费2元）
    set {money} -= 2
    jump shiling
- 回医院
    jump hospital
```

选项可以带条件：

```text
- 去花店 [if {visit_huadian} < 3]
    jump flower_shop
```

Twine 的一次性选项用 `_choiceMade` 防重复，Dialogic 里用布尔变量即可：

```text
if {flower_shop_choice_done} == false:
    - 占着茅坑不拉屎，明年的蛤蟆能卖多少钱？
        set {flower_shop_choice_done} = true
        set {earthworm} += 1
        ...
    - 我已经知道你想陷害我的阴谋。
        set {flower_shop_choice_done} = true
        ...
```

### 6.3 访问次数

最简单的方式：每个地点 timeline 开头先自增，再按次数分支。

花店示例：

```text
set {visit_huadian} += 1
if {visit_huadian} == 1:
    花店老板正在玩手机。
    - 占着茅坑不拉屎...
    - 我已经知道你想陷害我的阴谋。
elif {visit_huadian} == 2:
    再次来到花店，她正在关门。
else:
    花店关门了。
jump crossroads
```

注意：Dialogic 的 History 模块只能判断“某个事件是否已经访问过”，不能统计访问次数，所以次数要用变量。

### 6.4 HUD 常驻状态栏

Twine 的 StoryCaption 在 Godot 里没有对应事件，需要自建场景：

1. 新建 `scenes/hud.tscn`：根节点 `Control`，里面放精力/镇定 `ProgressBar`、钱/蚯蚓/花 `Label`、图标 `TextureRect`、花篮状态、地图图片。
2. 用 `CanvasLayer` 挂在游戏场景，确保在对话层之上。
3. 监听 Dialogic 变量变化并刷新。

`scripts/hud/hud.gd` 示例：

```gdscript
extends Control

@onready var energy_bar: ProgressBar = %EnergyBar
@onready var calm_bar: ProgressBar = %CalmBar
@onready var money_label: Label = %MoneyLabel
@onready var earthworm_label: Label = %EarthwormLabel
@onready var flower_label: Label = %FlowerLabel
@onready var hualan_label: Label = %HualanLabel

func _ready() -> void:
	Dialogic.VAR.variable_changed.connect(_on_variable_changed)
	refresh_all()

func _on_variable_changed(info: Dictionary) -> void:
	var name: String = info.get("variable", "")
	var value: Variant = info.get("new_value", null)
	match name:
		"energy":
			energy_bar.value = value
		"calm":
			calm_bar.value = value
		"money":
			money_label.text = "钱：%s元" % value
		"earthworm":
			earthworm_label.text = "蚯蚓：%s只" % value
		"flower":
			flower_label.text = "花：%s朵" % value
		"hualan":
			hualan_label.text = "花篮：有" if value else "花篮：无"

func refresh_all() -> void:
	energy_bar.value = Dialogic.VAR.get_variable("energy", 0)
	calm_bar.value = Dialogic.VAR.get_variable("calm", 0)
	money_label.text = "钱：%s元" % Dialogic.VAR.get_variable("money", 0)
	earthworm_label.text = "蚯蚓：%s只" % Dialogic.VAR.get_variable("earthworm", 0)
	flower_label.text = "花：%s朵" % Dialogic.VAR.get_variable("flower", 0)
	hualan_label.text = "花篮：有" if Dialogic.VAR.get_variable("hualan", false) else "花篮：无"
```

`%EnergyBar` 这种写法要求场景里的节点开启 Unique Name。也可以改用 `get_node("Panel/...")`。

### 6.5 全局结局监视

Twine 在 StoryCaption 里每页检查 `money < 0`、`calm < 0`、`energy < 0`。Godot 里推荐在 HUD 或 autoload 里监听变量变化：

```gdscript
extends Node

var _ending_triggered := false

func _ready() -> void:
	Dialogic.VAR.variable_changed.connect(_on_variable_changed)

func _on_variable_changed(_info: Dictionary) -> void:
	if _ending_triggered:
		return
	var money: float = Dialogic.VAR.get_variable("money", 0)
	var calm: float = Dialogic.VAR.get_variable("calm", 0)
	var energy: float = Dialogic.VAR.get_variable("energy", 0)
	if money < 0:
		_ending_triggered = true
		Dialogic.start_timeline("ending_bankrupt")
	elif calm < 0:
		_ending_triggered = true
		Dialogic.start_timeline("ending_crazy")
	elif energy < 0:
		_ending_triggered = true
		Dialogic.start_timeline("ending_exhausted")
```

也可以不用 autoload，在每个地点 timeline 出口加 `if` 检查再 `jump`。两种方式都要防重入。

注意：Twine 原版只写了“破产结局”和“游戏结束”，但引用了“疯狂结局”和“力竭结局”。迁移时要补全这三个结局 timeline，否则跳转会失败。

### 6.6 玩家输入名字

Dialogic 原生 TextInput 事件对应 Twine 的 `<<textbox>>`：

```text
[text_input text="如果我是王，我叫做：" var="player_name" placeholder="输入名字" default="无名王" allow_empty="false"]
```

之后台词里显示：

```text
此刻我已是万人敬仰的 {player_name}！
```

### 6.7 文字样式与自定义特效

静态样式直接用 BBCode：

```text
[color=#aaf]冷色发光文字[/color]
[font_size=28]加大字号[/font_size]
[outline_color=#55f][outline_size=2]描边发光[/outline_size][/outline_color]
[i]灰白低语[/i]
[img=res://art/icon/flowericon.png] 内嵌图标
```

内置文本效果是行内触发命令，没有闭合标签：

```text
[speed=0.05] 从这里开始按慢速逐字显示
[pause=0.5] 打字到这里时停顿半秒
[signal=some_event] 打字到这里时触发信号
```

注意：`speed / pause / signal / mood` 是行内命令，不是成对 BBCode；`color / font_size / i / img` 这些才是成对 BBCode。

自定义闪烁/抖动/血字效果需要写 `RichTextEffect`。示例 `scripts/text_effects/flicker.gd`：

```gdscript
class_name FlickerTextEffect
extends RichTextEffect

var bbcode := "flicker"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var t := Time.get_ticks_msec() / 1000.0
	char_fx.color.a = 0.5 + 0.5 * sin(t * 8.0 + char_fx.range.x)
	return true
```

注册方式：

1. 在 Dialogic 设置页 Text -> Custom BBCode Effects 里填 `res://scripts/text_effects/flicker.gd`，多个用逗号分隔。
2. 或直接在 `project.godot` 写 `dialogic/text/custom_bbcode_effects="res://scripts/text_effects/flicker.gd"`。
3. 文本里使用 `[flicker]会闪烁的字[/flicker]`。

Twine CSS 对应方案：

| Twine 效果 | Dialogic 方案 |
| --- | --- |
| `.cold-glow` | 静态 `[color=#aaf]` + 描边 |
| `.large-text` | `[font_size=28]` |
| `.grayWhisper` | `[color=#696969][i]...[/i]` |
| `.flicker-text` | 自定义闪烁 `RichTextEffect` |
| `.shake-text` | 自定义抖动 `RichTextEffect`（`char_fx.offset` 加随机偏移） |
| `.blood-text` | 自定义颜色脉动 `RichTextEffect` |
| `.ghost-text` | 自定义浮动/透明度效果 |
| `.fadein-text` | 整段淡入需要自定义 Label/背景层动画，或用 `[wait]` 分步显示 |

### 6.8 点击分段揭示 / 延时显示

Twine 的 `<<linkreplace>> + <<timed>>` 在 Dialogic 里没有同款事件，推荐改成多步选项流。

原版“摘绣球花”的眼睛/嘴/手逐项检查可以写成：

```text
- 仔细看看她的眼睛
    她的眼睛浑浊，眼皮被人用细线吊起，末端缝在眉毛上。
    [wait time="1" hide_text="false" skippable="true"]
- 仔细看看她的嘴
    她的嘴翻动着，喉咙发出模糊的声音。
    [wait time="1" hide_text="false" skippable="true"]
- 仔细看看她的手
    她的手无力的垂着，手背上画了些看不懂的符咒。
    [wait time="1" hide_text="false" skippable="true"]
- 她是怎么立住的？
    jump lizhu
```

开幕1 的“车停了，3 秒后出现下车选项”可以写成：

```text
车停了，车上的人都转头盯着我。
[wait time="3" hide_text="false"]
- 下车
    jump hospital
```

如果一定要“点击一段文字后原地展开”，需要自定义控件：

1. 做一个按钮/面板场景。
2. timeline 里用 `do MyAutoload.show_reveal_panel(...)` 或 `[signal arg="..."]` 打开它。
3. 玩家点击后隐藏面板，再调用 `Dialogic.handle_next_event()` 继续（Alpha 版 API 以实际运行行为为准）。

### 6.9 图片、地图、背景

整页背景图用 Background 事件：

```text
[background arg="res://art/shilin2.png" fade="1.0"]
```

内嵌小图用 BBCode：

```text
[img=res://art/icon/moneyicon.png] 钱：{money}元
```

地图建议直接放进 HUD，而不是塞在台词里；狮岭、露园、妻子、花篮这种大图建议放背景层或单独展示层。

### 6.10 存档、历史、设置、音频

这些 Twine 原版没有，但 Dialogic 自带，后续需要直接启用：

```text
# 音乐/音效
audio music "res://music/bgm.ogg" [loop="true"]
audio sfx "res://sfx/click.wav" [loop="false"]

# 下一句配音
[voice path="res://voice/wife_01.ogg"]

# 存档
[save slot="auto"]
```

历史、设置和自动存档在 Dialogic 设置页开启即可。

### 6.11 调用 GDScript / 发信号

Call 事件可以调用 autoload 方法：

```text
do GameState.unlock_ending("bankrupt")
```

Signal 事件可以通知游戏脚本：

```text
[signal arg="open_wife_panel"]
```

```gdscript
func _ready() -> void:
	Dialogic.signal_event.connect(_on_dialogic_signal)

func _on_dialogic_signal(argument: Variant) -> void:
	if argument == "open_wife_panel":
		show_wife_panel()
```

这组 API 用于自定义小游戏、动画、面板和任何插件事件覆盖不到的逻辑。

## 7. 推荐迁移顺序

1. 建 autoload `GameState`，在 Dialogic 变量编辑器注册全部变量和默认值。
2. 做 HUD 和结局监视，先让变量变化能在屏幕上看到。
3. 按地点建 timeline：开始 -> 医院 -> 路口 -> 花店/狮岭/露园 -> 迷宫 -> 病房 -> 结局。
4. 先把文本、选项、属性扣除、访问次数迁移完，暂不做特效。
5. 加背景大图和 BGM。
6. 加自定义文字特效和点击分段揭示。
7. 最后接存档、历史、设置和配音。

## 8. 注意事项

- 当前 Dialogic 是 `2.0-Alpha-20 WIP`，升级插件前备份 `project.godot` 和全部 `.dtl`。
- `.dtl` 优先用 Dialogic 编辑器编辑；手改时要保持事件缩进格式。
- 中文文件名和路径在当前 `project.godot` 里已经出现过乱码（例如 character 目录配置），尽量用英文命名 timeline 和变量，中文只放在显示文本里。
- 一次性选项、结局跳转都要加布尔守卫，防止重复触发。
- `{变量}` 会被 Dialogic 解析，特殊符号需要转义时用 `\{`。
- 被 `jump` 引用的 timeline 必须真实存在，否则运行时报错。
- 素材已复制到 `art/` 和 `art/icon/`，事件里统一写 `res://art/...`。
