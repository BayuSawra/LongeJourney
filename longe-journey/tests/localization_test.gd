extends GdUnitTestSuite

var _original_messages: Dictionary = {}


func before() -> void:
	if not ProjectSettings.has_setting("validation/user_data_dir") or OS.get_user_data_dir().replace("\\", "/") != str(ProjectSettings.get_setting("validation/user_data_dir")):
		push_error("Run localization integration tests through tools/verify.py")
		get_tree().quit(2)


func before_test() -> void:
	SaveManager._loading = true
	await Dialogic.end_timeline(true)
	Localization.set_locale("zh_CN")
	GameState.set_var("player_name", "")
	GameState.set_var("money", 20)
	await get_tree().process_frame
	SaveManager._loading = false


func after_test() -> void:
	SaveManager._loading = true
	await Dialogic.end_timeline(true)
	for language in _original_messages:
		for key in _original_messages[language]:
			Localization.catalogs[language].add_message(key, _original_messages[language][key])
	_original_messages.clear()
	SettingsManager.set_language("zh_CN")
	await get_tree().process_frame
	SaveManager._loading = false


func _wait_for_text() -> void:
	for frame in 180:
		if not Localization.dialogue.is_empty():
			return
		await get_tree().process_frame
	fail("Dialogic did not start localized text within 180 frames")


func _event_index_by_translation_key(timeline_name: String, key: String, event_name: String = "") -> int:
	var timeline := load("res://timelines/%s.dtl" % timeline_name) as DialogicTimeline
	if timeline == null:
		fail("Missing timeline while locating translation key: %s" % timeline_name)
		return -1
	timeline.process()
	for index in timeline.events.size():
		var event: DialogicEvent = timeline.events[index]
		if event.get_property_translation_key("text") != key:
			continue
		if not event_name.is_empty() and event.event_name != event_name:
			continue
		return index
	fail("Missing %s event translation key %s in %s" % [event_name if not event_name.is_empty() else "", key, timeline_name])
	return -1


func test_native_catalogs_and_all_timeline_properties() -> void:
	assert_array(Localization.supported_locales()).is_equal(["en", "zh_CN"])
	var paths: Dictionary = ProjectSettings.get_setting("dialogic/directories/dtl_directory")
	for language in Localization.supported_locales():
		Localization.set_locale(language)
		assert_str(str(TranslationServer.translate("save.title"))).is_equal(Localization.text("save.title"))
		for path in paths.values():
			var timeline := load(path) as DialogicTimeline
			timeline.process()
			for event: DialogicEvent in timeline.events:
				if not event.can_be_translated():
					continue
				for property in event._get_translatable_properties():
					var key: String = event._get_property_original_translation(property)
					if key.is_empty():
						continue
					assert_str(key).is_equal(event.get_property_translation_key(property))
					assert_str(event.get_property_translated(property)).is_equal(Localization.text(key))
		for path in ProjectSettings.get_setting("dialogic/directories/dch_directory").values():
			var character := load(path) as DialogicCharacter
			assert_str(character.get_display_name_translated()).is_equal(Localization.text(character.display_name))


func test_native_event_serialization_preserves_original_story_flow() -> void:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/localization_flow.json"))
	for path in baseline:
		var timeline := load(path) as DialogicTimeline
		timeline.process()
		assert_int(timeline.events.size()).is_equal(baseline[path].size())
		for index in timeline.events.size():
			# Native Comment retains CR from a Windows checkout; normalize line endings only.
			var serialized: String = timeline.events[index]._store_as_string().replace("\r\n", "\n").trim_suffix("\r")
			assert_str(serialized.sha256_text()).override_failure_message("Native event serialization changed: %s:%d => %s" % [path, index, serialized]).is_equal(baseline[path][index])


func test_language_settings_persist_and_options_use_autonyms() -> void:
	SettingsManager.set_language("en")
	Localization.set_locale("zh_CN")
	SettingsManager._load_settings()
	assert_str(Localization.locale).is_equal("en")
	var panel = load("res://scenes/settings_panel.tscn").instantiate()
	add_child(panel)
	assert_int(panel.language_option.item_count).is_equal(2)
	assert_str(panel.language_option.get_item_metadata(panel.language_option.selected)).is_equal("en")
	assert_str(panel.language_option.get_item_text(0)).is_equal("English")
	panel.queue_free()
	await get_tree().process_frame


