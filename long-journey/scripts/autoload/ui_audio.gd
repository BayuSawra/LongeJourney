extends Node

## Plays one UI click for ordinary game controls. Dialogic choice buttons own their
## press sound through DialogicChoiceLayer, so they are intentionally excluded.

const CLICK_SOUND_PATH := "res://audio/sfx/01_ui_click/ui_button_click.mp3"
const UI_BUS := &"UI"
const SCAN_INTERVAL := 0.15

var _click_player: AudioStreamPlayer
var _bound_buttons := {}
var _scan_elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_click_player = AudioStreamPlayer.new()
	_click_player.name = "UiClickPlayer"
	var click_sound: AudioStream = load(CLICK_SOUND_PATH) as AudioStream
	if click_sound == null:
		push_error("UI click sound is unavailable: %s" % CLICK_SOUND_PATH)
	else:
		_click_player.stream = click_sound
	_click_player.bus = UI_BUS
	add_child(_click_player)
	get_tree().node_added.connect(_on_tree_node_added)
	call_deferred("scan_buttons")


func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)


func _process(delta: float) -> void:
	_scan_elapsed += delta
	if _scan_elapsed >= SCAN_INTERVAL:
		_scan_elapsed = 0.0
		scan_buttons()


## Public for UI creation flows and regression tests. The instance-id registry
## keeps repeated panel openings and periodic scans from adding duplicate slots.
func scan_buttons() -> void:
	_prune_invalid_buttons()
	if get_tree() == null:
		return
	for candidate in get_tree().root.find_children("*", "BaseButton", true, false):
		if candidate is BaseButton:
			_register_button(candidate)


func is_button_bound(button: BaseButton) -> bool:
	return button != null and _bound_buttons.has(button.get_instance_id())


func get_click_player() -> AudioStreamPlayer:
	return _click_player


func _on_tree_node_added(node: Node) -> void:
	if node is BaseButton:
		call_deferred("_register_button_by_instance_id", node.get_instance_id())


func _register_button_by_instance_id(instance_id: int) -> void:
	var candidate := instance_from_id(instance_id)
	if candidate is BaseButton:
		_register_button(candidate as BaseButton)


func _register_button(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return
	if _is_dialogic_choice_button(button):
		return
	var instance_id := button.get_instance_id()
	if _bound_buttons.has(instance_id):
		return
	_bound_buttons[instance_id] = button
	button.pressed.connect(_on_ui_button_pressed)


func _is_dialogic_choice_button(button: BaseButton) -> bool:
	if button.is_in_group("dialogic_choice_button"):
		return true
	if button is DialogicNode_ChoiceButton:
		return true
	return false


func _on_ui_button_pressed() -> void:
	if _click_player == null or _click_player.stream == null:
		return
	_click_player.stop()
	_click_player.play()


func _prune_invalid_buttons() -> void:
	for instance_id in _bound_buttons.keys():
		var button: Variant = _bound_buttons[instance_id]
		if not is_instance_valid(button):
			_bound_buttons.erase(instance_id)
