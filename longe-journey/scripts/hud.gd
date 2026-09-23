extends CanvasLayer

## 常驻 HUD：显示 GameState 中的核心数值，并监听变化实时刷新。

const FIELD_LABELS: Dictionary = {
	"flower": "hud.flower",
	"money": "hud.money",
	"energy": "hud.energy",
	"calm": "hud.calm",
}

const CAUTION_THRESHOLD := 50.0
const LOW_THRESHOLD := 25.0
const NORMAL_COLOR := Color("#b4c5aa")
const CAUTION_COLOR := Color("#d5a85e")
const LOW_COLOR := Color("#d86c6c")

@onready var values: Container = %Values
@onready var settings_button: Button = %SettingsButton
@onready var lore_button: Button = %LoreButton


func _ready() -> void:
	GameState.value_changed.connect(_on_game_state_value_changed)
	Localization.locale_changed.connect(_refresh_all)
	_refresh_all()
	VisualFX.fade_in(self, 0.45)
	settings_button.pressed.connect(func() -> void: SettingsManager.open_settings())
	lore_button.pressed.connect(_on_lore_button_pressed)


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
