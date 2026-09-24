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
	for clip: Dictionary in catalog.get("clips", []):
		paths[clip["path"]] = true
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
	for text_id in ["lj_02_ward_016", "lj_02_ward_027"]:
		_assert_action_cue_before_text(ward, text_id, "26_hospital_door/creaky_door_open.wav")
	var maze_exit := FileAccess.get_file_as_string("res://timelines/07_maze_exit.dtl")
	assert_bool(not maze_exit.contains("03_footsteps/footsteps_walking_through_woods.mp3")).is_true()
	var shiling := FileAccess.get_file_as_string("res://timelines/05_shiling.dtl")
	assert_bool(not shiling.contains("13_ritual_temple/japan_kashiwa_shrine_hitting_a_small_gong.mp3")).is_true()
	var wife_room := FileAccess.get_file_as_string("res://timelines/08_wife_room.dtl")
	_assert_action_cue_before_text(wife_room, "lj_08_wife_room_009", "27_curtain/curtains_textile_texture_wav.mp3")
	_assert_action_cue_before_text(wife_room, "lj_08_wife_room_038", "40_female_whisper/whisper_once.wav")


func _catalog_group_by_name(catalog: Dictionary, group_name: String) -> Dictionary:
	for group: Dictionary in catalog["groups"]:
		if str(group.get("group", "")) == group_name:
			return group
	return {}


func test_sfx_catalog_manifest_contains_forty_loadable_streams() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/sfx_catalog.json"))
	var groups: Array = catalog["groups"]
	var seen_paths := {}
	assert_int(int(catalog["selected_count"])).is_equal(40)
	assert_int(groups.size()).is_equal(40)
	for group: Dictionary in groups:
		var stream_path := str(group["path"])
		assert_str(stream_path).starts_with(AUDIO_ROOT)
		assert_str(str(group["file"])).is_equal(stream_path.trim_prefix("res://"))
		assert_bool(seen_paths.has(stream_path)).override_failure_message(
			"Catalog must not list a stream twice: %s" % stream_path).is_false()
		seen_paths[stream_path] = true
		assert_bool(FileAccess.file_exists(stream_path)).override_failure_message(
			"Selected catalog stream is missing: %s" % stream_path).is_true()
		assert_bool(ResourceLoader.exists(stream_path)).override_failure_message(
			"Selected catalog stream is not importable: %s" % stream_path).is_true()
		assert_object(load(stream_path) as AudioStream).override_failure_message(
			"Selected catalog stream does not load as AudioStream: %s" % stream_path).is_not_null()

	var clips: Array = catalog["clips"]
	var expected_clips := {
		"res://audio/sfx/28_bucket_spill/bucket_drop_once.wav": {"source_track_id": "28_1", "source_file": "audio/sfx/28_bucket_spill/plastic_bucket_drop_wav.mp3"},
		"res://audio/sfx/33_wood_impact/wood_impact_once.wav": {"source_track_id": "33_1", "source_file": "audio/sfx/33_wood_impact/hammer_on_wood_martelo_em_madeira.mp3"},
		"res://audio/sfx/36_light_buzz/light_hum_loop.wav": {"source_track_id": "36_1", "source_file": "audio/sfx/36_light_buzz/fluorescent_light_turn_on_hum_buzz_various_flac.mp3"},
		"res://audio/sfx/37_phone_handling/phone_pickup_once.wav": {"source_track_id": "37_1", "source_file": "audio/sfx/37_phone_handling/selected.mp3"},
		"res://audio/sfx/39_basket_handling/basket_lift_once.wav": {"source_track_id": "39_3", "source_file": "audio/sfx/39_basket_handling/selected.mp3"},
		"res://audio/sfx/40_female_whisper/whisper_once.wav": {"source_track_id": "40_1", "source_file": "audio/sfx/40_female_whisper/55_whisper_strangeness_woman_wav.mp3"},
	}
	var seen_clip_paths := {}
	assert_int(clips.size()).is_equal(expected_clips.size())
	for clip: Dictionary in clips:
		var clip_path := str(clip["path"])
		assert_bool(expected_clips.has(clip_path)).override_failure_message(
			"Unexpected derived audio clip: %s" % clip_path).is_true()
		assert_bool(seen_clip_paths.has(clip_path)).override_failure_message(
			"Derived audio clip is listed twice: %s" % clip_path).is_false()
		seen_clip_paths[clip_path] = true
		var expected: Dictionary = expected_clips[clip_path]
		assert_str(str(clip["file"])).is_equal(clip_path.trim_prefix("res://"))
		assert_str(str(clip["source_track_id"])).is_equal(str(expected["source_track_id"]))
		assert_str(str(clip["source_file"])).is_equal(str(expected["source_file"]))
		assert_float(float(clip["start_seconds"])).is_greater_equal(0.0)
		assert_float(float(clip["duration_seconds"])).is_greater(0.0)
		assert_float(float(clip["fade_seconds"])).is_greater_equal(0.0)
		assert_bool(FileAccess.file_exists(clip_path)).override_failure_message(
			"Derived audio clip is missing: %s" % clip_path).is_true()
		assert_bool(ResourceLoader.exists(clip_path)).override_failure_message(
			"Derived audio clip is not importable: %s" % clip_path).is_true()
		assert_object(load(clip_path) as AudioStream).override_failure_message(
			"Derived audio clip does not load as AudioStream: %s" % clip_path).is_not_null()


