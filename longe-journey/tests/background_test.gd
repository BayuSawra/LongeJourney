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


func test_ward_door_locator_is_runtime_ui_text() -> void:
	var scene := ResourceLoader.load("res://scenes/scene_1.tscn", "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	assert_object(scene).override_failure_message("Main scene is missing for ward door locator").is_not_null()
	if scene == null:
		return
	var instance := scene.instantiate()
	var sign := instance.get_node_or_null("WardDoorSign/Sign") as Label
	assert_object(sign).override_failure_message("Ward door locator Label is missing").is_not_null()
	if sign != null:
		assert_str(sign.text).is_equal("ui.ward_door_locator.text")
		assert_bool(sign.visible).is_false()
	instance.free()


func test_ward_door_locator_uses_background_cover_mapping() -> void:
	var controller: CanvasLayer = load("res://scripts/ward_door_sign.gd").new() as CanvasLayer
	var wide_rect: Rect2 = controller._plaque_rect(Vector2(1152.0, 648.0))
	var four_three_rect: Rect2 = controller._plaque_rect(Vector2(1024.0, 768.0))
	assert_bool(abs(wide_rect.position.x - 910.0) < 3.0).is_true()
	assert_bool(abs(four_three_rect.position.x - 907.0) < 5.0).override_failure_message(
		"4:3 plaque mapping ignored covered background crop").is_true()
	assert_bool(four_three_rect.position.x > 880.0).is_true()
	controller.free()


func test_ward_door_locator_tracks_background_across_reentry() -> void:
	var previous_background := str(Dialogic.Backgrounds.argument)
	Dialogic.start(_load_timeline("02_ward"))
	await _wait_for_first_text()
	var controller := load("res://scripts/ward_door_sign.gd").new() as CanvasLayer
	var sign := Label.new()
	sign.name = "Sign"
	controller.add_child(sign)
	get_tree().root.add_child(controller)
	await get_tree().process_frame

	Dialogic.Backgrounds.update_background("", "res://art/backgrounds/ward_corridor.png", 0.0)
	await get_tree().process_frame
	assert_bool(sign.visible).override_failure_message("Door sign leaked into ward corridor").is_false()

	Dialogic.Backgrounds.update_background("", "res://art/backgrounds/hospital_ward_door_505.png", 0.05)
	await get_tree().create_timer(0.08).timeout
	assert_bool(sign.visible).override_failure_message("Door sign did not appear for 5-05 background").is_true()
	assert_object(controller.attached_sign).override_failure_message(
		"Door sign was not attached to the active Dialogic background").is_not_null()

	Dialogic.Backgrounds.update_background("", "res://art/backgrounds/wife_room_curtained.png", 0.05)
	await get_tree().create_timer(0.08).timeout
	assert_bool(sign.visible).override_failure_message("Door sign remained visible after leaving 5-05").is_false()

	controller.queue_free()
	await get_tree().process_frame
	var second_controller := load("res://scripts/ward_door_sign.gd").new() as CanvasLayer
	var second_sign := Label.new()
	second_sign.name = "Sign"
	second_controller.add_child(second_sign)
	get_tree().root.add_child(second_controller)
	await get_tree().process_frame
	assert_bool(second_sign.visible).is_false()
	second_controller.queue_free()
	Dialogic.Backgrounds.update_background("", previous_background, 0.0)
	await get_tree().process_frame


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
		var cue_keys := {}
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
			assert_bool(not cue_keys.has(key)).override_failure_message(
				"Duplicate background cue: %s / %s" % [id, key]).is_true()
			cue_keys[key] = true
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


func _advance_to_text(key: String, max_frames := 600) -> String:
	for _frame in max_frames:
		if str(Localization.dialogue.get("key", "")) == key:
			return str(Dialogic.Backgrounds.argument)
		if Dialogic.current_state == Dialogic.States.REVEALING_TEXT:
			Dialogic.Text.skip_text_reveal()
		elif Dialogic.current_state == Dialogic.States.IDLE:
			Dialogic.Inputs.dialogic_action.emit()
		await get_tree().process_frame
	fail("Timeline did not reach text event: " + key)
	return ""


func _advance_to_text_without_background(key: String, forbidden_background: String, max_frames := 300) -> void:
	for _frame in max_frames:
		if str(Dialogic.Backgrounds.argument) == forbidden_background:
			fail("Unexpected background before %s: %s" % [key, forbidden_background])
			return
		if str(Localization.dialogue.get("key", "")) == key:
			return
		if Dialogic.current_state == Dialogic.States.REVEALING_TEXT:
			Dialogic.Text.skip_text_reveal()
		elif Dialogic.current_state == Dialogic.States.IDLE:
			Dialogic.Inputs.dialogic_action.emit()
		await get_tree().process_frame
	fail("Timeline did not reach text event: " + key)


func _runtime_assets_available(assets: Dictionary, required_assets: Array) -> bool:
	var available := true
	for raw_asset_id in required_assets:
		var asset_id := str(raw_asset_id)
		assert_bool(assets.has(asset_id)).override_failure_message("Missing state asset: " + asset_id).is_true()
		available = available and assets.has(asset_id)
	return available


func _select_runtime_choice(button_index: int, max_frames := 600) -> bool:
	for _frame in max_frames:
		if Dialogic.current_state == Dialogic.States.AWAITING_CHOICE:
			var question := Dialogic.Choices.get_current_question_info()
			var choices: Array = question.get("choices", [])
			if button_index < 1 or button_index > choices.size():
				fail("Choice index is unavailable: %d" % button_index)
				return false
			Dialogic.Choices._choice_blocker.stop()
			Dialogic.Choices._on_choice_selected(choices[button_index - 1])
			await get_tree().process_frame
			return true
		if Dialogic.current_state == Dialogic.States.REVEALING_TEXT:
			Dialogic.Text.skip_text_reveal()
		elif Dialogic.current_state == Dialogic.States.IDLE:
			Dialogic.Inputs.dialogic_action.emit()
		await get_tree().process_frame
	fail("Timeline did not reach a choice")
	return false


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

func test_item_and_pose_states_use_the_expected_backgrounds() -> void:
	var manifest := _read_manifest()
	var assets := _asset_map(manifest)
	var cases := [
		{"timeline": "05_shiling", "key": "Text/lj_05_shiling_013/text", "asset": "shiling_bandit_ambush_no_iris"},
		{"timeline": "06_luyuan", "key": "Text/lj_06_luyuan_009/text", "asset": "maze_woman_closeup"},
		{"timeline": "06_luyuan", "key": "Text/lj_06_luyuan_009_face/text", "asset": "maze_woman_face_detail"},
		{"timeline": "06_luyuan", "key": "Text/lj_06_luyuan_009_hands/text", "asset": "maze_woman_closeup"},
		{"timeline": "06_luyuan", "key": "Text/lj_06_luyuan_019/text", "asset": "maze_woman_closeup_no_hydrangea"},
		{"timeline": "06_luyuan", "key": "Text/lj_06_luyuan_031/text", "asset": "maze_woman_closeup"},
		{"timeline": "06_luyuan", "key": "Text/lj_06_luyuan_031_face/text", "asset": "maze_woman_face_detail"},
		{"timeline": "06_luyuan", "key": "Text/lj_06_luyuan_031_hands/text", "asset": "maze_woman_closeup"},
		{"timeline": "06_luyuan", "key": "Text/lj_06_luyuan_041/text", "asset": "maze_woman_closeup_no_hydrangea"},
		{"timeline": "06_luyuan", "key": "Text/lj_06_luyuan_053/text", "asset": "maze_woman_closeup"},
		{"timeline": "06_luyuan", "key": "Text/lj_06_luyuan_053_face/text", "asset": "maze_woman_face_detail"},
		{"timeline": "06_luyuan", "key": "Text/lj_06_luyuan_053_hands/text", "asset": "maze_woman_closeup"},
		{"timeline": "06_luyuan", "key": "Text/lj_06_luyuan_063/text", "asset": "maze_woman_closeup_no_hydrangea"},
		{"timeline": "07_maze_middle", "key": "Text/lj_07_maze_middle_004/text", "asset": "maze_blood_trail_no_cactus_flower"},
		{"timeline": "07_maze_middle", "key": "Text/lj_07_maze_middle_015/text", "asset": "maze_woman_closeup"},
		{"timeline": "07_maze_middle", "key": "Text/lj_07_maze_middle_015_face/text", "asset": "maze_woman_face_detail"},
		{"timeline": "07_maze_middle", "key": "Text/lj_07_maze_middle_015_hands/text", "asset": "maze_woman_closeup"},
		{"timeline": "07_maze_middle", "key": "Text/lj_07_maze_middle_021/text", "asset": "maze_pinned_woman"},
		{"timeline": "07_maze_middle", "key": "Text/lj_07_maze_middle_035/text", "asset": "maze_woman_closeup_no_hydrangea"},
		{"timeline": "08_wife_room", "key": "Text/lj_08_wife_room_009/text", "asset": "wife_room_nurse"},
		{"timeline": "08_wife_room", "key": "Text/lj_08_wife_room_010/text", "asset": "wife_room_open"},
		{"timeline": "08_wife_room", "key": "Text/lj_08_wife_room_012/text", "asset": "wife_room_turned"},
		{"timeline": "08_wife_room", "key": "Text/lj_08_wife_room_018/text", "asset": "wife_room_turned_calmer"},
		{"timeline": "08_wife_room", "key": "Text/lj_08_wife_room_035/text", "asset": "wife_room_hands"},
		{"timeline": "10_morgue", "key": "Text/lj_10_morgue_008/text", "asset": "morgue_basket_held"},
	]
	var loaded := {}
	for case: Dictionary in cases:
		var timeline_id := str(case.timeline)
		if not loaded.has(timeline_id):
			loaded[timeline_id] = _load_timeline(timeline_id)
		var timeline: DialogicTimeline = loaded[timeline_id]
		var asset_id := str(case.asset)
		assert_bool(assets.has(asset_id)).override_failure_message("Missing state asset: " + asset_id).is_true()
		if timeline != null and assets.has(asset_id):
			assert_str(_background_path_before_key(timeline, str(case.key))).override_failure_message(
				"State background mismatch: %s / %s" % [timeline_id, case.key]).is_equal(assets[asset_id])
	for timeline: DialogicTimeline in loaded.values():
		if timeline != null:
			await timeline.clean()


func test_branch_specific_backgrounds_do_not_leak_to_skipped_routes() -> void:
	var maze_source := FileAccess.get_file_as_string("res://timelines/07_maze_middle.dtl")
	var picked_cactus_start := maze_source.find("- Choice/lj_07_maze_middle_002/text")
	var skipped_cactus_start := maze_source.find("- Choice/lj_07_maze_middle_007/text")
	var cactus_label := maze_source.find("label pick_cactus_flower")
	assert_bool(picked_cactus_start >= 0 and skipped_cactus_start > picked_cactus_start and cactus_label > skipped_cactus_start).is_true()
	if picked_cactus_start >= 0 and skipped_cactus_start > picked_cactus_start and cactus_label > skipped_cactus_start:
		var picked_cactus := maze_source.substr(picked_cactus_start, skipped_cactus_start - picked_cactus_start)
		var skipped_cactus := maze_source.substr(skipped_cactus_start, cactus_label - skipped_cactus_start)
		assert_bool(picked_cactus.contains("maze_blood_trail_no_cactus_flower.png")).is_true()
		assert_bool(not skipped_cactus.contains("maze_blood_trail_no_cactus_flower.png")).is_true()

	var wife_source := FileAccess.get_file_as_string("res://timelines/08_wife_room.dtl")
	var earthworm_branch := wife_source.find("if {earthworm} > 0.0:")
	var no_earthworm_branch := wife_source.find("else:\n    Text/lj_08_wife_room_032/text")
	assert_bool(earthworm_branch >= 0 and no_earthworm_branch > earthworm_branch).is_true()
	if earthworm_branch >= 0 and no_earthworm_branch > earthworm_branch:
		var worm_route := wife_source.substr(earthworm_branch, no_earthworm_branch - earthworm_branch)
		assert_bool(worm_route.contains("wife_room_turned_calmer.png")).is_true()
		assert_bool(not wife_source.substr(no_earthworm_branch).contains("wife_room_turned_calmer.png")).is_true()

	var morgue_source := FileAccess.get_file_as_string("res://timelines/10_morgue.dtl")
	var collect_start := morgue_source.find("- Choice/lj_10_morgue_005/text")
	var leave_start := morgue_source.find("- Choice/lj_10_morgue_014/text")
	assert_bool(collect_start >= 0 and leave_start > collect_start).is_true()
	if collect_start >= 0 and leave_start > collect_start:
		assert_bool(morgue_source.substr(collect_start, leave_start - collect_start).contains(
			"morgue_basket_held.png")).is_true()
		assert_bool(not morgue_source.substr(leave_start).contains("morgue_basket_held.png")).is_true()

func test_runtime_shiling_iris_background_persists_after_discard() -> void:
	var assets := _asset_map(_read_manifest())
	if not _runtime_assets_available(assets, ["shiling_bandit_ambush_no_iris"]):
		return
	GameState.set_var("visit_shiling", 1)
	Dialogic.start(_load_timeline("05_shiling"))
	await _advance_to_text("Text/lj_05_shiling_003/text")
	assert_bool(await _select_runtime_choice(1)).is_true()
	assert_bool(await _select_runtime_choice(1)).is_true()
	assert_bool(await _select_runtime_choice(1)).is_true()
	assert_str(await _advance_to_text("Text/lj_05_shiling_013/text")).is_equal(assets["shiling_bandit_ambush_no_iris"])
	assert_bool(await _select_runtime_choice(1)).is_true()
	assert_str(await _advance_to_text("Text/lj_05_shiling_015/text")).is_equal(assets["shiling_bandit_ambush_no_iris"])


func test_runtime_luyuan_hydrangea_pick_updates_all_entry_routes() -> void:
	var assets := _asset_map(_read_manifest())
	if not _runtime_assets_available(assets, ["maze_woman_closeup", "maze_woman_closeup_no_hydrangea"]):
		return
	var routes := [
		{"entry_choice": 1, "closeup_key": "Text/lj_06_luyuan_009/text", "picked_key": "Text/lj_06_luyuan_019/text"},
		{"entry_choice": 2, "closeup_key": "Text/lj_06_luyuan_031/text", "picked_key": "Text/lj_06_luyuan_041/text"},
		{"entry_choice": 3, "closeup_key": "Text/lj_06_luyuan_053/text", "picked_key": "Text/lj_06_luyuan_063/text"},
	]
	for route: Dictionary in routes:
		Dialogic.start(_load_timeline("06_luyuan"))
		await _advance_to_text("Text/lj_06_luyuan_002/text")
		assert_bool(await _select_runtime_choice(int(route.entry_choice))).is_true()
		assert_bool(await _select_runtime_choice(1)).is_true()
		assert_str(await _advance_to_text(str(route.closeup_key))).is_equal(assets["maze_woman_closeup"])
		assert_bool(await _select_runtime_choice(2)).is_true()
		assert_str(await _advance_to_text(str(route.picked_key))).is_equal(assets["maze_woman_closeup_no_hydrangea"])
		await Dialogic.end_timeline(true)
		await get_tree().process_frame


func test_runtime_maze_middle_observe_pick_and_flee_backgrounds() -> void:
	var assets := _asset_map(_read_manifest())
	if not _runtime_assets_available(assets, ["maze_blood_trail", "maze_woman_closeup", "maze_pinned_woman", "maze_woman_closeup_no_hydrangea", "maze_escape_road"]):
		return
	Dialogic.start(_load_timeline("07_maze_middle"))
	await _advance_to_text("Text/lj_07_maze_middle_001/text")
	assert_bool(await _select_runtime_choice(2)).is_true()
	assert_str(await _advance_to_text("Text/lj_07_maze_middle_015/text")).is_equal(assets["maze_woman_closeup"])
	assert_bool(await _select_runtime_choice(1)).is_true()
	assert_str(await _advance_to_text("Text/lj_07_maze_middle_021/text")).is_equal(assets["maze_pinned_woman"])
	assert_bool(await _select_runtime_choice(2)).is_true()
	assert_str(await _advance_to_text("Text/lj_07_maze_middle_035/text")).is_equal(assets["maze_woman_closeup_no_hydrangea"])
	assert_bool(await _select_runtime_choice(1)).is_true()
	assert_str(await _advance_to_text("Text/lj_07_maze_middle_030/text")).is_equal(assets["maze_escape_road"])


func test_runtime_maze_middle_cactus_pick_and_skip_backgrounds() -> void:
	var assets := _asset_map(_read_manifest())
	if not _runtime_assets_available(assets, ["maze_blood_trail", "maze_blood_trail_no_cactus_flower"]):
		return
	Dialogic.start(_load_timeline("07_maze_middle"))
	await _advance_to_text("Text/lj_07_maze_middle_001/text")
	assert_bool(await _select_runtime_choice(1)).is_true()
	assert_str(await _advance_to_text("Text/lj_07_maze_middle_004/text")).is_equal(assets["maze_blood_trail_no_cactus_flower"])
	await Dialogic.end_timeline(true)
	await get_tree().process_frame

	Dialogic.start(_load_timeline("07_maze_middle"))
	await _advance_to_text("Text/lj_07_maze_middle_001/text")
	assert_bool(await _select_runtime_choice(2)).is_true()
	assert_str(await _advance_to_text("Text/lj_07_maze_middle_008/text")).is_equal(assets["maze_blood_trail"])


func test_runtime_morgue_basket_take_and_leave_backgrounds() -> void:
	var assets := _asset_map(_read_manifest())
	if not _runtime_assets_available(assets, ["morgue_interior_drawers", "morgue_basket_held"]):
		return
	Dialogic.start(_load_timeline("10_morgue"))
	await _advance_to_text("Text/lj_10_morgue_004/text")
	assert_bool(await _select_runtime_choice(1)).is_true()
	assert_str(await _advance_to_text("Text/lj_10_morgue_007/text")).is_equal(assets["morgue_interior_drawers"])
	assert_str(await _advance_to_text("Text/lj_10_morgue_008/text")).is_equal(assets["morgue_basket_held"])
	await Dialogic.end_timeline(true)
	await get_tree().process_frame

	_reset_runtime_state()
	Dialogic.start(_load_timeline("10_morgue"))
	assert_str(await _advance_to_text("Text/lj_10_morgue_004/text")).is_equal(assets["morgue_interior_drawers"])
	assert_bool(await _select_runtime_choice(2)).is_true()
	await _advance_to_text_without_background("Text/lj_01_hospital_000/text", assets["morgue_basket_held"])


func test_runtime_wife_room_branches_end_with_hands_background() -> void:
	var assets := _asset_map(_read_manifest())
	if not _runtime_assets_available(assets, ["wife_room_nurse", "wife_room_open", "wife_room_turned", "wife_room_turned_calmer", "wife_room_hands"]):
		return
	for earthworm in [0, 1]:
		GameState.set_var("earthworm", earthworm)
		Dialogic.start(_load_timeline("08_wife_room"))
		await _advance_to_text("Text/lj_08_wife_room_007/text")
		assert_bool(await _select_runtime_choice(1)).is_true()
		assert_str(await _advance_to_text("Text/lj_08_wife_room_009/text")).is_equal(assets["wife_room_nurse"])
		assert_str(await _advance_to_text("Text/lj_08_wife_room_010/text")).is_equal(assets["wife_room_open"])
		assert_str(await _advance_to_text("Text/lj_08_wife_room_012/text")).is_equal(assets["wife_room_turned"])
		var branch_key: String = "Text/lj_08_wife_room_018/text" if earthworm > 0 else "Text/lj_08_wife_room_032/text"
		var expected_path: String = str(assets["wife_room_turned_calmer"]) if earthworm > 0 else str(assets["wife_room_turned"])
		assert_str(await _advance_to_text(branch_key)).is_equal(expected_path)
		assert_str(await _advance_to_text("Text/lj_08_wife_room_035/text")).is_equal(assets["wife_room_hands"])
		await Dialogic.end_timeline(true)
		await get_tree().process_frame
		_reset_runtime_state()
