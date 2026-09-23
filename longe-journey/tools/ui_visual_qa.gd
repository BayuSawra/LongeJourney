extends SceneTree

## UI acceptance driver. It runs only from tools/ui_visual_qa.py's disposable copy.
const CAPTURE_NAMES := ["main-menu", "settings", "lore", "dialogue-hud", "save-load", "history", "choices"]

var report_dir := ""
var expected_size := Vector2i.ZERO
var locale := ""
var failures: Array[String] = []
var checks: Array[Dictionary] = []
var captures: Array[String] = []
var dialogic: DialogicGameHandler
var settings_manager: Node
var save_manager: Node


func _initialize() -> void:
	_parse_args()
	call_deferred("_run")


func _parse_args() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-report="):
			report_dir = argument.trim_prefix("--qa-report=")
		elif argument.begins_with("--qa-width="):
			expected_size.x = int(argument.trim_prefix("--qa-width="))
		elif argument.begins_with("--qa-height="):
			expected_size.y = int(argument.trim_prefix("--qa-height="))
		elif argument.begins_with("--qa-locale="):
			locale = argument.trim_prefix("--qa-locale=")
	if report_dir.is_empty() or expected_size.x <= 0 or expected_size.y <= 0 or locale.is_empty():
		push_error("UI visual QA requires --qa-report, --qa-width, --qa-height, and --qa-locale")
		quit(2)


