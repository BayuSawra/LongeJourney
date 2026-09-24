extends GdUnitTestSuite


func before() -> void:
	if not ProjectSettings.has_setting("validation/user_data_dir") or \
			OS.get_user_data_dir().replace("\\", "/") != str(ProjectSettings.get_setting("validation/user_data_dir")):
		push_error("Run UI style tests through tools/verify.py with isolated user data")
		get_tree().quit(2)


func test_main_menu_names_and_translation_keys() -> void:
	assert_str(str(ProjectSettings.get_setting("application/run/main_scene"))).is_equal(
		"res://scenes/mainMenu.tscn")
	for path in ["res://scenes/mainMenu.tscn", "res://scenes/mainMenu_legacy_snake.tscn"]:
		var menu := (load(path) as PackedScene).instantiate()
		assert_str(str(menu.name)).is_equal("MainMenu")
		for action in ["start", "save", "load", "setting", "exit"]:
			var key := "ui.mainmenu.button_%s.text" % action
			var button := menu.get_node("UI/Button_%s" % action) as Button
			assert_str(button.text).is_equal(key)
			for language in Localization.supported_locales():
				assert_str(Localization.text_in(language, key)).is_not_empty()
		menu.free()


func test_menu_uses_cover_and_keyboard_focus() -> void:
	var menu := (load("res://scenes/mainMenu.tscn") as PackedScene).instantiate()
	add_child(menu)
	menu.get_node("BGM").stop()
	await get_tree().process_frame
	assert_str(menu.theme.resource_path).is_equal("res://ui/journey_theme.tres")
	assert_str(menu.get_node("Background").texture.resource_path).is_equal(
		"res://art/backgrounds/crossroads.png")
	var start := menu.get_node("UI/Button_start") as Button
	assert_bool(start.has_focus()).is_true()
	assert_str(str(start.theme_type_variation)).is_equal("PrimaryButton")
	for button in menu.get_node("UI").get_children():
		assert_object(button.icon).is_not_null()
		assert_float(button.size.y).is_greater_equal(44.0)
	menu.queue_free()
	await get_tree().process_frame


func test_legacy_snake_menu_is_available_for_comparison() -> void:
	var menu := (load("res://scenes/mainMenu_legacy_snake.tscn") as PackedScene).instantiate()
	add_child(menu)
	menu.get_node("BGM").stop()
	await get_tree().process_frame
	assert_str(menu.get_node("Panel/img_qiuyin").texture.resource_path).is_equal("res://art/1.png")
	assert_object(menu.get_node("Distortion").material).is_not_null()
	assert_bool(menu.get_node("UI/Button_start").has_focus()).is_true()
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

func test_dialogic_text_input_uses_private_theme_without_mutating_shared_theme() -> void:
	await Dialogic.end_timeline(true)
	await get_tree().process_frame
	var shared_theme := load("res://ui/journey_theme.tres") as Theme
	assert_int(shared_theme.default_font_size).is_equal(20)

	var layout := Dialogic.start("00_start")
	for _frame in 30:
		if layout != null and layout.is_inside_tree() and layout.is_node_ready():
			break
		await get_tree().process_frame
	if layout == null or not layout.is_inside_tree() or not layout.is_node_ready():
		fail("Dialogic layout did not become ready")
		await Dialogic.end_timeline(true)
		await get_tree().process_frame
		return

	var text_input_layer := layout.get_node_or_null("TextInputLayer") as Control
	if text_input_layer == null:
		fail("Dialogic layout is missing the text input layer")
		await Dialogic.end_timeline(true)
		await get_tree().process_frame
		return
	var private_theme := text_input_layer.theme
	assert_object(private_theme).is_not_null()
	assert_object(private_theme).is_not_same(shared_theme)
	assert_int(shared_theme.default_font_size).is_equal(20)
	assert_int(private_theme.default_font_size).is_equal(18)

	await Dialogic.end_timeline(true)
	await get_tree().process_frame
