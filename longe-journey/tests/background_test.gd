extends GdUnitTestSuite

const MANIFEST_PATH := "res://art/backgrounds/manifest.json"
const FORMAL_TIMELINES: Array[String] = [
	"00_start", "01_hospital", "02_ward", "03_crossroads", "04_flower_shop",
	"05_shiling", "06_luyuan", "07_maze_entry", "07_maze_left", "07_maze_middle",
	"07_maze_right", "07_maze_exit", "08_wife_room", "09_ending", "10_morgue",
]


func before() -> void:
	if not ProjectSettings.has_setting("validation/user_data_dir") or \
			OS.get_user_data_dir().replace("\\", "/") != str(ProjectSettings.get_setting("validation/user_data_dir")):
		push_error("Run integration tests through tools/verify.py with isolated user data")
		get_tree().quit(2)


func before_test() -> void:
	await Dialogic.end_timeline(true)
	_reset_runtime_state()
	await get_tree().process_frame


func after_test() -> void:
	await Dialogic.end_timeline(true)
	_reset_runtime_state()
	await get_tree().process_frame


func after() -> void:
	await Dialogic.end_timeline(true)
	await get_tree().process_frame


func _read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		fail("Missing background manifest: %s" % MANIFEST_PATH)
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not value is Dictionary:
		fail("Background manifest must be a JSON object")
		return {}
	var manifest: Dictionary = value
	if int(manifest.get("version", -1)) != 1:
		fail("Unsupported background manifest version")
		return {}
	if not manifest.get("assets", []) is Array or not manifest.get("timelines", []) is Array:
		fail("Background manifest requires assets and timelines arrays")
		return {}
	return manifest


func _asset_map(manifest: Dictionary) -> Dictionary:
	var assets := {}
	for raw_asset in manifest.get("assets", []):
		if not raw_asset is Dictionary:
			fail("Background manifest asset must be an object")
			continue
		var asset: Dictionary = raw_asset
		var id := str(asset.get("id", ""))
		var path := str(asset.get("path", ""))
		if id.is_empty() or path.is_empty() or assets.has(id):
			fail("Background asset id/path is missing or duplicated: %s" % id)
			continue
		assets[id] = path
	return assets


func _timeline_map(manifest: Dictionary) -> Dictionary:
	var timelines := {}
	for raw_timeline in manifest.get("timelines", []):
		if not raw_timeline is Dictionary:
			fail("Background manifest timeline must be an object")
			continue
		var timeline: Dictionary = raw_timeline
		var id := str(timeline.get("id", ""))
		if id.is_empty() or timelines.has(id):
			fail("Background timeline id is missing or duplicated: %s" % id)
			continue
		timelines[id] = timeline
	return timelines


func _cue_asset_path(timeline_data: Dictionary, key: String, assets: Dictionary) -> String:
	for cue_value in timeline_data.get("cues", []):
		if not cue_value is Dictionary:
			continue
		var cue: Dictionary = cue_value
		if str(cue.get("before", "")) == key:
			var asset_id := str(cue.get("asset", ""))
			if assets.has(asset_id):
				return assets[asset_id]
			break
	fail("Missing manifest cue %s" % key)
	return ""


func _load_timeline(id: String) -> DialogicTimeline:
	# Each probe owns its parsed events; Jump events must not form cycles through
	# other probes' cached, already processed timeline resources.
	var timeline := ResourceLoader.load("res://timelines/%s.dtl" % id, "", ResourceLoader.CACHE_MODE_IGNORE) as DialogicTimeline
	if timeline == null:
		fail("Missing Dialogic timeline: %s" % id)
		return null
	timeline.process()
	return timeline


func _event_translation_key(event: DialogicEvent) -> String:
	if not event.can_be_translated():
		return ""
	return event.get_property_translation_key("text")


func _background_path_before_key(timeline: DialogicTimeline, key: String) -> String:
	var text_index := -1
	for index in timeline.events.size():
		if _event_translation_key(timeline.events[index]) == key:
			text_index = index
			break
	if text_index < 0:
		return ""
	for index in range(text_index - 1, -1, -1):
		if timeline.events[index] is DialogicBackgroundEvent:
			return (timeline.events[index] as DialogicBackgroundEvent).argument
	return ""


func _assert_registered_timeline(id: String) -> void:
	var registered: Dictionary = ProjectSettings.get_setting("dialogic/directories/dtl_directory", {})
	var path := "res://timelines/%s.dtl" % id
	assert_array(registered.values()).contains([path])