func test_hud_lore_and_history_refresh_without_changing_variables() -> void:
	var hud = load("res://scenes/hud.tscn").instantiate()
	var history = load("res://scenes/history_panel.tscn").instantiate()
	add_child(hud)
	add_child(history)
	var record_key := "Text/lj_07_maze_entry_008/text"
	var record := {"key": record_key, "variables": {"player_name": ""}, "character": "", "timeline": "res://timelines/07_maze_entry.dtl", "event_idx": _event_index_by_translation_key("07_maze_entry", record_key, "Text"), "type": "Text"}
	history._append_record(record)
	var original: String = history.list_box.get_child(0).text
	var lore_before: Dictionary = LoreRuntime.get_detail("protagonist")
	Localization.set_locale("en")
	assert_str(hud.values.get_node("money").text).is_equal(Localization.format_text("hud.money", {"value": 20}))
	assert_str(history.list_box.get_child(0).text).is_not_equal(original)
	assert_str(LoreRuntime.get_detail("protagonist")["title"]).is_not_equal(lore_before["title"])
	assert_array(LoreRuntime.search("Nameless King")).is_not_empty()
	assert_array(LoreRuntime.search("无名王")).is_empty()
	assert_int(GameState.money).is_equal(20)
	assert_str(GameState.player_name).is_empty()
	assert_str(Localization.render_record(record)).contains(Localization.text("player.default_name"))
	record.variables.player_name = "{money}"
	assert_str(Localization.render_record(record)).contains("{money}")
	hud.queue_free()
	history.queue_free()
	await get_tree().process_frame


func test_live_text_switch_preserves_event_and_reveal_progress() -> void:
	Dialogic.start("00_start")
	await _wait_for_text()
	var event_index: int = Dialogic.current_event_idx
	var node: DialogicNode_DialogText = Dialogic.Text.get_textboxes(Dialogic.Text.active_textbox)[0]
	node.visible_ratio = 0.4
	var ratio := node.visible_ratio
	var revealing := node.revealing
	Localization.set_locale("en")
	assert_int(Dialogic.current_event_idx).is_equal(event_index)
	assert_float(node.visible_ratio).is_equal_approx(ratio, 0.02)
	assert_bool(node.revealing).is_equal(revealing)
	assert_str(Dialogic.Text.dialog_text).is_equal(Localization.text("Text/lj_00_start_000/text"))


func test_live_choices_preserve_branch_state_and_selected_history() -> void:
	var history = load("res://scenes/history_panel.tscn").instantiate()
	add_child(history)
	var text_key := "Text/lj_00_start_008/text"
	var choice_key := "Choice/lj_00_start_010/text"
	Dialogic.start("00_start", _event_index_by_translation_key("00_start", text_key, "Text"))
	await _wait_for_text()
	Dialogic.Text.skip_text_reveal()
	Dialogic.Inputs.dialogic_action.emit()
	await get_tree().create_timer(0.6).timeout
	for frame in 180:
		if Dialogic.current_state == Dialogic.States.AWAITING_CHOICE:
			break
		await get_tree().process_frame
	assert_int(Dialogic.current_state).is_equal(Dialogic.States.AWAITING_CHOICE)
	var button := Dialogic.Choices.get_choice_button(1)
	assert_object(button).is_not_null()
	var index: int = Dialogic.current_event_idx
	var disabled: bool = button.disabled
	Localization.set_locale("en")
	assert_str(button.text).is_equal(Localization.text(choice_key))
	assert_bool(button.disabled).is_equal(disabled)
	assert_int(Dialogic.current_event_idx).is_equal(index)
	assert_int(history._entries.size()).is_equal(1)
	Dialogic.Choices._choice_blocker.stop()
	button.choice_selected.emit()
	assert_str(history._entries[-1].type).is_equal("Choice")
	assert_int(history._entries[-1].event_idx).is_equal(_event_index_by_translation_key("00_start", choice_key, "Choice"))
	history.queue_free()
	await get_tree().process_frame


func test_cross_language_save_restores_text_not_saved_language() -> void:
	var text_key := "Text/lj_07_maze_entry_008/text"
	Dialogic.start("07_maze_entry", _event_index_by_translation_key("07_maze_entry", text_key, "Text"))
	await _wait_for_text()
	Dialogic.Text.skip_text_reveal()
	assert_bool(SaveManager.save_to_slot("localization-roundtrip")).is_true()
	var data: Dictionary = SaveManager._read_save_data("localization-roundtrip")
	assert_str(data["game_state"]["player_name"]).is_empty()
	assert_str(data["localized_dialogue"]["key"]).is_equal(text_key)
	await Dialogic.end_timeline(true)
	Localization.set_locale("en")
	assert_bool(await SaveManager.load("localization-roundtrip")).is_true()
	assert_str(Localization.locale).is_equal("en")
	assert_str(Dialogic.Text.dialog_text).contains(Localization.text("player.default_name"))
	assert_str(Dialogic.Text.dialog_text).is_equal(Localization.render_record(Localization.dialogue))
	assert_str(GameState.player_name).is_empty()


