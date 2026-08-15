extends CanvasLayer

## 常驻 HUD：显示 GameState 中的核心数值，并监听变化实时刷新。

const FIELD_LABELS: Dictionary = {
	"energy": "能量",
	"calm": "平静",
	"money": "金币",
}

@onready var values: HBoxContainer = %Values


func _ready() -> void:
	GameState.value_changed.connect(_on_game_state_value_changed)
	_refresh_all()


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
	label.text = "%s %s" % [FIELD_LABELS[variable], GameState.get_var(variable)]