func test_new_catalog_groups_preserve_metadata_and_resources() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/sfx_catalog.json"))
	var expected_groups := {
		"25_bus_arrival": {"track_id": "25_3", "kind": "动作", "path": "res://audio/sfx/25_bus_arrival/bus_coach_ext_pull_up_brake_air_release_idle.mp3"},
		"26_hospital_door": {"track_id": "26_1", "kind": "动作", "path": "res://audio/sfx/26_hospital_door/creaky_door_open.wav"},
		"27_curtain": {"track_id": "27_1", "kind": "动作", "path": "res://audio/sfx/27_curtain/curtains_textile_texture_wav.mp3"},
		"28_bucket_spill": {"track_id": "28_1", "kind": "分层动作", "path": "res://audio/sfx/28_bucket_spill/plastic_bucket_drop_wav.mp3"},
		"29_road_steps": {"track_id": "29_2", "kind": "脚步", "path": "res://audio/sfx/29_road_steps/light_footsteps_on_concrete_walking_wav.mp3"},
		"30_fire_loop": {"track_id": "30_1", "kind": "环境", "path": "res://audio/sfx/30_fire_loop/campfire_crackles.wav"},
		"31_banquet": {"track_id": "31_1", "kind": "环境", "path": "res://audio/sfx/31_banquet/dinner_atmo_wav.mp3"},
		"32_female_humming": {"track_id": "32_2", "kind": "人物声音", "path": "res://audio/sfx/32_female_humming/woman_humming.mp3"},
		"33_wood_impact": {"track_id": "33_1", "kind": "撞击", "path": "res://audio/sfx/33_wood_impact/hammer_on_wood_martelo_em_madeira.mp3"},
		"34_body_scuffle": {"track_id": "34_2", "kind": "动作", "path": "res://audio/sfx/34_body_scuffle/body_fall_wav.mp3"},
		"35_muffled_voices": {"track_id": "35_1", "kind": "环境", "path": "res://audio/sfx/35_muffled_voices/muffled_voices_mp3.mp3"},
		"36_light_buzz": {"track_id": "36_1", "kind": "环境", "path": "res://audio/sfx/36_light_buzz/fluorescent_light_turn_on_hum_buzz_various_flac.mp3"},
		"37_phone_handling": {"track_id": "37_1", "kind": "动作", "path": "res://audio/sfx/37_phone_handling/selected.mp3"},
		"38_soil_rummage": {"track_id": "38_1", "kind": "动作", "path": "res://audio/sfx/38_soil_rummage/selected.mp3"},
		"39_basket_handling": {"track_id": "39_3", "kind": "动作", "path": "res://audio/sfx/39_basket_handling/selected.mp3"},
		"40_female_whisper": {"track_id": "40_1", "kind": "人物声音", "path": "res://audio/sfx/40_female_whisper/55_whisper_strangeness_woman_wav.mp3"},
	}
	assert_int(expected_groups.size()).is_equal(16)
	for group_name in expected_groups:
		var expected: Dictionary = expected_groups[group_name]
		var actual := _catalog_group_by_name(catalog, str(group_name))
		assert_bool(not actual.is_empty()).override_failure_message(
			"Missing selected catalog group: %s" % group_name).is_true()
		assert_str(str(actual.get("track_id", ""))).is_equal(str(expected["track_id"]))
		assert_str(str(actual.get("kind", ""))).is_equal(str(expected["kind"]))
		assert_str(str(actual.get("path", ""))).is_equal(str(expected["path"]))
		assert_bool(not str(actual.get("candidate", "")).is_empty()).is_true()
		assert_bool(str(actual.get("source_url", "")).begins_with("https://")).is_true()
		assert_bool(not str(actual.get("context", "")).is_empty()).is_true()
		assert_bool(FileAccess.file_exists(str(expected["path"]))).is_true()
		assert_object(load(str(expected["path"])) as AudioStream).is_not_null()


func test_new_story_action_cues_use_selected_streams() -> void:
	var start := FileAccess.get_file_as_string("res://timelines/00_start.dtl")
	_assert_action_cue_before_text(start, "lj_00_start_008", "25_bus_arrival/bus_coach_ext_pull_up_brake_air_release_idle.mp3")
	var crossroads := FileAccess.get_file_as_string("res://timelines/03_crossroads.dtl")
	for text_id in ["lj_03_crossroads_003", "lj_03_crossroads_008"]:
		_assert_action_cue_before_text(crossroads, text_id, "25_bus_arrival/bus_coach_ext_pull_up_brake_air_release_idle.mp3")
	_assert_action_cue_before_text(crossroads, "lj_03_crossroads_013", "29_road_steps/light_footsteps_on_concrete_walking_wav.mp3")
	var hospital := FileAccess.get_file_as_string("res://timelines/01_hospital.dtl")
	_assert_action_cue_before_text(hospital, "lj_01_hospital_002", "37_phone_handling/phone_pickup_once.wav")
	var flower_shop := FileAccess.get_file_as_string("res://timelines/04_flower_shop.dtl")
	_assert_action_cue_before_text(flower_shop, "lj_04_flower_shop_005", "28_bucket_spill/bucket_drop_once.wav")
	_assert_action_cue_before_text(flower_shop, "lj_04_flower_shop_011", "38_soil_rummage/selected.mp3")
	var maze_exit := FileAccess.get_file_as_string("res://timelines/07_maze_exit.dtl")
	_assert_action_cue_before_text(maze_exit, "lj_07_maze_exit_004", "29_road_steps/light_footsteps_on_concrete_walking_wav.mp3")
	var maze_middle := FileAccess.get_file_as_string("res://timelines/07_maze_middle.dtl")
	_assert_action_cue_before_text(maze_middle, "lj_07_maze_middle_015_face", "32_female_humming/woman_humming.mp3")
	var morgue := FileAccess.get_file_as_string("res://timelines/10_morgue.dtl")
	_assert_action_cue_before_text(morgue, "lj_10_morgue_007", "39_basket_handling/basket_lift_once.wav")


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
