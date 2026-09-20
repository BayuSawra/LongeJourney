extends CanvasLayer

@onready var _energy_edit: LineEdit = %EnergyEdit
@onready var _calm_edit: LineEdit = %CalmEdit
@onready var _money_edit: LineEdit = %MoneyEdit
@onready var _result_label: Label = %ResultLabel


var _result_key := ""
var _result_values: Dictionary = {}

func _ready() -> void:
	Localization.locale_changed.connect(_refresh_result)
	_energy_edit.text = str(GameState.get_var("energy"))
	_calm_edit.text = str(GameState.get_var("calm"))
	_money_edit.text = str(GameState.get_var("money"))
	if not EndingManager.ending_triggered.is_connected(_on_ending_triggered):
		EndingManager.ending_triggered.connect(_on_ending_triggered)


func _exit_tree() -> void:
	if EndingManager.ending_triggered.is_connected(_on_ending_triggered):
		EndingManager.ending_triggered.disconnect(_on_ending_triggered)


func _on_apply_pressed() -> void:
	var energy: float = _read_number(_energy_edit)
	var calm: float = _read_number(_calm_edit)
	var money: float = _read_number(_money_edit)
	GameState.set_var("energy", int(energy))
	GameState.set_var("calm", int(calm))
	GameState.set_var("money", int(money))
	_result_key = "ending.applied"
	_result_values = {"energy": int(energy), "calm": int(calm), "money": int(money)}
	_refresh_result()


func _read_number(edit: LineEdit) -> float:
	return float(edit.text)


func _on_ending_triggered(ending_id: String) -> void:
	_result_key = "ending.triggered"
	_result_values = {"ending": ending_id}
	_refresh_result()


func _refresh_result() -> void:
	if _result_key.is_empty():
		return
	var values := _result_values.duplicate()
	if values.has("ending"):
		values["ending"] = Localization.text("ending." + values["ending"])
	_result_label.text = Localization.format_text(_result_key, values)
