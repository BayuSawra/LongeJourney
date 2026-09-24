@tool
extends EditorPlugin

const BUTTON_KEY := "ui.mainmenu.button_start.text"


func _enter_tree() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ProjectSettings.has_setting("validation/user_data_dir") or \
			OS.get_user_data_dir().replace("\\", "/") != str(ProjectSettings.get_setting("validation/user_data_dir")):
		_fail("Run editor localization check through tools/verify.py with isolated user data")
		return
	if not Engine.is_editor_hint():
		_fail("Editor localization check requires --editor")
		return
	var expected_locale := "zh_CN"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--expected-locale="):
			expected_locale = argument.trim_prefix("--expected-locale=")
	if expected_locale not in ["zh_CN", "en"]:
		_fail("Unsupported expected preview locale: " + expected_locale)
		return
	var menu: PopupMenu
	for frame in range(600):
		await get_tree().process_frame
		var base := EditorInterface.get_base_control()
		if base != null:
			var menus := base.find_children("*", "EditorTranslationPreviewMenu", true, false)
			if not menus.is_empty():
				menu = menus[0] as PopupMenu
				break
	if menu == null:
		_fail("Native translation preview menu did not become available")
		return
	for frame in range(8):
		await get_tree().process_frame
	if not await _wait_for_filesystem():
		return
	EditorInterface.open_scene_from_path("res://scenes/mainMenu.tscn")
	var scene: Node
	for frame in range(600):
		await get_tree().process_frame
		scene = EditorInterface.get_edited_scene_root()
		if scene != null and scene.scene_file_path == "res://scenes/mainMenu.tscn":
			break
	if scene == null or scene.scene_file_path != "res://scenes/mainMenu.tscn":
		_fail("Main menu did not open in the scene editor")
		return
	var button := scene.get_node("UI/Button_start") as Button
	if not _check_preview(button, expected_locale):
		return
	for locale in ["en", "", "zh_CN", "en"]:
		if not _select_locale(menu, locale):
			return
		for frame in range(3):
			await get_tree().process_frame
		if not _check_preview(button, locale):
			return
	# Leave English selected so the next editor process can test persistence.
	for frame in range(8):
		await get_tree().process_frame
	EditorInterface.save_all_scenes()
	if not await _wait_for_filesystem():
		return
	print("EDITOR_LOCALIZATION_CHECK_PASSED")
	await _close_editor()


func _close_editor() -> void:
	# Native editor shutdown unloads plugins and persists project metadata.
	var base := EditorInterface.get_base_control()
	var editor := base.get_parent()
	editor.notification.call_deferred(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		# Native editor dialogs can be reparented to the root Window in headless mode.
		for dialog in get_tree().root.find_children("*", "ConfirmationDialog", true, false):
			if not dialog.visible:
				continue
			for connection in dialog.get_signal_connection_list(&"confirmed"):
				var callback: Callable = connection.callable
				if str(callback) == "EditorNode::_menu_confirm_current":
					print("EDITOR_EXIT_SAVE: ", dialog.dialog_text)
					dialog.get_ok_button().emit_signal.call_deferred(&"pressed")
					break
	_fail("Editor did not finish its native save-and-quit sequence")


func _wait_for_filesystem() -> bool:
	var deadline := Time.get_ticks_msec() + 30000
	while EditorInterface.get_resource_filesystem().is_scanning():
		if Time.get_ticks_msec() >= deadline:
			return _fail("Editor filesystem scan did not complete within 30 seconds")
		await get_tree().process_frame
	return true


func _check_preview(button: Button, locale: String) -> bool:
	var domain := TranslationServer.get_or_add_domain(&"")
	if domain.enabled != (not locale.is_empty()):
		return _fail("Unexpected translation preview enabled state for " + locale)
	if not locale.is_empty() and domain.get_locale_override() != locale:
		return _fail("Expected preview locale %s, got %s" % [locale, domain.get_locale_override()])
	if str(EditorInterface.get_editor_settings().get_project_metadata("editor_metadata", "preview_locale", "")) != locale:
		return _fail("Native preview selection was not persisted: " + locale)
	if button == null or button.text != BUTTON_KEY:
		return _fail("Scene button no longer stores its stable translation key")
	if button.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED:
		return _fail("Scene button has auto translation disabled")
	var expected := BUTTON_KEY
	if not locale.is_empty():
		var catalog := load("res://localization/%s.po" % locale) as Translation
		expected = catalog.get_message(BUTTON_KEY)
		if expected.is_empty() or expected == BUTTON_KEY:
			return _fail("Missing expected catalog text: " + locale)
	if button.tr(button.text) != expected:
		return _fail("Scene button did not translate to %s: %s" % [locale, button.tr(button.text)])
	print("EDITOR_PREVIEW %s: %s" % [locale, button.tr(button.text)])
	return true


func _select_locale(menu: PopupMenu, locale: String) -> bool:
	menu.about_to_popup.emit()
	for index in menu.item_count:
		if str(menu.get_item_metadata(index)) == locale:
			menu.index_pressed.emit(index)
			return true
	return _fail("Native preview menu is missing locale: " + locale)


func _fail(message: String) -> bool:
	push_error(message)
	get_tree().quit(1)
	return false
