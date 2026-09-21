extends CanvasLayer

## Unified, lightweight feedback for resource changes, endings and autosaves.
## The layer only renders events emitted by business autoloads; it does not
## mutate game state or make save decisions.

const TRACKED_RESOURCES: Array[String] = ["energy", "calm", "money", "flower", "earthworm"]
const RESOURCE_KEYS: Dictionary = {
	"energy": "feedback.energy",
	"calm": "feedback.calm",
	"money": "feedback.money",
	"flower": "feedback.flower",
	"earthworm": "feedback.earthworm",
}
const RESOURCE_FEEDBACK_DELAY := 0.12
const FLOAT_DURATION := 0.9
const NOTICE_DURATION := 2.6
const STATUS_DURATION := 1.4

@onready var _floating_texts: Control = %FloatingTexts
@onready var _notice_panel: PanelContainer = %NoticePanel
@onready var _notice_label: Label = %NoticeLabel
@onready var _status_label: Label = %StatusLabel

var _last_values: Dictionary = {}
var _pending_deltas: Dictionary = {}
var _resource_timer: Timer
var _notice_tween: Tween
var _status_tween: Tween
var _floating_count := 0


func _ready() -> void:
	for variable in TRACKED_RESOURCES:
		_last_values[variable] = GameState.get_var(variable)
	if not GameState.value_changed.is_connected(_on_game_state_changed):
		GameState.value_changed.connect(_on_game_state_changed)
	if not EndingManager.ending_triggered.is_connected(_on_ending_triggered):
		EndingManager.ending_triggered.connect(_on_ending_triggered)
	if not AutoSaveManager.auto_save_completed.is_connected(_on_auto_save_completed):
		AutoSaveManager.auto_save_completed.connect(_on_auto_save_completed)
	_resource_timer = Timer.new()
	_resource_timer.one_shot = true
	_resource_timer.wait_time = RESOURCE_FEEDBACK_DELAY
	_resource_timer.timeout.connect(_flush_resource_feedback)
	add_child(_resource_timer)
	_notice_panel.visible = false
	_status_label.visible = false


func _exit_tree() -> void:
	if GameState.value_changed.is_connected(_on_game_state_changed):
		GameState.value_changed.disconnect(_on_game_state_changed)
	if EndingManager.ending_triggered.is_connected(_on_ending_triggered):
		EndingManager.ending_triggered.disconnect(_on_ending_triggered)
	if AutoSaveManager.auto_save_completed.is_connected(_on_auto_save_completed):
		AutoSaveManager.auto_save_completed.disconnect(_on_auto_save_completed)


func _on_game_state_changed(variable: String, new_value: Variant) -> void:
	var previous: Variant = _last_values.get(variable, new_value)
	_last_values[variable] = new_value
	if variable not in TRACKED_RESOURCES:
		return
	# Loading emits the same signal for every restored variable. Refresh the
	# baseline without presenting a burst of changes to the player.
	if SaveManager._loading:
		return
	if not _is_number(previous) or not _is_number(new_value):
		return
	var delta := float(new_value) - float(previous)
	if is_zero_approx(delta):
		return
	_pending_deltas[variable] = float(_pending_deltas.get(variable, 0.0)) + delta
	_resource_timer.start()


func _flush_resource_feedback() -> void:
	var pending := _pending_deltas.duplicate()
	_pending_deltas.clear()
	for variable in TRACKED_RESOURCES:
		if not pending.has(variable):
			continue
		var delta: float = pending[variable]
		if is_zero_approx(delta):
			continue
		_show_floating_text(variable, delta)


func _show_floating_text(variable: String, delta: float) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("#b9e6ad") if delta > 0.0 else Color("#f0a2a2"))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	var resource_name := Localization.text(RESOURCE_KEYS[variable])
	label.text = "%s %s%s" % [resource_name, "+" if delta > 0.0 else "", _format_number(delta)]
	label.position = Vector2(28.0, 84.0 + _floating_count * 27.0)
	_floating_count += 1
	_floating_texts.add_child(label)
	label.modulate.a = 0.0
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.12)
	tween.tween_property(label, "position:y", label.position.y - 24.0, FLOAT_DURATION).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(func() -> void:
		_floating_count = maxi(0, _floating_count - 1)
		label.queue_free()
	)


func _on_ending_triggered(ending_id: String) -> void:
	var ending_name := Localization.text("ending." + ending_id)
	var message := Localization.format_text("ending.triggered", {"ending": ending_name})
	_show_notice(message, Color("#f3d28b"))


func _on_auto_save_completed(success: bool, error_key: String) -> void:
	if success:
		_show_status(Localization.text("feedback.autosave"), Color("#b9e6ad"))
		return
	var error_text := Localization.text(error_key) if not error_key.is_empty() else Localization.text("save.error_write")
	_show_status(Localization.format_text("feedback.autosave_failed", {"error": error_text}), Color("#f0a2a2"))


func _show_notice(message: String, color: Color) -> void:
	_notice_label.text = message
	_notice_label.add_theme_color_override("font_color", color)
	_notice_panel.visible = true
	_notice_panel.modulate.a = 0.0
	_notice_panel.scale = Vector2(0.94, 0.94)
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	_notice_tween = _notice_panel.create_tween()
	_notice_tween.set_parallel(true)
	_notice_tween.tween_property(_notice_panel, "modulate:a", 1.0, 0.18)
	_notice_tween.tween_property(_notice_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_notice_tween.chain().tween_interval(NOTICE_DURATION)
	_notice_tween.chain().tween_property(_notice_panel, "modulate:a", 0.0, 0.35)
	_notice_tween.chain().tween_callback(func() -> void: _notice_panel.visible = false)


func _show_status(message: String, color: Color) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", color)
	_status_label.visible = true
	_status_label.modulate.a = 0.0
	if _status_tween != null and _status_tween.is_valid():
		_status_tween.kill()
	_status_tween = _status_label.create_tween()
	_status_tween.tween_property(_status_label, "modulate:a", 1.0, 0.16)
	_status_tween.tween_interval(STATUS_DURATION)
	_status_tween.tween_property(_status_label, "modulate:a", 0.0, 0.3)
	_status_tween.tween_callback(func() -> void: _status_label.visible = false)


func _is_number(value: Variant) -> bool:
	return value is int or value is float


func _format_number(value: float) -> String:
	var rounded := snappedf(value, 0.01)
	if is_equal_approx(rounded, roundf(rounded)):
		return str(int(roundf(rounded)))
	return str(rounded)
