extends GdUnitTestSuite

const AUDIO_ROOT := "res://audio/sfx/"
const AMBIENCE_CHANNEL := "ambience"
const AMBIENCE_PATH := "res://audio/sfx/09_bus_ambience/bus_interior_ambience_with_people.wav"
const TEST_CHANNEL := "audio_regression"


func before() -> void:
	if not ProjectSettings.has_setting("validation/user_data_dir") or OS.get_user_data_dir().replace("\\", "/") != str(ProjectSettings.get_setting("validation/user_data_dir")):
		push_error("Run audio integration tests through tools/verify.py")
		get_tree().quit(2)


func before_test() -> void:
	Dialogic.Audio.stop_all_channels()
	Dialogic.Audio.stop_all_one_shot_sounds()
	await get_tree().process_frame


func after_test() -> void:
	Dialogic.Audio.stop_all_channels()
	Dialogic.Audio.stop_all_one_shot_sounds()
	await get_tree().create_timer(0.12).timeout


func _catalog_paths() -> Dictionary:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/sfx_catalog.json"))
	var paths := {}
	for group: Dictionary in catalog["groups"]:
		paths[group["path"]] = true
	return paths


func _action_stops_after_next_text(events: Array, action_index: int) -> bool:
	var text_index := -1
	for index in range(action_index + 1, events.size()):
		if events[index] is DialogicTextEvent:
			text_index = index
			break
	if text_index == -1:
		return false
	for index in range(text_index + 1, events.size()):
		if events[index] is DialogicCommentEvent:
			continue
		var event := events[index] as DialogicAudioEvent
		return event != null and event.channel_name == "action" and event.file_path.is_empty()
	return false


func test_timeline_audio_events_use_catalog_resources_and_channel_contracts() -> void:
	var catalog_paths := _catalog_paths()
	var timeline_paths: Dictionary = ProjectSettings.get_setting("dialogic/directories/dtl_directory")
	var audio_event_count := 0
	for path in timeline_paths.values():
		var timeline := load(path) as DialogicTimeline
		timeline.process()
		var entry_audio_events: Array[DialogicAudioEvent] = []
		for index in timeline.events.size():
			var event := timeline.events[index] as DialogicAudioEvent
			if event == null:
				continue
			audio_event_count += 1
			if entry_audio_events.size() < 2:
				entry_audio_events.append(event)
			assert_bool([AMBIENCE_CHANNEL, "action"].has(event.channel_name)).override_failure_message(
				"Timeline audio must use an owned channel: %s" % path).is_true()
			if event.file_path.is_empty():
				continue

			assert_str(event.file_path).starts_with(AUDIO_ROOT)
			assert_bool(catalog_paths.has(event.file_path)).override_failure_message(
				"Timeline audio is absent from the selected catalog: %s" % event.file_path).is_true()
			assert_bool(ResourceLoader.exists(event.file_path)).override_failure_message(
				"Missing bound audio resource: %s" % event.file_path).is_true()
			assert_object(load(event.file_path) as AudioStream).is_not_null()
			assert_bool(event.set_loop).is_true()
			assert_bool(event.set_audio_bus).is_true()
			assert_str(event.audio_bus).is_equal("SFX")
			if event.channel_name == AMBIENCE_CHANNEL:
				assert_bool(event.loop).is_true()
			else:
				assert_bool(event.loop).is_false()
				assert_bool(_action_stops_after_next_text(timeline.events, index)).override_failure_message(
					"Action cue must stop after its following text event: %s:%d" % [path, index]).is_true()
		if entry_audio_events.is_empty():
			continue
		assert_int(entry_audio_events.size()).override_failure_message(
			"Audio timeline must clear action and ambience in its first two audio events: %s" % path).is_equal(2)
		var entry_channels := {}
		for event in entry_audio_events:
			assert_bool(event.file_path.is_empty()).override_failure_message(
				"Timeline must start by clearing an audio channel: %s" % path).is_true()
			entry_channels[event.channel_name] = true
		for channel in [AMBIENCE_CHANNEL, "action"]:
			assert_bool(entry_channels.has(channel)).override_failure_message(
				"Timeline must clear %s at scene entry: %s" % [channel, path]).is_true()
	assert_int(audio_event_count).is_greater(0)


func _assert_action_cue_before_text(source: String, text_id: String, stream_path: String) -> void:
	var text_index := source.find("Text/%s/text #id:%s" % [text_id, text_id])
	assert_int(text_index).is_greater(-1)
	var action_index := source.rfind("audio action ", text_index)
	assert_int(action_index).is_greater(-1)
	assert_bool(source.substr(action_index, text_index - action_index).contains(stream_path)).is_true()
	var stop_index := source.find("audio action -", text_index)
	assert_int(stop_index).is_greater(text_index)


