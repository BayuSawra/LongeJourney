# 阶段 6：背景 / BGM 资源清单与切换点

> 状态：25 张背景图已生成并登记，覆盖 15 个正式剧情 timeline。表中的剧情 BGM 仍为占位路径，未接入 timeline；主菜单沿用现有 `music/00_start.mp3`。
> 登记日期：2026-09-20

## 资源登记

- 统一清单：`art/backgrounds/manifest.json`。
- 生成元数据：`art/backgrounds/maze_generation.json`、`art/backgrounds/shiling_generation.json`；文件内保留每张图的完整 prompt 与原始输出路径。
- 全部正式背景图尺寸为 `1671–1672×941`（与公交背景一致，接近 16:9）。
- `art/` 中的肖像、线稿、道具和菜单素材继续作为前景或界面资源，不计入下表的 25 张正式环境背景。

## 15 个正式 timeline 的背景覆盖

| 场景 | timeline 文件 | 背景资源（可复用） | 切换点 | BGM（占位，未创建） |
| --- | --- | --- | --- | --- |
| 00 公交车开场 | `timelines/00_start.dtl` | `res://art/bus_interior_normal.png`；`res://art/bus_interior_staring.png` | 进入时显示正常乘坐；车辆停下且乘客转头后切换凝视版 | `res://music/00_start.ogg` |
| 01 医院楼下 | `timelines/01_hospital.dtl` | `res://art/backgrounds/hospital_exterior.png` | timeline 进入时 | `res://music/01_hospital.ogg` |
| 02 病房走廊 | `timelines/02_ward.dtl` | `res://art/backgrounds/ward_corridor.png`；`res://art/backgrounds/hospital_exterior.png`；`res://art/backgrounds/wife_room_curtained.png` | 进入时显示走廊；被拒时回到医院楼下；获准时进入帘幕闭合的妻子病房 | `res://music/02_ward.ogg` |
| 03 十字路口 | `timelines/03_crossroads.dtl` | `res://art/backgrounds/crossroads.png` | timeline 进入时 | `res://music/03_crossroads.ogg` |
| 04 花店 | `timelines/04_flower_shop.dtl` | `res://art/backgrounds/flower_shop_open.png`；`res://art/backgrounds/flower_shop_closed.png` | 开门分支显示开放店面；关门分支切换卷帘门关闭版 | `res://music/04_flower_shop.ogg` |
| 05 狮岭 | `timelines/05_shiling.dtl` | `res://art/backgrounds/shiling_foothill.png`；`res://art/backgrounds/shiling_trail.png`；`res://art/backgrounds/shiling_iron_lion.png`；`res://art/backgrounds/shiling_burning_mountain.png`；`res://art/backgrounds/shiling_temple.png`；`res://art/backgrounds/shiling_closed_gate.png` | 首访按选项从山脚、上山路、铁狮、吐火到白玉狮子庙切换；再访显示关门版 | `res://music/05_shiling.ogg` |
| 06 露园 | `timelines/06_luyuan.dtl` | `res://art/backgrounds/luyuan_garden.png`；`res://art/backgrounds/maze_stone_corridor.png`；`res://art/backgrounds/maze_center.png` | 进入露园时显示入口；三条采花分支均进入石廊后再到中央空地 | `res://music/06_luyuan.ogg` |
| 07 迷宫入口 | `timelines/07_maze_entry.dtl` | `res://art/backgrounds/maze_entry.png` | 进入迷宫、石门关闭后 | `res://music/07_maze_entry.ogg` |
| 07 迷宫左路 | `timelines/07_maze_left.dtl` | `res://art/backgrounds/maze_left_garden.png` | 选择左路后 | `res://music/07_maze_left.ogg` |
| 07 迷宫中路 | `timelines/07_maze_middle.dtl` | `res://art/backgrounds/maze_stone_corridor.png`；`res://art/backgrounds/maze_center.png`；`res://art/backgrounds/maze_exit_road.png` | 进入石廊后到中央空地并切换中央图；逃跑分支转到园外道路 | `res://music/07_maze_middle.ogg` |
| 07 迷宫右路 | `timelines/07_maze_right.dtl` | `res://art/backgrounds/maze_right_bamboo.png` | 选择右路后 | `res://music/07_maze_right.ogg` |
| 07 迷宫出口 | `timelines/07_maze_exit.dtl` | `res://art/backgrounds/maze_exit_road.png` | 离开迷宫、到达园外道路后 | `res://music/07_maze_exit.ogg` |
| 08 妻子的病房 | `timelines/08_wife_room.dtl` | `res://art/backgrounds/wife_room_curtained.png`；`res://art/backgrounds/wife_room_open.png`；`res://art/backgrounds/hospital_stairs.png` | 进入时显示帘幕闭合；剧情揭示后切换开放病房；末段下楼切换楼梯间 | `res://music/08_wife_room.ogg` |
| 09 结局 | `timelines/09_ending.dtl` | `res://art/backgrounds/hospital_stairs.png`；`res://art/backgrounds/hospital_exterior.png` | 进入时为楼梯间；第 005 段切到医院楼下 | `res://music/09_ending.ogg` |
| 10 停尸房 | `timelines/10_morgue.dtl` | `res://art/backgrounds/morgue_occupied.png`；`res://art/backgrounds/morgue_empty.png` | 第一次、第二次进入显示有人使用；第三次起切换空置版 | `res://music/10_morgue.ogg` |

## 备注

- 资源文件共 25 张；同一文件可在多个 timeline 或分支复用，表格按实际剧情切换点重复引用。
- `art/backgrounds/manifest.json` 是正式资源清单；两个 `*_generation.json` 只记录生成过程，不替代资源清单。
- BGM 待 `res://music/*.ogg` 实际创建后，再在对应 timeline 补充 `audio music ...` 事件并检查暂停 / 继续行为。
- `timelines/timeline1_0.dtl` 为历史测试文件，不属于这 15 个正式剧情 timeline。
