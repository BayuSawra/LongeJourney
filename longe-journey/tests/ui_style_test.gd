extends GdUnitTestSuite


func before() -> void:
	if not ProjectSettings.has_setting("validation/user_data_dir") or \
			OS.get_user_data_dir().replace("\\", "/") != str(ProjectSettings.get_setting("validation/user_data_dir")):
		push_error("Run UI style tests through tools/verify.py with isolated user data")
		get_tree().quit(2)


func test_menu_uses_cover_and_keyboard_focus() -> void:
	var menu := (load("res://scenes/mianMenu.tscn") as PackedScene).instantiate()
	add_child(menu)
	menu.get_node("BGM").stop()
	await get_tree().process_frame
	assert_str(menu.theme.resource_path).is_equal("res://ui/journey_theme.tres")
	assert_str(menu.get_node("Background").texture.resource_path).is_equal(
		"res://art/backgrounds/crossroads_bus_sunflower.png")
	var start := menu.get_node("UI/Button_start") as Button
	assert_bool(start.has_focus()).is_true()
	assert_str(str(start.theme_type_variation)).is_equal("PrimaryButton")
	for button in menu.get_node("UI").get_children():
		assert_object(button.icon).is_not_null()
		assert_float(button.size.y).is_greater_equal(44.0)
	menu.queue_free()
	await get_tree().process_frame


func test_hud_tools_are_visible_and_do_not_cover_values() -> void:
	var hud := (load("res://scenes/hud.tscn") as PackedScene).instantiate()
	add_child(hud)
	await get_tree().process_frame
	for button: Button in [hud.lore_button, hud.settings_button]:
		assert_bool(button.visible).is_true()
		assert_str(button.text).is_empty()
		assert_str(button.tooltip_text).is_not_empty()
		assert_object(button.icon).is_not_null()
		assert_bool(button.get_global_rect().intersects(hud.values.get_global_rect())).is_false()
	assert_bool(hud.lore_button.get_global_rect().intersects(hud.settings_button.get_global_rect())).is_false()
	for variable in ["flower", "money", "energy", "energy_bar", "calm", "calm_bar"]:
		assert_object(hud.values.get_node_or_null(variable)).is_not_null()
	hud.queue_free()
	await get_tree().process_frame


func test_theme_preserves_readable_text_and_distinct_primary_action() -> void:
	var theme := load("res://ui/journey_theme.tres") as Theme
	assert_int(theme.default_font_size).is_equal(20)
	assert_str(str(theme.get_type_variation_base("PrimaryButton"))).is_equal("Button")
	var normal := theme.get_stylebox("normal", "Button") as StyleBoxFlat
	var primary := theme.get_stylebox("normal", "PrimaryButton") as StyleBoxFlat
	assert_bool(normal.bg_color == primary.bg_color).is_false()
	assert_float(theme.get_color("font_color", "Button").get_luminance()).is_greater(0.8)