func test_story_audio_corrections_match_their_actions() -> void:
	var luyuan := FileAccess.get_file_as_string("res://timelines/06_luyuan.dtl")
	for text_id in ["lj_06_luyuan_006", "lj_06_luyuan_028", "lj_06_luyuan_050"]:
		_assert_action_cue_before_text(luyuan, text_id, "05_stone_footsteps/footsteps_stone_floor.mp3")
		var text_index := luyuan.find("Text/%s/text #id:%s" % [text_id, text_id])
		var ambience_index := luyuan.rfind("audio ambience ", text_index)
		assert_str(luyuan.substr(ambience_index, "audio ambience -".length())).is_equal("audio ambience -")
	for text_id in ["lj_06_luyuan_011", "lj_06_luyuan_019", "lj_06_luyuan_033", "lj_06_luyuan_041", "lj_06_luyuan_055", "lj_06_luyuan_063"]:
		_assert_action_cue_before_text(luyuan, text_id, "04_running_breath/alvarez_fernando_antropo_fonia_corriendo.mp3")

	var crossroads := FileAccess.get_file_as_string("res://timelines/03_crossroads.dtl")
	for text_id in ["lj_03_crossroads_019", "lj_03_crossroads_025"]:
		_assert_action_cue_before_text(crossroads, text_id, "24_coin_payment/coin_payment.mp3")
	assert_bool(not crossroads.contains("03_footsteps/footsteps_walking_through_woods.mp3")).is_true()

	var maze_entry := FileAccess.get_file_as_string("res://timelines/07_maze_entry.dtl")
	_assert_action_cue_before_text(maze_entry, "lj_07_maze_entry_009", "03_footsteps/footsteps_walking_through_woods.mp3")
	var maze_middle := FileAccess.get_file_as_string("res://timelines/07_maze_middle.dtl")
	_assert_action_cue_before_text(maze_middle, "lj_07_maze_middle_008", "05_stone_footsteps/footsteps_stone_floor.mp3")

	var ward := FileAccess.get_file_as_string("res://timelines/02_ward.dtl")
	assert_bool(not ward.contains("08_heavy_door/door_smash_1.mp3")).is_true()
	var maze_exit := FileAccess.get_file_as_string("res://timelines/07_maze_exit.dtl")
	assert_bool(not maze_exit.contains("03_footsteps/footsteps_walking_through_woods.mp3")).is_true()
	var shiling := FileAccess.get_file_as_string("res://timelines/05_shiling.dtl")
	assert_bool(not shiling.contains("13_ritual_temple/japan_kashiwa_shrine_hitting_a_small_gong.mp3")).is_true()
	var wife_room := FileAccess.get_file_as_string("res://timelines/08_wife_room.dtl")
	assert_bool(not wife_room.contains("18_whisper_horror/four_voices_whispering_6_with_echo.mp3")).is_true()


func test_audio_stop_event_trims_windows_line_ending() -> void:
	var event := DialogicAudioEvent.new()
	event.from_text("audio ambience -\r\n")
	assert_str(event.channel_name).is_equal(AMBIENCE_CHANNEL)
	assert_bool(event.file_path.is_empty()).is_true()


func test_faded_channel_replace_and_clear_leave_no_audio_player() -> void:
	Dialogic.Audio.update_audio(TEST_CHANNEL, AMBIENCE_PATH, {
		"audio_bus": "SFX",
		"loop": true,
	})
	await get_tree().process_frame
	assert_bool(Dialogic.Audio.current_audio_channels.has(TEST_CHANNEL)).is_true()
	var first_player := Dialogic.Audio.current_audio_channels[TEST_CHANNEL] as AudioStreamPlayer
	assert_object(first_player).is_not_null()
	assert_str(first_player.bus).is_equal("SFX")

	Dialogic.Audio.update_audio(TEST_CHANNEL, AMBIENCE_PATH, {
		"audio_bus": "SFX",
		"fade_length": 0.04,
		"loop": true,
	})
	await get_tree().process_frame
	var replacement := Dialogic.Audio.current_audio_channels[TEST_CHANNEL] as AudioStreamPlayer
	assert_bool(replacement != first_player).is_true()
	assert_bool(is_instance_valid(first_player)).is_true()
	assert_str(String(first_player.name)).ends_with("_Prev")

	Dialogic.Audio.update_audio(TEST_CHANNEL, "", {"fade_length": 0.04})
	assert_bool(Dialogic.Audio.current_audio_channels.has(TEST_CHANNEL)).is_false()
	await get_tree().create_timer(0.12).timeout
	assert_bool(is_instance_valid(first_player)).is_false()
	assert_bool(is_instance_valid(replacement)).is_false()
	for player in Dialogic.Audio.audio_node.get_children():
		assert_bool(String(player.name).begins_with(TEST_CHANNEL)).is_false()