func test_custom_names_are_never_retranslated() -> void:
	GameState.set_var("player_name", "{money}")
	Dialogic.start("07_maze_entry", _event_index_by_translation_key("07_maze_entry", "Text/lj_07_maze_entry_008/text", "Text"))
	await _wait_for_text()
	Localization.set_locale("en")
	assert_str(Dialogic.Text.dialog_text).contains("{money}")
	assert_str(GameState.player_name).is_equal("{money}")
	assert_str(SaveManager.display_name("1", "自动存档")).is_equal("自动存档")
	assert_str(SaveManager.display_name("1", "")).is_equal("Save 1")
	assert_str(SaveManager.display_name("auto", "")).is_equal(Localization.text("save.auto_name"))


func test_language_switch_during_animation_and_cancel_does_not_revive_event() -> void:
	Dialogic.start("00_start")
	await get_tree().process_frame
	Localization.set_locale("en")
	await _wait_for_text()
	assert_str(Dialogic.Text.dialog_text).is_equal(Localization.text("Text/lj_00_start_000/text"))
	await Dialogic.end_timeline(true)
	Dialogic.start("00_start")
	await get_tree().process_frame
	await Dialogic.end_timeline(true)
	for frame in 8:
		await get_tree().process_frame
	assert_object(Dialogic.current_timeline).is_null()
	assert_bool(Dialogic.Animations.is_animating()).is_false()
	assert_dict(Localization.dialogue).is_empty()


func test_future_segments_use_new_locale() -> void:
	var key := "Text/lj_00_start_000/text"
	for language in ["en", "zh_CN"]:
		_original_messages[language] = {key: Localization.text_in(language, key)}
	Localization.catalogs["zh_CN"].add_message(key, "甲[n]乙[n+]丙")
	Localization.catalogs["en"].add_message(key, "One[n]Two[n+]Three")
	Dialogic.start("00_start")
	await _wait_for_text()
	Dialogic.Text.skip_text_reveal()
	Localization.set_locale("en")
	assert_str(Dialogic.Text.dialog_text).is_equal("One")
	var event: DialogicTextEvent
	for candidate in Dialogic.current_timeline_events:
		if candidate is DialogicTextEvent:
			event = candidate
			break
	assert_object(event).is_not_null()
	event.advance.emit()
	for frame in 8:
		await get_tree().process_frame
	assert_str(Dialogic.Text.dialog_text).is_equal("Two")
	Dialogic.Text.skip_text_reveal()
	event.advance.emit()
	for frame in 8:
		await get_tree().process_frame
	assert_str(Dialogic.Text.dialog_text).is_equal("TwoThree")


func test_font_covers_all_catalog_characters() -> void:
	var missing := ""
	for language in Localization.supported_locales():
		for key in Localization.catalogs[language].get_message_list():
			for character in Localization.text_in(language, key):
				if character.strip_edges().is_empty():
					continue
				if not Localization.UI_FONT.has_char(character.unicode_at(0)) and not character in missing:
					missing += character
	assert_str(missing).override_failure_message("Font is missing catalog characters: " + missing).is_empty()


func test_incompatible_or_invalid_localized_save_is_rejected_without_mutation() -> void:
	Dialogic.start("07_maze_entry", _event_index_by_translation_key("07_maze_entry", "Text/lj_07_maze_entry_008/text", "Text"))
	await _wait_for_text()
	Dialogic.Text.skip_text_reveal()
	var valid := SaveManager._build_save_data("localization-invalid", "Custom name")
	var path := SaveManager._save_path("localization-invalid")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	for invalid in ["version", "key", "variables", "segment"]:
		var data: Dictionary = valid.duplicate(true)
		match invalid:
			"version": data.version = 2
			"key": data.localized_dialogue.key = "Text/does-not-exist/text"
			"variables": data.localized_dialogue.variables.clear()
			"segment": data.localized_dialogue.segment = 999
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_var(data, false)
		file.close()
		var before := FileAccess.get_file_as_bytes(path)
		GameState.set_var("money", 33)
		assert_bool(await SaveManager.load("localization-invalid")).is_false()
		assert_str(SaveManager.last_error).is_equal("save.error_version" if invalid == "version" else "save.error_data")
		assert_int(GameState.money).is_equal(33)
		assert_bool(FileAccess.get_file_as_bytes(path) == before).is_true()
