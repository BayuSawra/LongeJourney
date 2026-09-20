extends CanvasLayer

## 常驻 HUD：显示 GameState 中的核心数值，并监听变化实时刷新。

const FIELD_LABELS: Dictionary = {
	"flower": "hud.flower",
	"money": "hud.money",
}

@onready var values: HBoxContainer = %Values
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
	label.text = Localization.format_text(FIELD_LABELS[variable], {"value": GameState.get_var(variable)})
