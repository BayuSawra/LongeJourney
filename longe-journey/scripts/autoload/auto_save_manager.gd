extends Node
## 自动存档触发点：里程碑变量 / Dialogic 时间线 / 结局广播。

const MILESTONE_VARS: Array[String] = [
	"wife", "hualan", "jiahua", "earthworm", "flower",
	"visit_huadian", "visit_shiling", "visit_luyuan", "visit_ting_shifang",
]

var _saving: bool = false

func _ready() -> void:
	if not Dialogic.timeline_started.is_connected(_on_timeline_started):
		Dialogic.timeline_started.connect(_on_timeline_started)
	if not Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.connect(_on_timeline_ended)
	if not GameState.value_changed.is_connected(_on_game_state_changed):
		GameState.value_changed.connect(_on_game_state_changed)
	if not EndingManager.ending_triggered.is_connected(_on_ending_triggered):
		EndingManager.ending_triggered.connect(_on_ending_triggered)

func _on_timeline_started() -> void:
	_request_auto_save()

func _on_timeline_ended() -> void:
	_request_auto_save()

func _on_game_state_changed(variable: String, _new_value: Variant) -> void:
	if MILESTONE_VARS.has(variable):
		_request_auto_save()

func _on_ending_triggered(_ending_id: String) -> void:
	_request_auto_save()

func _request_auto_save() -> void:
	if SaveManager._loading or _saving:
		return
	_saving = true
	call_deferred("_perform_auto_save")

func _perform_auto_save() -> void:
	_saving = false
	SaveManager.save_to_slot("auto", "自动存档")
