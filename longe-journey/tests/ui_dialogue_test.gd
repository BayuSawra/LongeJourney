extends GdUnitTestSuite


func before() -> void:
	if not ProjectSettings.has_setting("validation/user_data_dir") or \
			OS.get_user_data_dir().replace("\\", "/") != str(ProjectSettings.get_setting("validation/user_data_dir")):
		push_error("Run UI dialogue tests through tools/verify.py with isolated user data")
		get_tree().quit(2)


func test_textbox_uses_responsive_22px_dialogue_panel() -> void:
	var layout := (load("res://addons/dialogic/Modules/DefaultLayoutParts/Base_Default/default_layout_base.tscn") as PackedScene).instantiate() as DialogicLayoutBase
	add_child(layout)
	var textbox := (load("res://scenes/dialogic_textbox_layer.tscn") as PackedScene).instantiate()
	layout.add_child(textbox)
	await get_tree().process_frame
	layout.apply_export_overrides()
	var sizer := textbox.get_node("Anchor/AnimationParent/Sizer") as Control
	var expected_width := minf(1000.0, get_viewport().get_visible_rect().size.x - 64.0)
	assert_float(sizer.size.x).is_equal(expected_width)
	assert_float(sizer.size.y).is_equal(156.0)
	assert_float(sizer.position.y).is_equal(-180.0)
	var text := textbox.get_node("Anchor/AnimationParent/Sizer/DialogTextPanel/DialogicNode_DialogText") as RichTextLabel
	assert_int(text.get_theme_font_size(&"normal_font_size")).is_equal(22)
	var name_label := textbox.get_node("Anchor/AnimationParent/Sizer/DialogTextPanel/NameLabelHolder/NameLabelPanel/DialogicNode_NameLabel") as Label
	assert_int(name_label.get_theme_font_size(&"font_size")).is_equal(22)
	layout.queue_free()


func test_choice_layer_uses_centered_warm_white_buttons() -> void:
	var layout := (load("res://addons/dialogic/Modules/DefaultLayoutParts/Base_Default/default_layout_base.tscn") as PackedScene).instantiate() as DialogicLayoutBase
	add_child(layout)
	var choices := (load("res://scenes/dialogic_choice_layer.tscn") as PackedScene).instantiate()
	layout.add_child(choices)
	await get_tree().process_frame
	layout.apply_export_overrides()
	var container := choices.get_node("Choices") as VBoxContainer
	assert_float(container.anchor_left).is_equal(0.5)
	assert_float(container.anchor_top).is_equal(0.0)
	assert_float(container.anchor_right).is_equal(0.5)
	assert_float(container.anchor_bottom).is_equal(1.0)
	assert_float(container.offset_left).is_equal(-380.0)
	assert_float(container.offset_top).is_equal(0.0)
	assert_float(container.offset_right).is_equal(380.0)
	assert_float(container.offset_bottom).is_equal(0.0)
	assert_int(container.alignment).is_equal(BoxContainer.ALIGNMENT_CENTER)
	var first_button := container.get_child(1) as Button
	assert_object(first_button).is_not_null()
	assert_int(first_button.get_theme_font_size(&"font_size")).is_equal(22)
	assert_that(first_button.get_theme_color(&"font_color")).is_equal(Color(0.925, 0.922, 0.895, 1))
	assert_int(first_button.autowrap_mode).is_equal(TextServer.AUTOWRAP_WORD_SMART)
	layout.queue_free()


