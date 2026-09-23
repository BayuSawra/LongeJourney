# 阶段 6 背景视觉验收记录

日期：2026-09-22

## 1. 花店

```text
场景组：花店：flower_shop_open → flower_shop_interior_buckets → flower_shop_closed
结果：通过
涉及文件：art/backgrounds/flower_shop_open.png、art/backgrounds/flower_shop_interior_buckets.png、art/backgrounds/flower_shop_closed.png、timelines/04_flower_shop.dtl、art/backgrounds/manifest.json
具体问题：原开放图存在时钟和花卡的伪文字形状；室内倒桶、泥土和蚯蚓属于剧情触发后的异常，未构成无因废墟。
修改方式：重绘开放图，保留半开卷帘、工作台、店主、花材和水桶，时钟改为无数字刻度、花卡留白；同步 manifest 的 prompt、生成记录和验收修订。
验证方式：实图对照三张背景和 04_flower_shop.dtl 的分支顺序；资源验证通过。
证据：python tools/check_timelines.py；python tools/verify.py；三张背景均为 1672×941 RGB PNG。
```

## 2. 路口与公交

```text
场景组：路口与公交：crossroads → crossroads_bus_sunflower；bus_interior_normal → bus_interior_staring
结果：通过
涉及文件：art/backgrounds/crossroads.png、art/backgrounds/crossroads_bus_sunflower.png、art/bus_interior_normal.png、art/bus_interior_staring.png、timelines/00_start.dtl、timelines/03_crossroads.dtl、art/backgrounds/manifest.json
具体问题：原递花图使用了老绿公交和湖边窄路，与十字路口的白蓝公交及道路方向不连续；公交图顶部线路牌含伪文字形状。
修改方式：递花图改为同一县城十字路口、白蓝公交、同一冷雨天气，并保留乘客递向日葵；normal/staring 重绘为同车体同机位，线路牌留白，staring 只改变乘客凝视状态。
验证方式：实图逐组对照车体、路口建筑、道路方向和天气；00_start 与 03_crossroads 的切换顺序、尺寸和资源引用通过自动验证。
证据：python tools/check_timelines.py；python tools/verify.py；normal/staring 视图机位、扶手、座椅和车窗结构一致。
```

## 3. 医院

```text
场景组：医院：hospital_exterior → ward_corridor → hospital_ward_door_505 → wife_room_curtained / wife_room_open
结果：通过
涉及文件：art/backgrounds/hospital_exterior.png、art/backgrounds/ward_corridor.png、art/backgrounds/hospital_ward_door_505.png、art/backgrounds/wife_room_curtained.png、art/backgrounds/wife_room_open.png、timelines/01_hospital.dtl、timelines/02_ward.dtl、timelines/08_wife_room.dtl、scenes/scene_1.tscn、scripts/ward_door_sign.gd、localization/zh_CN.po、localization/en.po
具体问题：外景和住院走廊需要保留在用医院的生活痕迹；走廊时钟与登记板不得出现可读数字或文字。门前画面较暗，但仍有工作灯、护理车、座椅和维护中的护墙，且剧情文字明确为“灰暗的走廊”。
修改方式：外景和走廊保留护士站、病人、家属、推车、照明和生活杂物；走廊时钟改为无数字刻度、登记板留白。门牌不烘焙文字，由运行时 Label 提供 `7F / 5-05`。
验证方式：图形驱动从主菜单正常进入 00_start、01_hospital、02_ward；在门牌背景执行对话推进、快速推进、0.6 秒淡入淡出、存档、读档和重复进入。宽屏与非宽屏均检查 COVER 映射和隐藏时机。
证据：`reports/phase6-visual-qa-2a3352b7a683/summary.json` 为两种窗口尺寸 passed；截图只保留在本地 ignored reports，不提交。
```

## 4. 停尸房

