extends Node

## Persists GameState vars plus the current Dialogic timeline and scene to user://
## slots, and restores them on load.

const VERSION: int = 3
const SAVE_ROOT := "user://dialogic/saves"
const SLOT_MAX_LENGTH := 64
var last_error := ""
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
	last_error = ""
	if not _is_valid_slot(slot):
		last_error = "save.error_invalid_slot"
		return false

	var data: Dictionary = _build_save_data(slot, slot_name)
	return _write_save_data(slot, data)


func get_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var root := DirAccess.open("user://dialogic/saves/")
	if root == null:
		return slots

	for slot in root.get_directories():
		if not _is_valid_slot(slot):
			continue
		var meta: Dictionary = get_slot_meta(slot)
		var data: Dictionary = _read_save_data(slot)
		if data.is_empty():
			continue
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
	last_error = ""
	if not _is_valid_slot(slot):
		last_error = "save.error_invalid_slot"
		return false
	var data: Dictionary = _read_save_data(slot)
	if data.is_empty():
		last_error = "save.error_missing"
		return false
	var meta: Dictionary = data.get("meta", {})
	if not meta is Dictionary:
		meta = {}
	meta["name"] = new_name
	data["meta"] = meta
	return _write_save_data(slot, data)


func get_slot_meta(slot: String) -> Dictionary:
	var data: Dictionary = _read_save_data(slot)
	if data.is_empty():
		return {}
	var meta: Dictionary = data.get("meta", {})
	if not meta is Dictionary:
		meta = {}
	return meta


func load(slot: String) -> bool:
	last_error = ""
	if not _is_valid_slot(slot):
		last_error = "save.error_invalid_slot"
		return false
	if _loading:
		last_error = "save.error_busy"
		return false
	var data: Dictionary = _read_save_data(slot)
	if data.is_empty():
		last_error = "save.error_missing"
		return false
	if data.get("version", 0) != VERSION:
		last_error = "save.error_version"
		return false
	if not data.get("localized_dialogue") is Dictionary or not Localization.valid_saved_dialogue(data["localized_dialogue"]):
		last_error = "save.error_data"
		return false

	_loading = true
	var success: bool = await _do_load(data)
	_loading = false
	return success


func has_save(slot: String) -> bool:
	return _is_valid_slot(slot) and FileAccess.file_exists(_save_path(slot))


func delete_save(slot: String) -> void:
	last_error = ""
	if not _is_valid_slot(slot):
		last_error = "save.error_invalid_slot"
		return
	var path := _save_path(slot)
	if not FileAccess.file_exists(path):
		return
	var error := DirAccess.remove_absolute(path)
	if error != OK:
		last_error = "save.error_delete"
		return
	var slot_dir := path.get_base_dir()
	if DirAccess.dir_exists_absolute(slot_dir):
		var dir_error := DirAccess.remove_absolute(slot_dir)
		if dir_error != OK:
			last_error = "save.error_delete"


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
	if not _is_valid_slot(slot):
		return {}
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
		last_error = "save.error_data"
		return false

	if Dialogic.current_timeline != null:
		await Dialogic.end_timeline(true)

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
	await Dialogic.load_full_state(state)
	Localization.dialogue = data["localized_dialogue"].duplicate(true)
	Localization.refresh_dialogue()
	Localization._refresh_choices()
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
		"localized_dialogue": Localization.dialogue.duplicate(true),
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
	if not _is_valid_slot(slot):
		return ""
	return "%s/%s/save.sav" % [SAVE_ROOT, slot]


func _is_valid_slot(slot: String) -> bool:
	if slot.is_empty() or slot.length() > SLOT_MAX_LENGTH:
		return false
	for index in slot.length():
		var code := slot.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) \
				or (code >= 97 and code <= 122) or code == 45 or code == 95):
			return false
	return true


func _write_save_data(slot: String, data: Dictionary) -> bool:
	var path := _save_path(slot)
	if path.is_empty():
		last_error = "save.error_invalid_slot"
		return false
	var directory := path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK and not DirAccess.dir_exists_absolute(directory):
		last_error = "save.error_write"
		return false

	var temp_path := "%s.tmp-%s" % [path, str(Time.get_ticks_usec())]
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		last_error = "save.error_write"
		return false
	file.store_var(data, false)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temp_path)
		last_error = "save.error_write"
		return false

	var rename_error := DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_path)
		last_error = "save.error_write"
		return false
	return true


func display_name(slot: String, raw_name: String) -> String:
	if not raw_name.is_empty():
		return raw_name
	if slot == "auto":
		return Localization.text("save.auto_name")
	return Localization.format_text("save.default_name", {"slot": slot})
