# 阶段 6：背景 / BGM 资源清单与切换点

> 状态：登记完成；BGM 仅保留接口占位，资源未创建前不添加 `audio music ...` / `audio sfx ...` 事件。
> 登记日期：2026-08-19

## 总览

- `art/` 已确认存在：`1.png`、`banner.png`、`hualan.png`、`IMG_0198.JPG`、`jianshan2.png`、`jiashan1.png`、`map.png`、`shilin1.png`、`shilin2.png`、`wife.png`、`封面.png`，以及 `art/icon/` 下的图标。
- 项目当前不存在 `music/`、`sfx/` 目录，也没有任何 BGM / 音效资源。
- 因此所有场景的 BGM 统一登记为占位路径 `res://music/<scene>.ogg`，标记为“资源未创建 / 跳过”。

## 场景背景 / BGM 切换点

| 场景 | timeline 文件 | 背景资源 | 切换点 | BGM（占位，未创建） | 状态 |
| --- | --- | --- | --- | --- | --- |
| 00 开始菜单 | `timelines/00_start.dtl` | `res://art/1.png`（由 `scenes/mianMenu.tscn` 直接使用，不在 timeline 内切换） | 场景进入时 | `res://music/00_start.ogg` | BGM 跳过；背景无需在 timeline 补事件 |
| 01 医院 | `timelines/01_hospital.dtl` | 缺少可用背景资源 | 未登记 | `res://music/01_hospital.ogg` | 缺少资源 / 跳过 |
| 02 病房 | `timelines/02_ward.dtl` | 缺少可用背景资源（timeline 内“下一阶段接入 08_wife_room”为占位注释，不是背景事件） | 未登记 | `res://music/02_ward.ogg` | 缺少资源 / 跳过 |
| 03 路口 | `timelines/03_crossroads.dtl` | 缺少可用背景资源 | 未登记 | `res://music/03_crossroads.ogg` | 缺少资源 / 跳过 |
| 04 花店 | `timelines/04_flower_shop.dtl` | 缺少可用背景资源 | 未登记 | `res://music/04_flower_shop.ogg` | 缺少资源 / 跳过 |
| 05 狮岭 | `timelines/05_shiling.dtl` | `res://art/shilin2.png` | timeline 首行（当前位置提示）之后立即切换 | `res://music/05_shiling.ogg` | 背景已补事件；BGM 跳过 |
| 06 露园 | `timelines/06_luyuan.dtl` | `res://art/jianshan2.png` | timeline 首行（当前位置提示）之后立即切换 | `res://music/06_luyuan.ogg` | 背景已补事件；BGM 跳过 |
| 07 迷宫入口 | `timelines/07_maze_entry.dtl` | 缺少可用背景资源 | 未登记 | `res://music/07_maze_entry.ogg` | 缺少资源 / 跳过 |
| 07 迷宫左 | `timelines/07_maze_left.dtl` | 缺少可用背景资源 | 未登记 | `res://music/07_maze_left.ogg` | 缺少资源 / 跳过 |
| 07 迷宫中 | `timelines/07_maze_middle.dtl` | 缺少可用背景资源 | 未登记 | `res://music/07_maze_middle.ogg` | 缺少资源 / 跳过 |
| 07 迷宫右 | `timelines/07_maze_right.dtl` | 缺少可用背景资源 | 未登记 | `res://music/07_maze_right.ogg` | 缺少资源 / 跳过 |
| 07 迷宫出口 | `timelines/07_maze_exit.dtl` | 缺少可用背景资源 | 未登记 | `res://music/07_maze_exit.ogg` | 缺少资源 / 跳过 |
| 08 妻子的病房 | `timelines/08_wife_room.dtl` | `res://art/wife.png` | timeline 首行（当前位置提示）之后立即切换 | `res://music/08_wife_room.ogg` | 背景已补事件；BGM 跳过 |
| 09 结局 | `timelines/09_ending.dtl` | 缺少可用背景资源 | 未登记 | `res://music/09_ending.ogg` | 缺少资源 / 跳过 |

## 备注

- 不将 `hualan.png`、`jiashan1.png`、`shilin1.png`、`banner.png`、`map.png`、`封面.png` 及 `art/icon/` 图标默认登记为某场景首屏背景，因为没有 timeline / scene 引用能确认用途。
- `timelines/timeline1_0.dtl` 为乱码测试文件，不在本次范围内。
- BGM 接入方式为接口占位：待 `res://music/*.ogg` 资源实际创建后，再在对应 timeline 补充 `audio music ...` 事件并验证暂停 / 继续行为。
