extends Node

## Persists GameState vars plus the current Dialogic timeline and scene to user://
## slots, and restores them on load.

const VERSION: int = 2
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


func save(slot: String, slot_name: String = "") -> bool:
	return save_to_slot(slot, slot_name)


func save_to_slot(slot: String, slot_name: String = "") -> bool:
	if slot.is_empty():
		return false

	var data: Dictionary = _build_save_data(slot, slot_name)
	var path: String = _save_path(slot)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(data, false)
	return true


func get_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var root := DirAccess.open("user://dialogic/saves/")
	if root == null:
		return slots

	for slot in root.get_directories():
		if slot.is_empty() or slot == "." or slot == "..":
			continue
		var meta: Dictionary = get_slot_meta(slot)
		var data: Dictionary = _read_save_data(slot)
		var dialogic_state: Dictionary = data.get("dialogic_state", {})
		if not dialogic_state is Dictionary:
			dialogic_state = {}
		slots.append({
			"id": slot,
			"name": meta.get("name", ""),
			"timestamp": meta.get("timestamp", {}),
			"scene": data.get("scene", ""),
			"timeline": dialogic_state.get("timeline", ""),
		})
	return slots


func new_slot_id() -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var stamp: String = "%04d%02d%02d%02d%02d%02d" % [
		now.get("year", 0),
		now.get("month", 0),
		now.get("day", 0),
		now.get("hour", 0),
		now.get("minute", 0),
		now.get("second", 0),
	]
	for i in 10:
		var candidate: String = "%s_%04d" % [stamp, randi() % 10000]
		if not has_save(candidate) and not DirAccess.dir_exists_absolute(_save_path(candidate).get_base_dir()):
			return candidate
	return ""


func rename_slot(slot: String, new_name: String) -> bool:
	var data: Dictionary = _read_save_data(slot)
	if data.is_empty():
		return false
	var meta: Dictionary = data.get("meta", {})
	if not meta is Dictionary:
		meta = {}
	meta["name"] = new_name
	data["meta"] = meta
	var path: String = _save_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(data, false)
	return true


func get_slot_meta(slot: String) -> Dictionary:
	var data: Dictionary = _read_save_data(slot)
	if data.is_empty():
		return {}
	var meta: Dictionary = data.get("meta", {})
	if not meta is Dictionary:
		meta = {}
	return meta


func load(slot: String) -> bool:
	if slot.is_empty() or _loading:
		return false
	var data: Dictionary = _read_save_data(slot)
	if data.is_empty() or data.get("version", 0) != VERSION:
		return false

	_loading = true
	var success: bool = await _do_load(data)
	_loading = false
	return success


func has_save(slot: String) -> bool:
	return FileAccess.file_exists(_save_path(slot))


func delete_save(slot: String) -> void:
	DirAccess.remove_absolute(_save_path(slot))


func get_save_meta(slot: String) -> Dictionary:
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

	var current_timeline: String = str(Dialogic.current_timeline)
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


func _build_save_data(slot: String, slot_name: String) -> Dictionary:
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

	var now: Dictionary = Time.get_datetime_dict_from_system()
	return {
		"version": VERSION,
		"scene": scene,
		"dialogic_state": dialogic_state,
		"game_state": game_state,
		"meta": {
			"id": slot,
			"name": slot_name,
			"timestamp": {
				"year": now.get("year", 0),
				"month": now.get("month", 0),
				"day": now.get("day", 0),
				"hour": now.get("hour", 0),
				"minute": now.get("minute", 0),
				"second": now.get("second", 0),
			},
		},
	}


func _valid_dialogic_state(dialogic_state: Dictionary) -> bool:
	var timeline: Variant = dialogic_state.get("timeline", "")
	var subsystems: Variant = dialogic_state.get("subsystems", {})
	return (timeline is String and not (timeline as String).is_empty()) \
		or (subsystems is Dictionary and not (subsystems as Dictionary).is_empty())


func _save_path(slot: String) -> String:
	return "user://dialogic/saves/%s/save.sav" % slot