func _run() -> void:
	if not ProjectSettings.has_setting("validation/user_data_dir") or \
			OS.get_user_data_dir().replace("\\", "/") != str(ProjectSettings.get_setting("validation/user_data_dir")):
		push_error("Run UI visual QA through tools/ui_visual_qa.py with isolated user data")
		quit(2)
		return
	dialogic = root.get_node("Dialogic") as DialogicGameHandler
	settings_manager = root.get_node("SettingsManager")
	save_manager = root.get_node("SaveManager")
	DirAccess.make_dir_recursive_absolute(report_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(expected_size)
	await _stable()
	_check(root.size == expected_size, "window viewport uses requested size", {"actual": root.size, "expected": expected_size})
	settings_manager.set_language(locale)
	_check(settings_manager.get_language() == locale, "requested locale is available", {"locale": locale, "actual": settings_manager.get_language()})
	await _stable()

	var result := change_scene_to_file("res://scenes/mianMenu.tscn")
	_check(result == OK, "main menu loads", {"error": result})
	if result != OK:
		_finish()
		return
	await scene_changed
	await _stable()
	var menu := current_scene
	var start_button := menu.get_node_or_null("UI/Button_start") as Button
	_check(start_button != null, "main menu keeps UI/Button_start")
	_assert_controls(_visible_controls(menu), "main-menu")
	await _capture("main-menu")

	var settings_button := menu.get_node_or_null("UI/Button_setting") as Button
	_check(settings_button != null, "main menu settings button exists")
	if settings_button != null:
		settings_button.pressed.emit()
		await _stable()
		var settings: Node = settings_manager.get_children().back() if not settings_manager.get_children().is_empty() else null
		_check(settings != null and settings.name == "SettingsPanel", "settings modal opens")
		_assert_controls(_visible_controls(settings), "settings")
		await _capture("settings")
		settings_manager.close_settings()
		await _stable()

	if start_button != null:
		start_button.pressed.emit()
		await scene_changed
		await _wait_for_dialogue()
		var previous_event := dialogic.current_event_idx
		var previous_text := (get_first_node_in_group("dialogic_dialog_text") as RichTextLabel).get_parsed_text()
		_send_dialogic_action()
		for index in 120:
			if dialogic.current_event_idx != previous_event:
				break
			await process_frame
		_check(dialogic.current_event_idx != previous_event, "dialogue advances beyond location caption")
		await _wait_for_dialogue(previous_text)
		var hud := current_scene.get_node_or_null("HUD")
		var hud_values := hud.get_node_or_null("%Values") as Control if hud != null else null
		_check(hud_values != null, "HUD keeps %Values container")
		var hud_settings := hud.get_node_or_null("%SettingsButton") as Button if hud != null else null
		var hud_lore := hud.get_node_or_null("%LoreButton") as Button if hud != null else null
		_check(hud_settings != null and hud_settings.is_visible_in_tree(), "HUD settings tool is visible")
		_check(hud_lore != null and hud_lore.is_visible_in_tree(), "HUD lore tool is visible")
		_assert_controls(_visible_controls(hud), "dialogue-hud")
		await _capture("dialogue-hud")
		if hud_lore != null:
			hud_lore.pressed.emit()
			await _stable()
			var lore := current_scene.get_node_or_null("LoreBrowser")
			_check(lore != null, "HUD lore tool opens lore modal")
			_assert_controls(_visible_controls(lore), "lore")
			await _capture("lore")
			if lore != null:
				lore.queue_free()
				await _stable()
		var saved: bool = save_manager.save("1", "UI Visual QA")
		_check(saved, "isolated story save is created", {"error": save_manager.last_error})
		_open_save_load()
		await _stable()
		var save_panel := current_scene.get_node_or_null("SaveSlotPanel")
		_check(save_panel != null, "load-mode save modal opens")
		if save_panel != null:
			_check(bool(save_panel.load_mode), "save modal uses load_mode")
			var save_1 := save_panel.get_node_or_null("%Save1") as Button
			_check(save_1 != null and not save_1.text.is_empty(), "load modal renders existing save")
		_assert_controls(_visible_controls(save_panel), "save-load")
		await _capture("save-load")
		if save_panel != null:
			save_panel.queue_free()
			await _stable()

		print("UI QA: opening history")
		var history := current_scene.get_node_or_null("HistoryPanel")
		_check(history != null, "history panel exists")
		if history != null:
			await _wait_for_history_record(history)
			_check(history.history_button.size == Vector2(44.0, 44.0), "history title button is 44px", {"actual": history.history_button.size})
			history.history_button.pressed.emit()
			await _stable()
			_check(history.list_box.get_child_count() > 0, "history contains a real dialogue record")
			_assert_controls(_visible_controls(history.overlay), "history")
			await _capture("history")
			history.close_button.pressed.emit()
			await _stable()
		await _capture_crossroads_choices(hud)
	_finish()


func _open_save_load() -> void:
	var packed := load("res://scenes/save_slot_panel.tscn") as PackedScene
	_check(packed != null, "save panel scene loads")
	if packed == null:
		return
	var panel = packed.instantiate()
	panel.load_mode = true
	current_scene.add_child(panel)


func _wait_for_dialogue(previous_text := "") -> void:
	for index in 240:
		var text := get_first_node_in_group("dialogic_dialog_text") as DialogicNode_DialogText
		if text != null and not text.get_parsed_text().is_empty() and text.get_parsed_text() != previous_text and text.is_visible_in_tree():
			# Event indices advance before textbox transitions finish updating the text.
			if dialogic.current_state == DialogicGameHandler.States.REVEALING_TEXT:
				dialogic.Text.skip_text_reveal()
			await _stable()
			if not text.revealing and text.visible_ratio == 1.0:
				_check(true, "dialogue text is fully revealed")
				return
		await process_frame
	_check(false, "real Dialogic dialogue did not finish revealing", {"state": dialogic.current_state, "event": dialogic.current_event_idx})


func _capture_crossroads_choices(hud: Node) -> void:
	# Normal menu and story entry ran above; exercise the largest real choice set.
	dialogic.start_timeline("res://timelines/03_crossroads.dtl")
	for index in 120:
		if dialogic.current_state == DialogicGameHandler.States.AWAITING_CHOICE:
			break
		_send_dialogic_action()
		await create_timer(0.13).timeout
	_check(dialogic.current_state == DialogicGameHandler.States.AWAITING_CHOICE, "crossroads reaches real choices")
	await _stable()
	var buttons: Array[Control] = []
	var hud_rect := (hud.get_node("Panel") as Control).get_global_rect()
	var dialogue_text := get_first_node_in_group("dialogic_dialog_text") as Control
	var textbox_rect := (dialogue_text.get_parent() as Control).get_global_rect()
	var group_rect := Rect2()
	var viewport_center := root.get_visible_rect().get_center()
	for index in range(1, 5):
		var button := dialogic.Choices.get_choice_button(index) as Button
		_check(button != null and button.is_visible_in_tree(), "crossroads choice is visible", {"index": index})
		if button != null:
			buttons.append(button)
			var rect := button.get_global_rect()
			group_rect = rect if buttons.size() == 1 else group_rect.merge(rect)
			_check(absf(rect.get_center().x - viewport_center.x) <= 0.5, "choice is horizontally centered", {"index": index, "rect": rect, "center": viewport_center})
			_check(not button.get_global_rect().intersects(hud_rect), "choice clears HUD", {"index": index})
			_check(not button.get_global_rect().intersects(textbox_rect), "choice clears textbox", {"index": index})
	_check(absf(group_rect.get_center().y - viewport_center.y) <= 0.5, "choice group is vertically centered", {"rect": group_rect, "center": viewport_center})
	_assert_controls(buttons, "choices")
	await _capture("choices")


func _send_dialogic_action() -> void:
	var down := InputEventAction.new()
	down.action = &"dialogic_default_action"
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = &"dialogic_default_action"
	up.pressed = false
	Input.parse_input_event(up)


func _wait_for_history_record(history: Node) -> void:
	for index in 12:
		print("UI QA: history wait ", index, ", records=", history.list_box.get_child_count(), ", state=", dialogic.current_state)
		if history.list_box.get_child_count() > 0:
			return
		_send_dialogic_action()
		await _stable()
	_check(false, "real Dialogic dialogue did not produce a history record")


func _visible_controls(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	if node == null:
		return result
	if node is Control and node.is_visible_in_tree():
		result.append(node)
	for child in node.find_children("*", "Control", true, false):
		if child.is_visible_in_tree() and not _is_scroll_content(child):
			result.append(child)
	return result


func _is_scroll_content(control: Control) -> bool:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false


func _assert_controls(controls: Array, label: String) -> void:
	_check(not controls.is_empty(), label + " has visible core controls")
	# canvas_items uses logical coordinates, while Window.size is physical pixels.
	var viewport := root.get_visible_rect()
	for control: Control in controls:
		if control == null:
			continue
		var rect := control.get_global_rect()
		_check(rect.size.x > 0.0 and rect.size.y > 0.0, label + " control has positive rectangle", {"node": control.get_path(), "rect": rect})
		_check(viewport.encloses(rect), label + " control stays inside viewport", {"node": control.get_path(), "rect": rect, "viewport": viewport})


func _capture(name: String) -> void:
	print("UI QA: rendering ", name)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var logical_size := root.get_visible_rect().size
	var scale_factor := minf(expected_size.x / logical_size.x, expected_size.y / logical_size.y)
	var content_pixels := Vector2i((logical_size * scale_factor).round())
	_check(image.get_size() == content_pixels, "capture uses letterboxed content size", {"actual": image.get_size(), "expected": content_pixels, "window": expected_size})
	var path := report_dir.path_join(name + ".png")
	var error := image.save_png(path)
	_check(error == OK, "capture " + name, {"path": path, "error": error, "size": image.get_size()})
	if error == OK:
		captures.append(path)
		print("UI QA: captured ", name)


func _stable() -> void:
	for index in 12:
		await process_frame
	await create_timer(0.2).timeout
	for index in 4:
		await process_frame


func _check(condition: bool, name: String, detail := {}) -> void:
	checks.append({"name": name, "passed": condition, "detail": detail})
	if not condition:
		failures.append(name)
		push_error("UI visual QA failed: " + name + " " + JSON.stringify(detail))


func _finish() -> void:
	_check(captures.size() == CAPTURE_NAMES.size(), "all UI screenshots are captured", {"actual": captures.size(), "expected": CAPTURE_NAMES.size()})
	await dialogic.end_timeline(true)
	await dialogic.clear(DialogicGameHandler.ClearFlags.FULL_CLEAR)
	if dialogic.has_subsystem("Audio"):
		dialogic.Audio.stop_all_one_shot_sounds()
		dialogic.Audio.stop_all_channels(0.0)
	if current_scene != null:
		current_scene.queue_free()
	# Dialogic layouts and spatial audio release playback references on physics ticks.
	for index in 8:
		await physics_frame
	for index in 4:
		await process_frame
	var summary := {"status": "passed" if failures.is_empty() else "failed", "locale": locale, "viewport": root.size, "captures": captures, "checks": checks, "failures": failures}
	var file := FileAccess.open(report_dir.path_join("summary.json"), FileAccess.WRITE)
	if file == null:
		push_error("UI visual QA could not write summary")
		quit(2)
		return
	file.store_string(JSON.stringify(summary, "\t"))
	file.close()
	# Canvas layers can outlive current_scene during normal scene teardown.
	for child in root.get_children():
		if is_instance_valid(child):
			child.queue_free()
	for index in 8:
		await physics_frame
	quit(0 if failures.is_empty() else 1)