func test_crossroads_choices_stay_centered_and_clear_hud_and_textbox() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	viewport.disable_3d = true
	add_child(viewport)
	var layout := (load("res://addons/dialogic/Modules/DefaultLayoutParts/Base_Default/default_layout_base.tscn") as PackedScene).instantiate() as DialogicLayoutBase
	viewport.add_child(layout)
	var hud := (load("res://scenes/hud.tscn") as PackedScene).instantiate()
	viewport.add_child(hud)
	var textbox := (load("res://scenes/dialogic_textbox_layer.tscn") as PackedScene).instantiate()
	layout.add_child(textbox)
	var choices := (load("res://scenes/dialogic_choice_layer.tscn") as PackedScene).instantiate()
	choices.set("maximum_choices", 4)
	layout.add_child(choices)
	layout.apply_export_overrides()
	var container := choices.get_node("Choices") as VBoxContainer
	var buttons: Array[DialogicNode_ChoiceButton] = []
	for child in container.get_children():
		if child is DialogicNode_ChoiceButton:
			buttons.append(child)
	assert_int(buttons.size()).is_equal(4)
	var catalog := load("res://localization/en.po") as Translation
	var choice_ids := ["012", "018", "024", "030"]
	# Physical windows below the project's 1152x648 design size are stretched.
	# Cover logical viewport sizes here; the GL driver covers smaller windows.
	for resolution: Vector2i in [Vector2i(1152, 648), Vector2i(1024, 768), Vector2i(1600, 900)]:
		viewport.size = resolution
		for unavailable: bool in [false, true]:
			for index in range(buttons.size()):
				var disabled := unavailable and index < 3
				var field := "disabled_text" if disabled else "text"
				var key := "Choice/lj_03_crossroads_%s/%s" % [choice_ids[index], field]
				var translated := String(catalog.get_message(key))
				assert_str(translated).is_not_empty()
				buttons[index]._load_info({
					"text": translated, "visible": true, "disabled": disabled,
					"event_index": index, "button_index": index + 1,
				})
				assert_str(buttons[index].text).is_equal(translated)
				assert_bool(buttons[index].disabled).is_equal(disabled)
			# Visibility, wrapping and container sorting settle on deferred frames.
			for frame in range(3):
				await get_tree().process_frame
			# VisualFX scales new buttons for 0.22 seconds, including in headless runs.
			await get_tree().create_timer(0.3).timeout
			var viewport_rect := viewport.get_visible_rect()
			var hud_rect := (hud.get_node("Panel") as Control).get_global_rect()
			var tools_rect := (hud.get_node("Tools") as Control).get_global_rect()
			var textbox_rect := (textbox.get_node("Anchor/AnimationParent/Sizer/DialogTextPanel") as Control).get_global_rect()
			var region := container.get_global_rect()
			assert_float(region.get_center().x).is_equal(viewport_rect.get_center().x)
			assert_float(region.get_center().y).is_equal(viewport_rect.get_center().y)
			assert_float(region.size.x).is_equal(760.0)
			assert_float(region.size.y).is_equal(float(resolution.y))
			assert_bool(viewport_rect.encloses(region)).is_true()
			for index in range(buttons.size()):
				var button := buttons[index]
				var rect := button.get_global_rect()
				assert_bool(button.is_visible_in_tree()).is_true()
				assert_bool(region.encloses(rect)).is_true()
				assert_bool(viewport_rect.encloses(rect)).is_true()
				assert_bool(rect.intersects(hud_rect)).is_false()
				assert_bool(rect.intersects(tools_rect)).is_false()
				assert_bool(rect.intersects(textbox_rect)).is_false()
				assert_float(rect.size.y).is_greater_equal(52.0)
				assert_float(rect.size.x).is_equal(region.size.x)
				if index > 0:
					assert_float(rect.position.y - buttons[index - 1].get_global_rect().end.y).is_greater_equal(10.0)
				_assert_choice_text_fits(button)
			_assert_choices_centered(buttons, viewport_rect)
		# Fewer choices must recenter instead of keeping the previous group's top edge.
		for count in [1, 2, 3, 4]:
			for index in range(buttons.size()):
				buttons[index].visible = index < count
			for frame in range(3):
				await get_tree().process_frame
			_assert_choices_centered(buttons, viewport.get_visible_rect())
		# The longest English choice belongs to a single-choice maze event.
		for index in range(buttons.size()):
			buttons[index].visible = index == 0
		buttons[0].disabled = false
		buttons[0].text = catalog.get_message("Choice/lj_07_maze_left_008/text")
		assert_str(buttons[0].text).is_not_empty()
		for frame in range(3):
			await get_tree().process_frame
		_assert_choices_centered(buttons, viewport.get_visible_rect())
		_assert_choice_text_fits(buttons[0])
	viewport.queue_free()
	await get_tree().process_frame


func _assert_choices_centered(buttons: Array[DialogicNode_ChoiceButton], viewport_rect: Rect2) -> void:
	var group_rect := Rect2()
	var first := true
	for button in buttons:
		if not button.visible:
			continue
		var rect := button.get_global_rect()
		assert_float(rect.get_center().x).is_equal_approx(viewport_rect.get_center().x, 0.5)
		group_rect = rect if first else group_rect.merge(rect)
		first = false
	assert_bool(first).is_false()
	assert_float(group_rect.get_center().y).is_equal_approx(viewport_rect.get_center().y, 0.5)


func _assert_choice_text_fits(button: Button) -> void:
	var style := button.get_theme_stylebox(&"disabled" if button.disabled else &"normal")
	var content_size := button.size - style.get_minimum_size()
	var font := button.get_theme_font(&"font")
	var font_size := button.get_theme_font_size(&"font_size")
	var text_size := font.get_multiline_string_size(button.text, button.alignment, content_size.x, font_size)
	assert_int(font_size).is_equal(22)
	assert_bool(button.clip_text).is_false()
	assert_int(button.text_overrun_behavior).is_equal(TextServer.OVERRUN_NO_TRIMMING)
	assert_float(text_size.x).is_less_equal(content_size.x)
	assert_float(text_size.y).is_less_equal(content_size.y)


func test_text_input_uses_dialogue_surfaces() -> void:
	var layout := (load("res://addons/dialogic/Modules/DefaultLayoutParts/Base_Default/default_layout_base.tscn") as PackedScene).instantiate() as DialogicLayoutBase
	add_child(layout)
	var input_layer := (load("res://scenes/dialogic_text_input.tscn") as PackedScene).instantiate()
	layout.add_child(input_layer)
	await get_tree().process_frame
	layout.apply_export_overrides()
	var input_node := input_layer.get_node("DialogicNode_TextInput") as Control
	assert_float(input_node.size.x).is_equal(720.0)
	assert_float(input_node.size.y).is_equal(236.0)
	var panel := input_node.get_node("TextInputPanel") as PanelContainer
	assert_object(panel.get_theme_stylebox(&"panel")).is_not_null()
	var confirmation := input_node.get_node("TextInputPanel/VBoxContainer/ConfirmationButton") as Button
	assert_int(confirmation.get_theme_font_size(&"font_size")).is_equal(20)
	layout.queue_free()