```text
场景组：停尸房：morgue_occupied → morgue_interior_drawers → morgue_empty
结果：通过
涉及文件：art/backgrounds/morgue_occupied.png、art/backgrounds/morgue_interior_drawers.png、art/backgrounds/morgue_empty.png、timelines/10_morgue.dtl、art/backgrounds/manifest.json
具体问题：原室内图由西式尸柜和废墟感主导；morgue_empty 原尺寸为 1671×941。
修改方式：改为县医院后勤房，保留一两张盖布推床、铁桶、登记板、清洁用品、备用床单和淡黄色空花篮，无尸体、血腥或多格尸柜；将 morgue_empty 统一为 1672×941 并更新 manifest。
验证方式：实图对照三张背景及 10_morgue.dtl 的首次/再次进入顺序；资源尺寸、资源引用和 gdUnit4 通过。
证据：python tools/verify.py；全部 35 张正式背景均为 1672×941 RGB PNG。
```

## 5. 狮岭

```text
场景组：狮岭：shiling_foothill / shiling_trail → shiling_bandit_ambush → shiling_iron_lion → shiling_temple / shiling_closed_gate
结果：通过
涉及文件：art/backgrounds/shiling_bandit_ambush.png、timelines/05_shiling.dtl、art/backgrounds/manifest.json
具体问题：原伏击图读作真正古代山匪，缺少县城演出队和景区营业痕迹。
修改方式：保留湿山路、雨雾、岩壁和道路方向，加入现代演员露出的帽子、运动鞋和夹克、廉价戏服、不均油彩、塑料/泡沫刀、便携音箱和折叠椅；同步生成记录。
验证方式：实图确认主体一眼读作低成本景区演出拦路，不是历史战争；按 05_shiling.dtl 复核山路到伏击再到铁狮的天气、地貌和道路方向。
证据：python tools/check_timelines.py；python tools/verify.py；候选背景 1672×941 RGB PNG。
```

## 6. 迷宫

```text
场景组：迷宫：entry → left/right → stone_corridor → center → pinned_woman / escape_road → exit_road
结果：通过
涉及文件：art/backgrounds/maze_entry.png、maze_left_garden.png、maze_right_bamboo.png、maze_stone_corridor.png、maze_blood_trail.png、maze_center.png、maze_pinned_woman.png、maze_escape_road.png、maze_exit_road.png、timelines/07_maze_*.dtl、localization/zh_CN.po
具体问题：初审将入口、内部冷紫灰阴影和出口紫灰日光误判为无依据的日夜跳变。
修改方式：不改资产。剧情文字明确入口“今日有戏”“灯火通明”，中段写明“太阳是紫灰色的”，出口写明“紫灰色日光像隔着一层旧玻璃”；仙人球花设定保留。
验证方式：按五个 07_maze timeline 对照背景顺序、园林材质、湿石路、光线和剧情文本；时间层次由文本支持。
证据：python tools/check_timelines.py；python tools/verify.py；未发现欧式建筑或无剧情依据的材质跳变。
```

## P0 门牌实机

```text
入口：主菜单开始按钮 → 00_start → 01_hospital → 02_ward
窗口：1152×648、1024×768
结果：通过
显示：仅 hospital_ward_door_505.png 当前背景显示 Label；本地化 key 为 ui.ward_door_locator.text，中英文均解析为 7F / 5-05。
状态：对话推进、快速推进、0.6 秒转场、存档、读档和重复进入均通过；进入 wife_room_curtained 后门牌隐藏，无残留。
位置：按 1672×941 原图和 KEEP_ASPECT_COVERED 的 center-crop 映射；宽屏和 4:3 窗口均在门牌区域内，非宽屏画布按项目配置保持 16:9。
证据：tools/phase6_visual_qa.py；reports/phase6-visual-qa-2a3352b7a683/summary.json；两个尺寸的截图未提交。
```

## 自动门槛

- `python -m pytest tools/tests`：54 passed。
- `python tools/verify.py --godot D:\project_godot\LongeJourney\.local-tools\godot-4.7\Godot_v4.7-stable_win64_console.exe`：版本、隔离冷导入、资源扫描、资源验证、gdUnit4 和启动冒烟全部通过。
- `git diff --check`：通过。
- 正式背景资源：35 张，全部存在且为 `1672×941 RGB PNG`；manifest 引用无缺失。
