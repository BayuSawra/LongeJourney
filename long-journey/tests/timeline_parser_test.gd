extends GdUnitTestSuite


func _process_text(text: String) -> DialogicTimeline:
	var timeline := DialogicTimeline.new()
	timeline.from_text(text)
	timeline.process()
	return timeline


func _end_branch_indices(timeline: DialogicTimeline) -> Array[int]:
	var indices: Array[int] = []
	for index in timeline.events.size():
		if timeline.events[index] is DialogicEndBranchEvent:
			indices.append(index)
	return indices


func test_trailing_space_indentation_closes_each_open_level_once() -> void:
	var timeline := _process_text("- first\n    - second\n        jump target\n")
	assert_array(_end_branch_indices(timeline)).is_equal([3, 4])


func test_trailing_tab_indentation_closes_open_level_once() -> void:
	var timeline := _process_text("- first\n\tjump target\n")
	assert_array(_end_branch_indices(timeline)).is_equal([2])


func test_project_timeline_ending_inside_choice_has_single_end_branch() -> void:
	var timeline := load("res://timelines/00_start.dtl") as DialogicTimeline
	assert_object(timeline).is_not_null()
	timeline.process()
	assert_array(_end_branch_indices(timeline)).is_equal([timeline.events.size() - 1])


func test_shiling_remaining_variable_is_declared_and_calculated() -> void:
	var timeline := load("res://timelines/05_4shiling.dtl") as DialogicTimeline
	assert_object(timeline).is_not_null()
	timeline.process()
	var variable_event := timeline.events[0] as DialogicVariableEvent
	assert_object(variable_event).is_not_null()
	assert_str(variable_event.name).is_equal("remaining")
	assert_bool(Dialogic.VAR.has(variable_event.name)).is_true()

	var original_flower = Dialogic.VAR.get_variable("flower")
	Dialogic.VAR.set_variable("flower", 2)
	variable_event.execute(Dialogic)
	await get_tree().process_frame
	assert_float(float(Dialogic.VAR.get_variable("remaining"))).is_equal(3.0)
	Dialogic.VAR.set_variable("flower", original_flower)


func test_luyuan_name_input_stores_player_name() -> void:
	var timeline := load("res://timelines/06_luyuan.dtl") as DialogicTimeline
	assert_object(timeline).is_not_null()
	timeline.process()

	var input: DialogicTextInputEvent
	var greeting: DialogicTextEvent
	var found_location := false
	var jump_targets: PackedStringArray = []
	for event in timeline.events:
		if event is DialogicTextEvent and event._translation_id == "lj_06_luyuan_000":
			found_location = true
			assert_str(event.text).is_equal("[color=#696969][i]※当前位置  露园※[/i][/color]")
		elif event is DialogicTextInputEvent and input == null:
			input = event
		elif input != null and greeting == null and event is DialogicTextEvent:
			greeting = event
		elif event is DialogicJumpEvent:
			jump_targets.append(event.timeline_identifier)

	assert_bool(found_location).is_true()
	assert_object(input).is_not_null()
	assert_str(input.text).is_equal("如果我是王，我叫做：")
	assert_str(input.variable).is_equal("player_name")
	assert_str(input.placeholder).is_equal("输入名字")
	assert_str(input.default).is_empty()
	assert_bool(input.allow_empty).is_true()
	assert_object(greeting).is_not_null()
	assert_str(greeting.text).is_equal("我是{player_name}")
	assert_bool(jump_targets.has("07_maze_entry")).is_true()
	assert_bool(jump_targets.has("03_crossroads")).is_true()

	var original_name = Dialogic.VAR.get_variable("player_name")
	input.execute(Dialogic)
	await get_tree().process_frame
	Dialogic.TextInput.input_confirmed.emit("海临")
	await get_tree().process_frame
	assert_str(str(Dialogic.VAR.get_variable("player_name"))).is_equal("海临")
	assert_str(GameState.player_name).is_equal("海临")

	input.execute(Dialogic)
	await get_tree().process_frame
	Dialogic.TextInput.input_confirmed.emit("")
	await get_tree().process_frame
	assert_str(str(Dialogic.VAR.get_variable("player_name"))).is_empty()
	assert_str(GameState.player_name).is_empty()
	assert_str(Localization.player_name("")).is_equal(Localization.text("player.default_name"))
	GameState.set_var("player_name", original_name)