func test_manifest_assets_are_valid_and_formal_timelines_are_registered() -> void:
	var manifest := _read_manifest()
	var assets := _asset_map(manifest)
	var timelines := _timeline_map(manifest)
	for id in FORMAL_TIMELINES:
		assert_bool(timelines.has(id)).override_failure_message("Manifest is missing timeline: " + id).is_true()
		_assert_registered_timeline(id)
	assert_bool(timelines.has("timeline1_0")).is_false()
	for id in assets:
		var texture := load(assets[id]) as Texture2D
		assert_object(texture).override_failure_message("Invalid background texture: " + assets[id]).is_not_null()
		if texture == null:
			continue
		var size := texture.get_size()
		assert_bool(size.x >= 1280.0).override_failure_message("Background is too small: " + assets[id]).is_true()
		assert_bool(abs(size.x / size.y - 16.0 / 9.0) <= 0.02).override_failure_message(
			"Background is not 16:9: %s (%s)" % [assets[id], size]).is_true()


func test_manifest_entries_and_cues_match_timeline_background_events() -> void:
	var manifest := _read_manifest()
	var assets := _asset_map(manifest)
	var timelines := _timeline_map(manifest)
	for id in FORMAL_TIMELINES:
		if not timelines.has(id):
			continue
		var timeline_data: Dictionary = timelines[id]
		var timeline := _load_timeline(id)
		if timeline == null:
			continue
		var entry_ids: Array = timeline_data.get("entry", [])
		assert_bool(entry_ids.size() > 0).override_failure_message("Timeline has no entry assets: " + id).is_true()
		var expected_paths: Array[String] = []
		for asset_id in entry_ids:
			assert_bool(assets.has(str(asset_id))).override_failure_message("Unknown entry asset: " + str(asset_id)).is_true()
			if assets.has(str(asset_id)):
				expected_paths.append(assets[str(asset_id)])
		var observed_entries: Array[String] = []
		for event: DialogicEvent in timeline.events:
			if event is DialogicBackgroundEvent:
				observed_entries.append((event as DialogicBackgroundEvent).argument)
		for path in expected_paths:
			assert_array(observed_entries).contains([path]).override_failure_message(
				"Entry background is missing from timeline: %s / %s" % [id, path])
		for cue_value in timeline_data.get("cues", []):
			if not cue_value is Dictionary:
				fail("Cue must be an object in timeline: %s" % id)
				continue
			var cue: Dictionary = cue_value
			var key := str(cue.get("before", ""))
			var asset_id := str(cue.get("asset", ""))
			if key.is_empty() or not assets.has(asset_id):
				fail("Cue key or asset is invalid in timeline: %s" % id)
				continue
			var actual := _background_path_before_key(timeline, key)
			assert_str(actual).override_failure_message("Missing cue background before %s" % key).is_equal(assets[asset_id])
		await timeline.clean()


func test_cross_timeline_jumps_use_dialogic_timeline_syntax() -> void:
	var registered: Dictionary = ProjectSettings.get_setting("dialogic/directories/dtl_directory", {})
	var timeline_ids := {}
	for path in registered.values():
		timeline_ids[(str(path).get_file().get_basename())] = true
	for id in FORMAL_TIMELINES:
		var timeline := _load_timeline(id)
		if timeline == null:
			continue
		for event: DialogicEvent in timeline.events:
			if not event is DialogicJumpEvent:
				continue
			var jump := event as DialogicJumpEvent
			var target := jump.timeline_identifier
			if target.is_empty():
				assert_bool(timeline_ids.has(jump.label_name)).override_failure_message(
					"Jump to a registered timeline is missing '/': %s -> %s" % [id, jump.label_name]).is_false()
			else:
				assert_bool(timeline_ids.has(target)).override_failure_message(
					"Jump target is not a registered timeline: %s -> %s" % [id, target]).is_true()
		await timeline.clean()


func _wait_for_first_text() -> String:
	for frame in 240:
		if Dialogic.current_timeline != null and Dialogic.current_event_idx >= 0 and \
				Dialogic.current_event_idx < Dialogic.current_timeline_events.size():
			var event: DialogicEvent = Dialogic.current_timeline_events[Dialogic.current_event_idx]
			if event is DialogicTextEvent:
				return Dialogic.Backgrounds.argument
		await get_tree().process_frame
	fail("Timeline did not reach its first text event")
	return ""


