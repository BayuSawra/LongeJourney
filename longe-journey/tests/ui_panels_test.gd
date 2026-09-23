extends GdUnitTestSuite


func before() -> void:
	if not ProjectSettings.has_setting("validation/user_data_dir") or \
			OS.get_user_data_dir().replace("\\", "/") != str(ProjectSettings.get_setting("validation/user_data_dir")):
		push_error("Run UI panel tests through tools/verify.py with isolated user data")
		get_tree().quit(2)


func test_modal_panels_share_theme_and_fit_baseline() -> void:
	var cases := [
		{"scene": "res://scenes/settings_panel.tscn", "panel": "Panel", "max_size": Vector2(960, 540)},
		{"scene": "res://scenes/save_slot_panel.tscn", "panel": "Panel", "max_size": Vector2(960, 540)},
		{"scene": "res://scenes/history_panel.tscn", "panel": "Overlay/Panel", "max_size": Vector2(960, 540)},
		{"scene": "res://scenes/lore_browser.tscn", "panel": "PanelContainer", "max_size": Vector2(960, 540)},
	]
	for case in cases:
		var scene := load(case.scene) as PackedScene
		assert_object(scene).is_not_null()
		var panel_root := scene.instantiate()
		add_child(panel_root)
		await get_tree().process_frame
		var panel := panel_root.get_node(case.panel) as Control
		assert_object(panel.theme).is_not_null()
		assert_float(panel.size.x).is_less_equal(case.max_size.x)
		assert_float(panel.size.y).is_less_equal(case.max_size.y)
		panel_root.queue_free()
		await get_tree().process_frame


func test_settings_values_and_panel_controls_are_visible() -> void:
	var settings := (load("res://scenes/settings_panel.tscn") as PackedScene).instantiate()
	add_child(settings)
	await get_tree().process_frame
	assert_str(settings.text_speed_value.text).is_equal(str(int(settings.text_speed_slider.value)))
	assert_str(settings.bgm_volume_value.text).is_equal("%d%%" % int(settings.bgm_volume_slider.value))
	settings.ui_volume_slider.value = 42
	assert_str(settings.ui_volume_value.text).is_equal("42%")
	assert_str(settings.close_button.tooltip_text).is_not_empty()
	settings.queue_free()
	await get_tree().process_frame


func test_history_paths_and_icon_controls_remain_available() -> void:
	var history := (load("res://scenes/history_panel.tscn") as PackedScene).instantiate()
	add_child(history)
	await get_tree().process_frame
	assert_object(history.get_node_or_null("Overlay/Panel/Main/Header/CloseButton")).is_not_null()
	assert_object(history.get_node_or_null("Overlay/Panel/Main/Scroll/List")).is_not_null()
	assert_object(history.history_button.icon).is_not_null()
	assert_str(history.history_button.tooltip_text).is_not_empty()
	history.queue_free()
	await get_tree().process_frame
