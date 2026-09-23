extends SceneTree

## Graphical Phase 6 acceptance driver. Runs in a disposable project copy.
const DOOR_BACKGROUND := "res://art/backgrounds/hospital_ward_door_505.png"
const WIFE_BACKGROUND := "res://art/backgrounds/wife_room_curtained.png"
const SIGN_KEY := "ui.ward_door_locator.text"

var report_dir := ""
var expected_size := Vector2i.ZERO
var failures: Array[String] = []
var checks: Array[Dictionary] = []
var background_events: Array[Dictionary] = []
var dialogic: DialogicGameHandler
var visual_fx: Node
var game_state: Node
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
	if report_dir.is_empty() or expected_size.x <= 0 or expected_size.y <= 0:
		push_error("Phase 6 QA requires --qa-report, --qa-width, and --qa-height")
		quit(2)

func _run() -> void:
	dialogic = root.get_node("Dialogic") as DialogicGameHandler
	visual_fx = root.get_node("VisualFX")
	game_state = root.get_node("GameState")
	save_manager = root.get_node("SaveManager")
	DirAccess.make_dir_recursive_absolute(report_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(expected_size)
	await _frames(8)
	_check(root.size == expected_size, "window viewport uses requested size", {"actual": root.size, "expected": expected_size})
	dialogic.Backgrounds.background_changed.connect(_on_background_changed)

	var result := change_scene_to_file("res://scenes/mianMenu.tscn")
	_check(result == OK, "main menu loads", {"error": result})
	await scene_changed
	await _frames(4)
	var menu := current_scene
	_check(menu != null and menu.scene_file_path == "res://scenes/mianMenu.tscn", "normal main-menu entry")
	var start_button := menu.get_node_or_null("UI/Button_start") as Button
	_check(start_button != null, "existing start button is available")
	if start_button == null:
		_finish()
		return
	start_button.pressed.emit()
	await scene_changed
	await _frames(8)
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/scene_1.tscn", "start button enters scene_1")
	_check(dialogic.current_timeline != null and dialogic.current_timeline.resource_path.ends_with("00_start.dtl"), "scene_1 begins 00_start")

	visual_fx.set_text_speed(10000.0)
	await _advance_to_choice("00_start")
	await _select_existing_choice(1, "00_start to 01_hospital")
	_check(dialogic.current_timeline != null and dialogic.current_timeline.resource_path.ends_with("01_hospital.dtl"), "first story jump reaches 01_hospital")

	# Runtime fixture: the normal menu and timeline route has already run. The
	# flower collection route is covered by content tests and is not the P0 target.
	game_state.set_var("flower", 5)
	await _advance_to_choice("01_hospital")
	await _select_existing_choice(1, "01_hospital to 02_ward")
	_check(dialogic.current_timeline != null and dialogic.current_timeline.resource_path.ends_with("02_ward.dtl"), "hospital choice reaches 02_ward")
	await _advance_to_choice("02_ward")
	await _select_existing_choice(1, "02_ward to door")
	await _wait_for_background(DOOR_BACKGROUND, "door background appears")
	await _frames(6)
	_assert_door("initial")
	_capture("door-initial")

	var saved: bool = save_manager.save("phase6qa", "Phase 6 visual QA")
	_check(saved, "SaveManager creates isolated door save", {"error": save_manager.last_error})
	_check(save_manager.has_save("phase6qa"), "isolated door save exists")

	# Four rapid actions cross the leave choice and must reach the wife-room background.
	for index in 4:
		_send_dialogic_action()
		await _frames(2)
	await _wait_for_background(WIFE_BACKGROUND, "rapid leave reaches wife-room background")
	await _frames(8)
	_check(dialogic.Backgrounds.argument == WIFE_BACKGROUND, "rapid leave changes to wife-room background")
	var sign_after_leave := _sign_label()
	_check(sign_after_leave != null and not sign_after_leave.visible, "rapid leave hides sign")
	_capture("door-after-rapid-leave")

	var loaded: bool = await save_manager.load("phase6qa")
	_check(loaded, "SaveManager restores door save", {"error": save_manager.last_error})
	await _wait_for_background(DOOR_BACKGROUND, "door appears after load")
	await _frames(8)
	_assert_door("after-load")
	_capture("door-after-load")

	await _leave_door("second-leave")
	loaded = await save_manager.load("phase6qa")
	_check(loaded, "SaveManager restores repeated door entry", {"error": save_manager.last_error})
	await _wait_for_background(DOOR_BACKGROUND, "door appears after repeated load")
	await _frames(8)
	_assert_door("repeat-entry")
	_capture("door-repeat-entry")
	_check(_saw_background(DOOR_BACKGROUND, 0.6), "door background transition records 0.6-second fade")
	_check(_saw_background(WIFE_BACKGROUND, 0.6), "leaving door records 0.6-second fade")
	_finish()

func _advance_to_choice(label: String) -> void:
	for index in 180:
		if dialogic.current_state == 3:
			_check(true, label + " reaches a choice")
			return
		_send_dialogic_action()
		await create_timer(0.13).timeout
	_check(false, label + " did not reach a choice before timeout", {"state": dialogic.current_state, "event": dialogic.current_event_idx})

func _select_existing_choice(index: int, label: String) -> void:
	await create_timer(0.28).timeout
	var button: BaseButton = dialogic.Choices.get_choice_button(index) as BaseButton
	_check(button != null and button.visible, label + " exposes an existing Dialogic choice button")
	if button == null:
		return
	dialogic.Choices.select_choice(index)
	await _frames(6)

func _leave_door(label: String) -> void:
	for index in 30:
		if dialogic.Backgrounds.argument == WIFE_BACKGROUND:
			break
		_send_dialogic_action()
		await create_timer(0.13).timeout
	await _wait_for_background(WIFE_BACKGROUND, label + " reaches wife-room background")
	await _frames(8)
	var sign := _sign_label()
	_check(sign != null and not sign.visible, label + " hides sign after leaving door")
	_capture(label + "-wife-room")

func _wait_for_background(path: String, label: String) -> void:
	for index in 120:
		if dialogic.Backgrounds.argument == path:
			_check(true, label)
			# Backgrounds emit their argument at transition start; wait for the
			# 0.6-second fade to finish before inspecting the rendered scene.
			await _frames(45)
			return
		await create_timer(0.05).timeout
	_check(false, label + " timed out", {"current": dialogic.Backgrounds.argument})

func _assert_door(stage: String) -> void:
	var sign := _sign_label()
	_check(sign != null, stage + " sign label exists")
	if sign == null:
		return
	_check(sign.visible, stage + " sign is visible")
	_check(sign.text == SIGN_KEY, stage + " sign keeps localization key", {"text": sign.text})
	_check(TranslationServer.translate(SIGN_KEY) == "7F / 5-05", stage + " sign translates to required room text", {"translated": TranslationServer.translate(SIGN_KEY)})
	# The non-wide window is letterboxed by the project's 16:9 canvas stretch;
	# map against the actual rendered viewport that owns the attached label.
	var viewport: Vector2 = sign.get_viewport().get_visible_rect().size
	var rect := sign.get_global_rect()
	var viewport_rect := Rect2(Vector2.ZERO, viewport)
	var controller := current_scene.get_node_or_null("WardDoorSign")
	var expected_rect: Rect2 = controller._plaque_rect(viewport) if controller != null else Rect2()
	_check(controller != null, stage + " has a plaque mapping controller")
	_check(rect.position.distance_to(expected_rect.position) <= 2.0 and rect.size.distance_to(expected_rect.size) <= 2.0,
		stage + " sign follows the source-image COVER plaque mapping", {"actual": rect, "expected": expected_rect})
	_check(viewport_rect.encloses(rect), stage + " sign rectangle remains inside viewport", {"rect": rect, "viewport": viewport_rect})
	var font_color := sign.get_theme_color("font_color")
	_check(font_color.a >= 0.8, stage + " sign color is opaque enough to read", {"actual": font_color})
	_check(sign.get_theme_constant("outline_size") >= 2, stage + " sign keeps a readable outline")

func _sign_label() -> Label:
	if current_scene == null:
		return null
	# The runtime implementation attaches the rendered label to Dialogic's
	# background node so it scales with the artwork. Fall back to the scene
	# label for implementations that render directly from scene_1.tscn.
	var attached := root.find_child("AttachedDoorSign", true, false) as Label
	if attached != null:
		return attached
	return current_scene.get_node_or_null("WardDoorSign/Sign") as Label

func _send_dialogic_action() -> void:
	var down := InputEventAction.new()
	down.action = &"dialogic_default_action"
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = &"dialogic_default_action"
	up.pressed = false
	Input.parse_input_event(up)

func _on_background_changed(info: Dictionary) -> void:
	background_events.append({"current_argument": dialogic.Backgrounds.argument, "fade_time": float(info.get("fade_time", -1.0)), "same_scene": bool(info.get("same_scene", false))})

func _saw_background(path: String, fade_time: float) -> bool:
	for event in background_events:
		if event.current_argument == path and is_equal_approx(float(event.fade_time), fade_time):
			return true
	return false

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := report_dir.path_join(name + ".png")
	var error := image.save_png(path)
	_check(error == OK, "capture " + name, {"path": path, "error": error, "size": image.get_size()})

func _frames(count: int) -> void:
	for index in count:
		await process_frame

func _check(condition: bool, name: String, detail := {}) -> void:
	checks.append({"name": name, "passed": condition, "detail": detail})
	if not condition:
		failures.append(name)
		push_error("Phase 6 visual QA failed: " + name + " " + JSON.stringify(detail))

func _finish() -> void:
	await dialogic.end_timeline(true)
	await dialogic.clear(DialogicGameHandler.ClearFlags.FULL_CLEAR)
	if dialogic.has_subsystem("Audio"):
		dialogic.Audio.stop_all_one_shot_sounds()
		dialogic.Audio.stop_all_channels(0.0)
	if current_scene != null:
		current_scene.queue_free()
	# Dialogic layouts, background viewports and spatial audio release on
	# physics ticks; mirror the project's smoke-test shutdown contract.
	for index in 8:
		await physics_frame
	for index in 4:
		await process_frame
	var summary := {"status": "passed" if failures.is_empty() else "failed", "viewport": root.size, "checks": checks, "failures": failures, "background_events": background_events}
	var file := FileAccess.open(report_dir.path_join("summary.json"), FileAccess.WRITE)
	if file == null:
		push_error("Phase 6 visual QA could not write summary")
		quit(2)
		return
	file.store_string(JSON.stringify(summary, "\t"))
	file.close()
	# This is an isolated acceptance process. Free every autoload and scene
	# child before quitting so Godot's leak detector sees the same orderly
	# teardown as the project's verification smoke test.
	for child in root.get_children():
		if is_instance_valid(child):
			child.queue_free()
	for index in 8:
		await physics_frame
	quit(0 if failures.is_empty() else 1)
