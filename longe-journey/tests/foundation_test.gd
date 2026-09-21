extends GdUnitTestSuite

var _defaults: Dictionary = {}


func before() -> void:
	# Tests mutate settings and saves; only run through tools/verify.py.
	if not ProjectSettings.has_setting("validation/user_data_dir") or \
			OS.get_user_data_dir().replace("\\", "/") != str(ProjectSettings.get_setting("validation/user_data_dir")):
		push_error("Run integration tests through tools/verify.py with isolated user data")
		get_tree().quit(2)
		return
	assert_str(str(ProjectSettings.get_setting("application/config/name"))).starts_with("LongeJourney-Verify-")
	assert_str(OS.get_user_data_dir().replace("\\", "/")).is_equal(
		str(ProjectSettings.get_setting("validation/user_data_dir")))
	for key in SaveManager.GAME_STATE_VARS:
		_defaults[key] = GameState.get_var(key)


func before_test() -> void:
	SaveManager._loading = true
	await Dialogic.end_timeline(true)
	for key in _defaults:
		GameState.set_var(key, _defaults[key])
	EndingManager.unlocked_endings.clear()
	await get_tree().process_frame
	SaveManager._loading = false


func after_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func test_business_autoloads_and_renderer_preserved() -> void:
	for singleton in ["Dialogic", "GameState", "SaveManager", "EndingManager", "VisualFX",
			"AutoSaveManager", "SettingsManager", "LoreRuntime", "MCPRuntimeBridge"]:
		assert_object(get_tree().root.get_node_or_null(singleton)).override_failure_message(
			"Missing autoload: " + singleton).is_not_null()
	assert_str(ProjectSettings.get_setting("rendering/renderer/rendering_method")).is_equal("gl_compatibility")
	assert_bool(ProjectSettings.has_setting("autoload/GodotFramework")).is_false()


func test_audio_layout_and_dialogic_routing() -> void:
	assert_bool(ProjectSettings.has_setting("audio/buses/default_bus_layout")).is_true()
	for bus_name in ["BGM", "SFX", "UI"]:
		assert_int(AudioServer.get_bus_index(bus_name)).is_greater_equal(0)
	var defaults: Dictionary = ProjectSettings.get_setting("dialogic/audio/channel_defaults")
	assert_str(str(defaults[""]["audio_bus"])).is_equal("SFX")
	assert_str(str(defaults["music"]["audio_bus"])).is_equal("BGM")
	assert_str(str(ProjectSettings.get_setting("dialogic/audio/type_sound_bus"))).is_equal("UI")
	var choice_layer: Node = (load("res://scenes/dialogic_choice_layer.tscn") as PackedScene).instantiate()
	var button_sound: AudioStreamPlayer = choice_layer.get_node("Choices/DialogicNode_ButtonSound")
	assert_str(str(button_sound.bus)).is_equal("UI")
	choice_layer.queue_free()


func test_game_state_writes_dialogic() -> void:
	GameState.set_var("money", 37)
	assert_int(GameState.money).is_equal(37)
	assert_int(int(Dialogic.VAR.get_variable("money"))).is_equal(37)


func test_dialogic_writes_game_state() -> void:
	assert_bool(Dialogic.VAR.set_variable("energy", 63)).is_true()
	assert_int(GameState.energy).is_equal(63)


func test_ending_boundary_and_deduplication() -> void:
	var received: Array[String] = []
	var listener := func(ending_id: String) -> void: received.append(ending_id)
	EndingManager.ending_triggered.connect(listener)
	GameState.set_var("money", 0)
	GameState.set_var("calm", 0)
	GameState.set_var("energy", 0)
	assert_array(received).is_empty()
	GameState.set_var("money", -1)
	GameState.set_var("calm", -1)
	GameState.set_var("energy", -1)
	EndingManager.check_endings()
	assert_array(received).is_equal(["ending_bankrupt", "ending_crazy", "ending_exhausted"])
	EndingManager.ending_triggered.disconnect(listener)


