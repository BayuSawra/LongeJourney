extends Node

## Persists GameState vars plus the current Dialogic timeline and scene to user://
## slots, and restores them on load.

const VERSION: int = 1
const GAME_STATE_VARS: Array[String] = [
	"energy",
	"calm",
	"money",
	"earthworm",
	"flower",
	"wife",
	"hualan",
	"jiahua",
	"player_name",
	"visit_huadian",
	"visit_shiling",
	"visit_luyuan",
	"visit_ting_shifang",
]

var _loading: bool = false


func save(slot: String) -> bool:
	if slot.is_empty():
		return false

	var data: Dictionary = _build_save_data()
	var path: String = _save_path(slot)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(data, false)
	return true


func load(slot: String) -> bool:
	if slot.is_empty() or _loading:
		return false
	var data: Dictionary = _read_save_data(slot)
	if data.is_empty() or data.get("version", 0) != VERSION:
		return false

	_loading = true
	var success: bool = _do_load(data)
	_loading = false
	return success


func has_save(slot: String) -> bool:
	return FileAccess.file_exists(_save_path(slot))


func delete_save(slot: String) -> void:
	DirAccess.remove_absolute(_save_path(slot))


func get_meta(slot: String) -> Dictionary:
	var data: Dictionary = _read_save_data(slot)
	if data.is_empty() or data.get("version", 0) != VERSION:
		return {}

	var game_state: Dictionary = data.get("game_state", {})
	if not game_state is Dictionary:
		game_state = {}
	var dialogic_state: Dictionary = data.get("dialogic_state", {})
	if not dialogic_state is Dictionary:
		dialogic_state = {}

	return {
		"version": data.get("version", VERSION),
		"scene": data.get("scene", ""),
		"timeline": dialogic_state.get("timeline", ""),
		"game_state": game_state,
	}


func _read_save_data(slot: String) -> Dictionary:
	var path: String = _save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var raw: Variant = file.get_var(false)
	if not raw is Dictionary:
		return {}
	return raw


func _do_load(data: Dictionary) -> bool:
	var game_state: Dictionary = data.get("game_state", {})
	if not game_state is Dictionary:
		game_state = {}
	for variable in GAME_STATE_VARS:
		if game_state.has(variable):
			GameState.set_var(variable, game_state[variable])

	var dialogic_state: Dictionary = data.get("dialogic_state", {})
	if not dialogic_state is Dictionary:
		dialogic_state = {}
	if not _valid_dialogic_state(dialogic_state):
		return false

	var current_timeline: String = Dialogic.current_timeline
	if not current_timeline.is_empty():
		if Dialogic.has_method("end_timeline"):
			Dialogic.end_timeline(true)
		await get_tree().process_frame

	var scene: String = data.get("scene", "")
	if not scene is String:
		scene = ""
	if not scene.is_empty() and get_tree().current_scene != null \
			and get_tree().current_scene.scene_file_path != scene:
		get_tree().change_scene_to_file(scene)
		await get_tree().process_frame

	var state := DialogicSaveState.new()
	state.timeline = dialogic_state.get("timeline", "")
	state.event_index = int(dialogic_state.get("event_index", -1))
	var subsystems: Variant = dialogic_state.get("subsystems", {})
	if subsystems is Dictionary:
		state.subsystems = subsystems
	Dialogic.load_full_state(state)
	if Dialogic.current_timeline.is_empty() and not state.timeline.is_empty():
		Dialogic.start_timeline(state.timeline, state.event_index)
	return true


func _build_save_data() -> Dictionary:
	var game_state: Dictionary = {}
	for variable in GAME_STATE_VARS:
		game_state[variable] = GameState.get_var(variable)

	var dialogic_state: Dictionary = {}
	if Dialogic.has_method("get_full_state"):
		var full_state: DialogicSaveState = Dialogic.get_full_state()
		dialogic_state = {
			"timeline": full_state.timeline,
			"event_index": full_state.event_index,
			"subsystems": full_state.subsystems,
		}

	var scene: String = ""
	if get_tree().current_scene != null:
		scene = get_tree().current_scene.scene_file_path

	return {
		"version": VERSION,
		"scene": scene,
		"dialogic_state": dialogic_state,
		"game_state": game_state,
	}


func _valid_dialogic_state(dialogic_state: Dictionary) -> bool:
	var timeline: Variant = dialogic_state.get("timeline", "")
	var subsystems: Variant = dialogic_state.get("subsystems", {})
	return (timeline is String and not (timeline as String).is_empty()) \
		or (subsystems is Dictionary and not (subsystems as Dictionary).is_empty())


func _save_path(slot: String) -> String:
	return "user://dialogic/saves/%s/save.sav" % slot
