# 伏笔总表

每个伏笔只有三种状态：`open`、`paid-off`、`abandoned`。回收伏笔时把状态改为 `paid-off` 或 `abandoned`，不要删除记录。

## 花数闸口

- 状态: open
- 埋设: 住院部闸口（`02_ward`）
- 回收: unknown
- 关联角色/地点: [护士](characters/nurse.md)、[花](items/flower.md)、[住院部/停尸房](locations/ward.md)
- 说明: 收集至少 5 朵花才能进入病房；不同收集路线会决定主角经历过什么。

## 花店多次到访

- 状态: open
- 埋设: 花店（`04_flower_shop`，visit_huadian）
- 回收: unknown
- 关联角色/地点: [花店老板](characters/flower-shop-owner.md)、[花店](locations/flower-shop.md)
- 说明: 多次到访会推进与老板的互动，可能影响物品获取与结局。

## 假花的代价

- 状态: open
- 埋设: 花店的 jiahua 选项
- 回收: unknown
- 关联角色/地点: [花店老板](characters/flower-shop-owner.md)、[假花](items/fake-flower.md)
- 说明: 假花可能带来短期便利，但风险尚未写明，迁移时需补足代价。

## 名字即王

- 状态: open
- 埋设: 露园改名（`06_luyuan`）
- 回收: unknown
- 关联角色/地点: [无名王](characters/protagonist.md)、[露园](locations/luyuan.md)
- 说明: 玩家可以改名，之后游戏内称号会使用 {player_name}。

## 结局分支

- 状态: open
- 埋设: energy、calm、money 三个全局变量
- 回收: ending_bankrupt（已存在）；ending_crazy、ending_exhausted 待写
- 关联角色/地点: [无名王](characters/protagonist.md)
- 说明: 检查顺序为 money < 0 -> calm < 0 -> energy < 0。

## 妻子的异常

- 状态: open
- 埋设: 病房中妻子的状态（`08_wife_room`）
- 回收: unknown
- 关联角色/地点: [妻子](characters/wife.md)、[病房](locations/wife-room.md)
- 说明: 眼皮缝合、手背符咒等异常是核心悬念，后续剧情需要给出现象背后的解释。
