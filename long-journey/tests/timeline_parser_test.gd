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
