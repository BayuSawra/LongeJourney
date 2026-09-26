# 阶段 6：背景视觉验收与剧情连续性检查

> 状态：待执行
> 登记日期：2026-09-21
> 上游清单：`docs/phase6_background_bgm_inventory.md`
> 目标：交给其他 agent 执行第二轮背景审查、连续性检查和实机验收。

## 1. 验收目标

本轮处理三件事：

1. 收回不必要的“废墟感”，保留百年孤独式的荒诞、诡异和生活质感。
2. 检查同一地点及相邻剧情画面的空间、年代、天气和陈设连续性。
3. 在实机中确认 `7F / 5-05` 门牌和对话阅读体验。

旧、冷清、潮湿可以保留，但画面不能像灾后遗址、完全停业场所或无人维护的废墟。异常应来自人物行为、重复秩序和细节错位。

## 2. 执行边界

- 保留 Dialogic、业务 Autoload、GL Compatibility 和现有资源路径。
- 不修改 `addons/`、GameState、存档逻辑或第三方插件。
- 不把中文剧情文字、楼层或房间号烘焙进背景图片。
- 不凭“感觉不一致”直接重绘；必须先记录具体问题，再修改对应资产。
- 修改背景行为时同步更新 `long-journey/tests/` 回归测试。
- 不提交 `.godot/`、截图、验证报告、工具下载、密钥或本地配置。

## 3. 并行执行分工

### Agent A：生活痕迹与场所功能

负责以下资产，文件名和尺寸必须保持不变：

- `art/bus_interior_normal.png`
- `art/bus_interior_staring.png`
- `art/backgrounds/hospital_exterior.png`
- `art/backgrounds/ward_corridor.png`
- `art/backgrounds/crossroads.png`
- `art/backgrounds/flower_shop_open.png`

检查并按需调整：

- 公交：乘客、司机区域、扶手磨损、塑料袋或雨具；normal 与 staring 保持同一机位和车体，只改变人物状态。
- 医院：值班、病人、家属、护理推车、登记表或生活杂物；建筑旧但仍在使用。
- 路口：公交、摩托车、自行车、店铺灯光、过路人和通行痕迹。
- 花店：营业灯光、花材、包装纸、水桶、工作台和店主活动痕迹。

避免：大面积坍塌、封锁带、灾后痕迹、现代商业综合体、豪华医疗中心、统一的阴森滤镜和可读中文招牌。

### Agent B：剧情设定修正

负责以下资产：

- `art/backgrounds/shiling_bandit_ambush.png`
- `art/backgrounds/morgue_interior_drawers.png`

验收要求：

- 狮岭必须能看出是现代演员或县城演出队：廉价仿古服装、油彩不均、塑料或泡沫刀、简易音箱、折叠椅或景区营业痕迹。不得呈现真正古代山匪、历史战争或专业武侠片。
- 停尸房必须是简陋县医院后勤房：一两张尸床、铁桶、登记板、清洁用品、备用床单和淡黄色空花篮。不得由多格西式金属尸柜主导构图，不出现尸体、血腥或现代法医中心。

### Agent C：门牌与实机阅读

负责检查：

- `scenes/scene_1.tscn`
- `scripts/ward_door_sign.gd`
- `localization/zh_CN.po`
- `localization/en.po`

门牌文字必须由 Dialogic 文本或运行时界面提供，内容为 `7F / 5-05`。确认它只在 `hospital_ward_door_505.png` 当前背景显示，切换背景、读档、快速推进和重复进入后状态都正确。

## 4. 地点连续性检查

按以下顺序逐组检查。每组必须记录“通过 / 需要调整 / 阻塞”，需要调整时写明具体文件、具体不连续点、修改方式和验证方式。

1. 花店：`flower_shop_open` → `flower_shop_interior_buckets` → `flower_shop_closed`。
2. 路口与公交：`crossroads` → `crossroads_bus_sunflower`，并对照 `bus_interior_normal` / `bus_interior_staring`。
3. 医院：`hospital_exterior` → `ward_corridor` → `hospital_ward_door_505` → `wife_room_curtained` / `wife_room_open`。
4. 停尸房：`morgue_occupied` → `morgue_interior_drawers` → `morgue_empty`。
5. 狮岭：山脚、山路、演员伏击、铁狮、庙和关门版之间的道路方向、天气与地貌。
6. 迷宫：入口、石廊、中央空地、固定女子、逃跑道路和出口道路之间的园林材质与光线。

每组检查：

- 建筑朝向、门窗、道路方向和主要陈设是否能相互对应。
- 时间、天气、光线和色温是否出现无剧情依据的跳变。
- 人物进入或离开画面时，空间位置是否合理。
- 同一地点是否突然从“有人使用”变成“完全废弃”。
- 异常细节是否服务当前剧情，而不是随机增加恐怖元素。
- 是否出现明显欧式建筑、欧式园林或与县城设定冲突的装饰。

## 5. P0 门牌实机流程

从正常入口完整运行：

1. 进入医院外景。
2. 进入病房走廊。
3. 走到或切换到 5-05 门前。
4. 确认 `7F / 5-05` 出现。
5. 推进至少一段对话。
6. 执行一次淡入淡出或背景切换。
7. 读档后再次进入该位置。

至少使用一个宽屏比例和一个非宽屏比例，检查：

- 位置是否稳定，是否覆盖在门牌区域。
- 是否被对话框、人物立绘或转场遮挡。
- 字体大小、颜色和描边是否清晰。
- 显示与隐藏时机是否正确。
- 跳过对话、快速点击和重复触发后是否残留或丢失。

记录截图或录屏时间点供复核，但不要把证据文件提交到仓库。

## 6. 资产修改规则

- 背景仍保持横版 16:9、`1672×941`、RGB PNG、原文件名和原资源路径。
- 背景图不生成可读中文、数字、英文招牌或房间号。
- 公交 normal/staring 必须保持同机位和车体结构。
- 修改图片后同步更新 `art/backgrounds/manifest.json` 的 prompt、尺寸或生成记录。
- `maze_stone_corridor.png` 当前仙人球花设定可以保留；只有发现连续性问题时才调整。
- 不改已确认符合设定的狮岭山脚、山路、铁狮、庙、关门版、露园、假山迷宫、竹窗、血迹、固定女子、中文园门、妻子病房和楼梯场景。

## 7. 自动验证

在 `long-journey/` 目录运行：

```powershell
python -m pytest tools/tests
python tools/verify.py
git diff --check
```

若系统 Godot 版本不符合项目固定版本，使用仓库内的 `Godot_v4.7-stable_win64_console.exe` 显式运行 `tools/verify.py`，并记录实际命令和失败原因。不得跳过导入、gdUnit4 或启动冒烟来换取通过。

## 8. 完成定义

任务只有在以下条件全部满足后完成：

1. 六张重点日常背景完成第二轮视觉验收。
2. 狮岭演员伏击和停尸房符合文字设定。
3. 六组地点连续性检查均有明确结论和证据。
4. `7F / 5-05` 在实机中可读，且在转场、读档和重复触发后状态正确。
5. Python 测试、资源导入、gdUnit4、启动冒烟和 `git diff --check` 全部通过。
6. 每项修改都能追溯到具体文件和具体问题。

## 9. 验收记录模板

复制以下条目逐组填写：

```text
场景组：
结果：通过 / 需要调整 / 阻塞
涉及文件：
具体问题：
修改方式：
验证方式：
证据：
```