func test_save_slot_create_list_rename_delete() -> void:
	var slot: String = SaveManager.new_slot_id()
	assert_str(slot).is_not_empty()
	GameState.set_var("money", 47)
	assert_bool(SaveManager.save_to_slot(slot, "测试存档")).is_true()
	assert_bool(SaveManager.has_save(slot)).is_true()
	assert_int(SaveManager.get_save_meta(slot)["game_state"]["money"]).is_equal(47)
	assert_bool(SaveManager.rename_slot(slot, "重命名")).is_true()
	assert_str(SaveManager.get_slot_meta(slot)["name"]).is_equal("重命名")
	var ids: Array = SaveManager.get_slots().map(func(item: Dictionary): return item["id"])
	assert_array(ids).contains([slot])
	SaveManager.delete_save(slot)
	assert_bool(SaveManager.has_save(slot)).is_false()
	assert_bool(DirAccess.dir_exists_absolute(SaveManager._save_path(slot).get_base_dir())).is_false()


func test_save_rejects_invalid_slot_without_touching_user_path() -> void:
	for slot: String in ["", "../escape", "nested/slot", "slot.sav", "a\\b", "a".repeat(65)]:
		assert_bool(SaveManager.save_to_slot(slot)).is_false()
		assert_str(SaveManager.last_error).is_equal("save.error_invalid_slot")
	assert_bool(FileAccess.file_exists("user://dialogic/escape/save.sav")).is_false()


func test_visual_fx_choice_scan_connects_each_button_once() -> void:
	var button := Button.new()
	button.name = "ChoiceButtonRegression"
	add_child(button)
	await get_tree().process_frame
	VisualFX._scan_for_choice_buttons()
	VisualFX._scan_for_choice_buttons()
	var pressed_connections := button.get_signal_connection_list("pressed")
	assert_int(pressed_connections.size()).is_equal(1)
	button.queue_free()
	await get_tree().process_frame


func test_load_rejects_missing_and_wrong_version() -> void:
	assert_bool(await SaveManager.load("missing")).is_false()
	assert_bool(SaveManager.save_to_slot("wrong-version")).is_true()
	var path: String = SaveManager._save_path("wrong-version")
	var data: Dictionary = SaveManager._read_save_data("wrong-version")
	data["version"] = -1
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var(data, false)
	file.close()
	assert_bool(await SaveManager.load("wrong-version")).is_false()
	assert_bool(SaveManager._loading).is_false()


func test_save_load_restores_variables_without_timeline() -> void:
	GameState.set_var("money", 71)
	GameState.set_var("player_name", "旅人")
	assert_bool(SaveManager.save_to_slot("roundtrip")).is_true()
	GameState.set_var("money", 12)
	GameState.set_var("player_name", "改变")
	assert_bool(await SaveManager.load("roundtrip")).is_true()
	await get_tree().process_frame
	assert_int(GameState.money).is_equal(71)
	assert_int(int(Dialogic.VAR.get_variable("money"))).is_equal(71)
	assert_str(GameState.player_name).is_equal("旅人")


func test_save_load_restores_timeline_position() -> void:
	Dialogic.start("00_start")
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.set_var("money", 54)
	assert_bool(SaveManager.save_to_slot("timeline-roundtrip")).is_true()
	var saved: Dictionary = SaveManager._read_save_data("timeline-roundtrip")
	assert_str(saved["dialogic_state"]["timeline"]).is_equal("res://timelines/00_start.dtl")
	await Dialogic.end_timeline(true)
	GameState.set_var("money", 3)
	assert_bool(await SaveManager.load("timeline-roundtrip")).is_true()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_object(Dialogic.current_timeline).is_not_null()
	assert_str(Dialogic.current_timeline.resource_path).is_equal(saved["dialogic_state"]["timeline"])
	assert_int(Dialogic.current_event_idx).is_equal(saved["dialogic_state"]["event_index"])
	assert_int(GameState.money).is_equal(54)


func test_auto_skip_follows_history_events() -> void:
	var skip := Dialogic.Inputs.auto_skip
	skip.enable_on_visited = true
	skip.disable_on_unread_text = true
	skip.enabled = false
	Dialogic.History.visited_event.emit()
	assert_bool(skip.enabled).is_true()
	Dialogic.History.unvisited_event.emit()
	assert_bool(skip.enabled).is_false()
	skip.enable_on_visited = false
	skip.disable_on_unread_text = false


func test_milestone_triggers_deferred_auto_save() -> void:
	SaveManager.delete_save("auto")
	GameState.set_var("flower", 2)
	await get_tree().process_frame
	assert_bool(SaveManager.has_save("auto")).is_true()
	assert_int(SaveManager.get_save_meta("auto")["game_state"]["flower"]).is_equal(2)


func test_auto_save_does_not_run_during_load() -> void:
	SaveManager.delete_save("auto")
	SaveManager._loading = true
	GameState.set_var("wife", 1)
	await get_tree().process_frame
	assert_bool(SaveManager.has_save("auto")).is_false()
	SaveManager._loading = false