func _reset_runtime_state() -> void:
	var defaults := {
		"energy": 100, "calm": 100, "money": 20, "earthworm": 0, "flower": 0, "wife": 0,
		"hualan": false, "jiahua": false, "player_name": "",
		"visit_huadian": 0, "visit_shiling": 0, "visit_luyuan": 0, "visit_ting_shifang": 0,
	}
	for name in defaults:
		GameState.set_var(name, defaults[name])


func _apply_runtime_state(variable: String, value: int) -> void:
	_reset_runtime_state()
	if not variable.is_empty():
		GameState.set_var(variable, value)


func _runtime_entry_path(id: String, variable: String = "", value: int = 0) -> String:
	await Dialogic.end_timeline(true)
	await get_tree().process_frame
	_apply_runtime_state(variable, value)
	Dialogic.start(_load_timeline(id))
	return await _wait_for_first_text()


func test_runtime_entries_do_not_retain_background_across_timelines() -> void:
	var manifest := _read_manifest()
	var assets := _asset_map(manifest)
	var timelines := _timeline_map(manifest)
	for id in FORMAL_TIMELINES:
		if not timelines.has(id):
			continue
		var timeline_data: Dictionary = timelines[id]
		if timeline_data.get("entry", []).size() == 1:
			var asset_id := str(timeline_data.entry[0])
			var path := await _runtime_entry_path(id)
			assert_str(path).override_failure_message("Runtime entry mismatch: " + id).is_equal(assets[asset_id])
	var cases := [
		{"timeline": "04_flower_shop", "variable": "visit_huadian", "value": 1, "asset": "flower_shop_open"},
		{"timeline": "04_flower_shop", "variable": "visit_huadian", "value": 2, "asset": "flower_shop_open"},
		{"timeline": "04_flower_shop", "variable": "visit_huadian", "value": 3, "asset": "flower_shop_closed"},
		{"timeline": "05_shiling", "variable": "visit_shiling", "value": 1, "asset": "shiling_foothill"},
		{"timeline": "05_shiling", "variable": "visit_shiling", "value": 2, "asset": "shiling_closed_gate"},
		{"timeline": "10_morgue", "variable": "visit_ting_shifang", "value": 0, "asset": "morgue_occupied"},
		{"timeline": "10_morgue", "variable": "visit_ting_shifang", "value": 1, "asset": "morgue_occupied"},
		{"timeline": "10_morgue", "variable": "visit_ting_shifang", "value": 2, "asset": "morgue_empty"},
	]
	for case: Dictionary in cases:
		var path := await _runtime_entry_path(case.timeline, case.variable, case.value)
		assert_str(path).override_failure_message("Runtime entry mismatch: %s/%s=%d" % [case.timeline, case.variable, case.value]).is_equal(assets[case.asset])


func test_bus_background_switch_and_hospital_transition() -> void:
	var manifest := _read_manifest()
	var assets := _asset_map(manifest)
	var timelines := _timeline_map(manifest)
	if not timelines.has("00_start") or not timelines.has("01_hospital"):
		fail("Bus and hospital timelines are required for runtime transition test")
		return
	var normal_path := _cue_asset_path(timelines["00_start"], "Text/lj_00_start_000/text", assets)
	var staring_path := _cue_asset_path(timelines["00_start"], "Text/lj_00_start_008/text", assets)
	var hospital_path_expected := _cue_asset_path(timelines["01_hospital"], "Text/lj_01_hospital_000/text", assets)
	Dialogic.start(_load_timeline("00_start"))
	var first_path := await _wait_for_first_text()
	assert_str(first_path).is_equal(normal_path)
	for frame in 600:
		if Localization.dialogue.get("key", "") == "Text/lj_00_start_008/text":
			break
		if Dialogic.current_state == Dialogic.States.REVEALING_TEXT:
			Dialogic.Text.skip_text_reveal()
		elif Dialogic.current_state == Dialogic.States.IDLE:
			Dialogic.Inputs.dialogic_action.emit()
		await get_tree().process_frame
	assert_str(Localization.dialogue.get("key", "")).is_equal("Text/lj_00_start_008/text")
	assert_str(Dialogic.Backgrounds.argument).is_equal(staring_path)
	await Dialogic.end_timeline(true)
	await get_tree().process_frame
	Dialogic.start(_load_timeline("01_hospital"))
	var hospital_path := await _wait_for_first_text()
	assert_str(hospital_path).is_equal(hospital_path_expected)
