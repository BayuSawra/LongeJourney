extends Node

## Centralized visual and text timing helpers used across the game UI.
## Keeps dialog speed, typewriter skipping and transition animations in one place.

## Characters typed per second for dialog text. Applied to Dialogic when possible.
@export var characters_per_second: float = 42.0

var _dialogic_text: Node = null
var _choice_buttons := {}
var _chosen_button: Button = null
var _custom_typer_target: Label = null
var _custom_typer_text := ""
var _custom_typer_index := 0
var _choice_scan_tick := 0.0
var _process_speed_scan := false

const CHOICE_SCAN_INTERVAL := 0.08


func _ready() -> void:
	_process_speed_scan = true
	call_deferred("_apply_dialog_text_speed")
	call_deferred("_fade_in_existing_hud")


func _process(delta: float) -> void:
	if _process_speed_scan:
		_apply_dialog_text_speed()

	_choice_scan_tick += delta
	if _choice_scan_tick >= CHOICE_SCAN_INTERVAL:
		_choice_scan_tick = 0.0
		_scan_for_choice_buttons()


func _exit_tree() -> void:
	if _custom_typer_timer != null and is_instance_valid(_custom_typer_timer):
		_custom_typer_timer.stop()
		_custom_typer_timer.queue_free()
		_custom_typer_timer = null


var _custom_typer_timer: Timer = null


## Sets the global dialog typing speed. When Dialogic is available this is
## forwarded to Dialogic.Text.speed; the value is also stored for custom labels.
func set_text_speed(cps: float) -> void:
	characters_per_second = maxf(1.0, cps)
	_apply_dialog_text_speed()


func get_text_speed() -> float:
	return characters_per_second


## Instantly reveals all currently typing text. Safe to call when no typing is
## happening; Dialogic and custom typewriters are both handled when present.
func skip_typing() -> void:
	if _dialogic_text != null and is_instance_valid(_dialogic_text):
		if _dialogic_text.has_method("skip_typing"):
			_dialogic_text.skip_typing()
	if _custom_typer_timer != null and is_instance_valid(_custom_typer_timer):
		_skip_custom_typer()


## Types text into a plain Label progressively. `on_complete` is called when the
## full text is visible. The active typing can be ended by skip_typing().
func type_on(label: Label, full_text: String, cps := -1.0) -> void:
	if label == null:
		return
	var speed := characters_per_second if cps <= 0.0 else cps
	_custom_typer_target = label
	_custom_typer_text = full_text
	_custom_typer_index = 0
	label.text = ""
	if _custom_typer_timer != null and is_instance_valid(_custom_typer_timer):
		_custom_typer_timer.stop()
	else:
		_custom_typer_timer = Timer.new()
		add_child(_custom_typer_timer)
		_custom_typer_timer.timeout.connect(_on_custom_typer_step)
	_custom_typer_timer.wait_time = 1.0 / speed
	_custom_typer_timer.start()


func skip_to_end(label: Label) -> void:
	if _custom_typer_target == label:
		_skip_custom_typer()


func _on_custom_typer_step() -> void:
	if _custom_typer_target == null or not is_instance_valid(_custom_typer_target):
		return
	_custom_typer_index = mini(_custom_typer_index + 1, _custom_typer_text.length())
	_custom_typer_target.text = _custom_typer_text.substr(0, _custom_typer_index)
	if _custom_typer_index >= _custom_typer_text.length():
		_skip_custom_typer()


func _skip_custom_typer() -> void:
	if _custom_typer_timer != null and is_instance_valid(_custom_typer_timer):
		_custom_typer_timer.stop()
	if _custom_typer_target != null and is_instance_valid(_custom_typer_target):
		_custom_typer_target.text = _custom_typer_text
	_custom_typer_index = _custom_typer_text.length()


func _apply_dialog_text_speed() -> void:
	if _dialogic_text == null or not is_instance_valid(_dialogic_text):
		var text_node: Node = get_node_or_null("/root/Dialogic/Text")
		if text_node != null:
			_dialogic_text = text_node
		else:
			return
	if _dialogic_text.has_method("set_speed"):
		_dialogic_text.set_speed(characters_per_second)
	elif "speed" in _dialogic_text:
		_dialogic_text.speed = characters_per_second
	_process_speed_scan = false


