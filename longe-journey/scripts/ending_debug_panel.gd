extends CanvasLayer

@onready var _energy_edit: LineEdit = %EnergyEdit
@onready var _calm_edit: LineEdit = %CalmEdit
@onready var _money_edit: LineEdit = %MoneyEdit
@onready var _result_label: Label = %ResultLabel


func _ready() -> void:
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
	_result_label.text = "已写入：energy=%d, calm=%d, money=%d" % [int(energy), int(calm), int(money)]


func _read_number(edit: LineEdit) -> float:
	return float(edit.text)


func _on_ending_triggered(ending_id: String) -> void:
	_result_label.text = "触发结局：" + ending_id
