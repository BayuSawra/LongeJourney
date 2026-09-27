extends Node

## 结局监视器：监听 GameState 关键数值，按固定优先级记录并广播结局触发。
signal ending_triggered(ending_id: String)

const ENDING_BANKRUPT := "ending_bankrupt"
const ENDING_CRAZY := "ending_crazy"
const ENDING_EXHAUSTED := "ending_exhausted"

var unlocked_endings: Dictionary = {}


func _ready() -> void:
	if not GameState.value_changed.is_connected(check_endings):
		GameState.value_changed.connect(check_endings)
	check_endings()


func check_endings(_variable: String = "", _new_value: Variant = null) -> void:
	var money: Variant = GameState.get_var("money")
	var calm: Variant = GameState.get_var("calm")
	var energy: Variant = GameState.get_var("energy")
	_check_ending(ENDING_BANKRUPT, money is int and money < 0)
	_check_ending(ENDING_CRAZY, calm is int and calm < 0)
	_check_ending(ENDING_EXHAUSTED, energy is int and energy < 0)


func _check_ending(ending_id: String, triggered: bool) -> void:
	if not triggered or unlocked_endings.has(ending_id):
		return
	unlocked_endings[ending_id] = true
	print("[EndingManager] 触发结局: ", ending_id)
	ending_triggered.emit(ending_id)