func test_non_milestone_does_not_auto_save() -> void:
	SaveManager.delete_save("auto")
	GameState.set_var("money", 21)
	await get_tree().process_frame
	assert_bool(SaveManager.has_save("auto")).is_false()


func test_settings_persistence_and_clamping() -> void:
	SettingsManager.set_text_speed(77.0)
	SettingsManager.set_bgm_volume(23)
	SettingsManager.set_sfx_volume(47)
	SettingsManager.set_ui_volume(61)
	SettingsManager.set_fullscreen(false)
	SettingsManager._text_speed = 38.0
	SettingsManager._bgm_volume = 100
	SettingsManager._sfx_volume = 100
	SettingsManager._ui_volume = 100
	SettingsManager._load_settings()
	assert_float(SettingsManager.get_text_speed()).is_equal(77.0)
	assert_float(VisualFX.get_text_speed()).is_equal(77.0)
	assert_int(SettingsManager.get_bgm_volume()).is_equal(23)
	assert_int(SettingsManager.get_sfx_volume()).is_equal(47)
	assert_int(SettingsManager.get_ui_volume()).is_equal(61)
	var config := ConfigFile.new()
	assert_int(config.load(SettingsManager.SETTINGS_PATH)).is_equal(OK)
	assert_int(config.get_value("audio", "bgm_volume")).is_equal(23)
	assert_int(config.get_value("audio", "sfx_volume")).is_equal(47)
	assert_int(config.get_value("audio", "ui_volume")).is_equal(61)
	assert_bool(config.get_value("display", "fullscreen")).is_false()
	SettingsManager.set_text_speed(500.0)
	SettingsManager.set_bgm_volume(-1)
	SettingsManager.set_sfx_volume(101)
	SettingsManager.set_ui_volume(50)
	assert_float(SettingsManager.get_text_speed()).is_equal(200.0)
	assert_int(SettingsManager.get_bgm_volume()).is_equal(0)
	assert_int(SettingsManager.get_sfx_volume()).is_equal(100)
	assert_int(SettingsManager.get_ui_volume()).is_equal(50)


func test_lore_returns_independent_copies() -> void:
	var entries: Array = LoreRuntime.get_all_entries()
	assert_array(entries).is_not_empty()
	var original: Dictionary = entries[0].duplicate(true)
	entries[0]["title"] = "MUTATED"
	assert_str(LoreRuntime.get_detail(original["slug"])["title"]).is_equal(original["title"])
	assert_array(LoreRuntime.search(original["title"])).is_not_empty()


func test_menu_and_panels_instantiate() -> void:
	for path in ["mianMenu", "settings_panel", "save_slot_panel", "lore_browser", "hud", "history_panel"]:
		var packed := load("res://scenes/%s.tscn" % path) as PackedScene
		assert_object(packed).is_not_null()
		var instance := packed.instantiate()
		add_child(instance)
		await get_tree().process_frame
		instance.queue_free()
		await get_tree().process_frame


func test_main_menu_start_and_cross_scene_load() -> void:
	var previous_scene := get_tree().current_scene
	assert_int(get_tree().change_scene_to_file("res://scenes/mianMenu.tscn")).is_equal(OK)
	await get_tree().scene_changed
	get_tree().current_scene._on_button_start_pressed()
	await get_tree().scene_changed
	await get_tree().process_frame
	await get_tree().process_frame
	assert_str(get_tree().current_scene.scene_file_path).is_equal("res://scenes/scene_1.tscn")
	assert_object(Dialogic.current_timeline).is_not_null()
	GameState.set_var("money", 66)
	assert_bool(SaveManager.save_to_slot("scene-roundtrip")).is_true()
	await Dialogic.end_timeline(true)
	assert_int(get_tree().change_scene_to_file("res://scenes/mianMenu.tscn")).is_equal(OK)
	await get_tree().scene_changed
	GameState.set_var("money", 2)
	assert_bool(await SaveManager.load("scene-roundtrip")).is_true()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_str(get_tree().current_scene.scene_file_path).is_equal("res://scenes/scene_1.tscn")
	assert_object(Dialogic.current_timeline).is_not_null()
	assert_int(GameState.money).is_equal(66)
	await Dialogic.end_timeline(true)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = previous_scene
	await get_tree().process_frame


func after() -> void:
	await Dialogic.end_timeline(true)
	await get_tree().process_frame
