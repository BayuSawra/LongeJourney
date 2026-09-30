extends Node

## Centralized visual helpers used across the game UI.
## Keeps transition animations in one place.

var _choice_buttons := {}
var _chosen_button: Button = null
var _choice_scan_tick := 0.0

const CHOICE_SCAN_INTERVAL := 0.08
const CHOICE_HIGHLIGHT_MODULATE := Color(1.08, 1.08, 1.08)


func _ready() -> void:
	call_deferred("_fade_in_existing_hud")


func _process(delta: float) -> void:
	_choice_scan_tick += delta
	if _choice_scan_tick >= CHOICE_SCAN_INTERVAL:
		_choice_scan_tick = 0.0
		_scan_for_choice_buttons()


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
	# Choice nodes are recreated by Dialogic. Remove freed entries first, then
	# use the instance id as the connection guard. A bound Callable is distinct
	# from the unbound method Callable, so is_connected() cannot detect the
	# connection created below.
	for instance_id in _choice_buttons.keys():
		var registered: Variant = _choice_buttons[instance_id]
		if not is_instance_valid(registered):
			_choice_buttons.erase(instance_id)
	var candidates: Array[Node] = []
	candidates.append_array(get_tree().get_nodes_in_group("dialogic_choice"))
	candidates.append_array(get_tree().get_nodes_in_group("dialogic_choice_button"))
	for node in get_tree().root.find_children("*", "Button", true, false):
		if node is Button and ("choice" in node.name.to_lower() or "choice" in str(node.get_path()).to_lower()):
			candidates.append(node)
	for candidate in candidates:
		if candidate is Button and not _choice_buttons.has(candidate.get_instance_id()):
			_register_choice_button(candidate)


func _register_choice_button(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		return
	var instance_id := button.get_instance_id()
	if _choice_buttons.has(instance_id):
		return
	_choice_buttons[instance_id] = button
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


func _apply_choice_state(button: Button, active: bool) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.scale = Vector2(1.04, 1.04) if active else Vector2.ONE
	button.modulate = CHOICE_HIGHLIGHT_MODULATE if active else Color.WHITE


func _clear_previous_choice() -> void:
	if _chosen_button != null and is_instance_valid(_chosen_button):
		_apply_choice_state(_chosen_button, false)
	_chosen_button = null
