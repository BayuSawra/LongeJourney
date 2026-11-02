extends CanvasLayer

## 常驻 HUD：显示 GameState 中的核心数值，并监听变化实时刷新。

const FIELD_LABELS: Dictionary = {
	"flower": "hud.flower",
	"money": "hud.money",
	"energy": "hud.energy",
	"calm": "hud.calm",
}

## 地点由当前 timeline 文件名决定。新增 timeline 时在此登记，并补对应 PO 文案。
const LOCATION_KEYS: Dictionary = {
	"00_start": "location.bus",
	"01_hospital": "location.hospital",
	"02_ward": "location.ward",
	"03_crossroads": "location.crossroads",
	"04_1_flower_shop": "location.flower_shop",
	"04_2_flower_shop": "location.flower_shop",
	"04_flower_shop": "location.flower_shop",
	"05_1shiling": "location.shiling",
	"05_2shiling": "location.shiling",
	"05_3shiling": "location.shiling",
	"05_4shiling": "location.shiling",
	"05_shiling": "location.shiling",
	"06_luyuan": "location.luyuan",
	"07_maze_entry": "location.maze",
	"07_maze_exit": "location.maze",
	"07_maze_left": "location.maze",
	"07_maze_middle": "location.maze",
	"07_maze_right": "location.maze",
	"08_wife_room": "location.wife_room",
	"09_ending": "location.ending",
	"10_morgue": "location.morgue",
	"timeline1_0": "location.debug",
}

const CAUTION_THRESHOLD := 50.0
const LOW_THRESHOLD := 25.0
const NORMAL_COLOR := Color("#b4c5aa")
const CAUTION_COLOR := Color("#d5a85e")
const LOW_COLOR := Color("#d86c6c")

## 地图点的位置和大小只在 scenes/hud.tscn 的 Map 子节点上调整。
const MAP_LOCATION_KEYS: Array[String] = [
	"location.hospital",
	"location.flower_shop",
	"location.crossroads",
	"location.shiling",
	"location.luyuan",
]
const MAP_DOT_IDLE := Color(1, 1, 1, 1)
const MAP_DOT_HERE := Color(1, 0, 0, 1)

@onready var values: Container = %Values
@onready var settings_button: Button = %SettingsButton
@onready var lore_button: Button = %LoreButton
@onready var where_u_are: Label = %whereUare


func _ready() -> void:
	GameState.value_changed.connect(_on_game_state_value_changed)
	Localization.locale_changed.connect(_refresh_all)
	Dialogic.timeline_started.connect(_on_timeline_started)
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	_refresh_all()
	VisualFX.fade_in(self, 0.45)
	settings_button.pressed.connect(func() -> void: SettingsManager.open_settings())
	lore_button.pressed.connect(_on_lore_button_pressed)


func _exit_tree() -> void:
	if Dialogic.timeline_started.is_connected(_on_timeline_started):
		Dialogic.timeline_started.disconnect(_on_timeline_started)
	if Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.disconnect(_on_timeline_ended)


func _on_timeline_started() -> void:
	_refresh_location()


func _on_timeline_ended() -> void:
	_refresh_location()


func _on_lore_button_pressed() -> void:
	var packed := load("res://scenes/lore_browser.tscn") as PackedScene
	if packed == null:
		return
	get_tree().current_scene.add_child(packed.instantiate())


func _on_game_state_value_changed(variable: String, _new_value: Variant) -> void:
	if variable in FIELD_LABELS:
		_refresh(variable)


func _refresh_all() -> void:
	for variable in FIELD_LABELS:
		_refresh(variable)
	_refresh_location()


func _refresh_location() -> void:
	if where_u_are == null:
		push_error("HUD 缺少 whereUare")
		get_tree().quit(2)
		return
	var location_key := ""
	if Dialogic.current_timeline != null:
		var timeline_id := Dialogic.current_timeline.resource_path.get_file().get_basename()
		if not LOCATION_KEYS.has(timeline_id):
			push_error("HUD 未登记地点：%s" % timeline_id)
			get_tree().quit(2)
			return
		location_key = String(LOCATION_KEYS[timeline_id])
		where_u_are.text = Localization.text(location_key)
	else:
		where_u_are.text = ""
	_refresh_map_dots(location_key)


func _refresh_map_dots(location_key: String) -> void:
	var map := get_node_or_null("Map")
	if map == null:
		push_error("HUD 缺少 Map")
		get_tree().quit(2)
		return
	var dots := {}
	for child in map.get_children():
		if not child.has_meta("location_key"):
			continue
		var key := String(child.get_meta("location_key"))
		if not MAP_LOCATION_KEYS.has(key):
			push_error("Map 点登记了未知地点：%s（%s）" % [child.name, key])
			get_tree().quit(2)
			return
		if dots.has(key):
			push_error("Map 地点重复：%s" % key)
			get_tree().quit(2)
			return
		if not child is CanvasItem:
			push_error("Map 点不是可视节点：%s" % child.name)
			get_tree().quit(2)
			return
		dots[key] = child
	for key in MAP_LOCATION_KEYS:
		if not dots.has(key):
			push_error("Map 缺少地点点：%s" % key)
			get_tree().quit(2)
			return
		var dot := dots[key] as CanvasItem
		dot.self_modulate = MAP_DOT_HERE if key == location_key else MAP_DOT_IDLE


func _refresh(variable: String) -> void:
	var label: Label = values.get_node_or_null(variable)
	if label == null:
		return
	var value: Variant = GameState.get_var(variable)
	label.text = Localization.format_text(FIELD_LABELS[variable], {"value": value})
	if variable in ["energy", "calm"]:
		_apply_status_style(variable, value)


func _apply_status_style(variable: String, raw_value: Variant) -> void:
	var value := float(raw_value)
	var color := NORMAL_COLOR
	if value <= LOW_THRESHOLD:
		color = LOW_COLOR
	elif value <= CAUTION_THRESHOLD:
		color = CAUTION_COLOR
	var label: Label = values.get_node_or_null(variable)
	if label != null:
		label.add_theme_color_override("font_color", color)
	var bar: ProgressBar = values.get_node_or_null("%s_bar" % variable)
	if bar == null:
		return
	bar.value = clampf(value, 0.0, 100.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", fill)