## Fades a Node2D/Control or CanvasLayer child in. Works for HUD panels,
## dialog boxes, portraits and scene layers without changing their original
## modulate values after the transition finishes.
func fade_in(node: Node, duration := 0.35) -> void:
	_fade(node, true, duration)


func fade_out(node: Node, duration := 0.35) -> void:
	_fade(node, false, duration)


func _fade(node: Node, fade_in_value: bool, duration: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	var targets := []
	if node is CanvasLayer:
		for child in node.get_children():
			if child is CanvasItem:
				targets.append(child)
	elif node is CanvasItem:
		targets.append(node)
	for target in targets:
		_fade_canvas_item(target, fade_in_value, duration)


func _fade_canvas_item(item: CanvasItem, fade_in_value: bool, duration: float) -> void:
	var target_alpha := 1.0 if fade_in_value else 0.0
	var tween := item.create_tween()
	tween.set_parallel(false)
	tween.tween_property(item, "modulate:a", target_alpha, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	if fade_in_value:
		tween.chain().tween_callback(func() -> void: item.modulate.a = 1.0)


func _fade_in_existing_hud() -> void:
	var hud: Node = _find_hud_node()
	if hud != null:
		fade_in(hud, 0.45)


func _find_hud_node() -> Node:
	for node in get_tree().get_nodes_in_group("hud"):
		if node != null:
			return node
	for node in get_tree().get_nodes_in_group("HUD"):
		if node != null:
			return node
	for candidate in get_tree().get_nodes_in_group("hud_panel"):
		if candidate != null:
			return candidate
	return null


func _scan_for_choice_buttons() -> void:
	if get_tree() == null:
		return
	var candidates: Array[Node] = []
	candidates.append_array(get_tree().get_nodes_in_group("dialogic_choice"))
	candidates.append_array(get_tree().get_nodes_in_group("dialogic_choice_button"))
	for node in get_tree().root.find_children("*", "Button", true, false):
		if node is Button and ("choice" in node.name.to_lower() or "choice" in str(node.get_path()).to_lower()):
			candidates.append(node)
	for candidate in candidates:
		if candidate is Button and not candidate.is_connected("pressed", _on_choice_pressed):
			_register_choice_button(candidate)


func _register_choice_button(button: Button) -> void:
	_choice_buttons[button.get_instance_id()] = button
	button.pressed.connect(_on_choice_pressed.bind(button))
	button.mouse_entered.connect(_on_choice_hover.bind(button, true))
	button.mouse_exited.connect(_on_choice_hover.bind(button, false))
	button.focus_entered.connect(_on_choice_focus.bind(button, true))
	button.focus_exited.connect(_on_choice_focus.bind(button, false))
	_animate_choice_appear(button)


func _animate_choice_appear(button: Button) -> void:
	if button.get_pivot_offset() == Vector2.ZERO:
		button.set_pivot_offset(button.size / 2.0)
	button.modulate.a = 0.0
	var appear_tween := button.create_tween()
	appear_tween.set_parallel(true)
	appear_tween.tween_property(button, "modulate:a", 1.0, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	appear_tween.tween_property(button, "scale", Vector2.ONE, 0.22).from(Vector2(0.94, 0.94)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_choice_pressed(button: Button) -> void:
	_clear_previous_choice()
	_chosen_button = button
	_apply_choice_state(button, true)


func _on_choice_hover(button: Button, hovering: bool) -> void:
	if hovering and button != _chosen_button:
		_apply_choice_state(button, true)
	elif not hovering and button != _chosen_button:
		_apply_choice_state(button, false)


func _on_choice_focus(button: Button, focused: bool) -> void:
	if focused and button != _chosen_button:
		_apply_choice_state(button, true)
	elif not focused and button != _chosen_button:
		_apply_choice_state(button, false)


func _apply_choice_state(button: Button, selected: bool) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.scale = Vector2(1.04, 1.04) if selected else Vector2.ONE
	button.modulate = Color(1.25, 1.18, 0.92) if selected else Color.WHITE


func _clear_previous_choice() -> void:
	if _chosen_button != null and is_instance_valid(_chosen_button):
		_apply_choice_state(_chosen_button, false)
	_chosen_button = null


func set_dialog_text_speed_on_timeline_start() -> void:
	_process_speed_scan = true
	_apply_dialog_text_speed()
