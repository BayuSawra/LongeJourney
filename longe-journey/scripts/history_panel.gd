extends CanvasLayer

const MAX_ENTRIES := 200
const MAX_TEXT_LEN := 42

@onready var overlay: ColorRect = $Overlay
@onready var history_button: Button = $HistoryButton
@onready var close_button: Button = $Overlay/Panel/Main/Header/CloseButton
@onready var list_box: VBoxContainer = $Overlay/Panel/Main/Scroll/List

var _entries: Array = []


func _ready() -> void:
	history_button.pressed.connect(_open)
	close_button.pressed.connect(_close)
	Dialogic.event_handled.connect(_on_dialogic_event_handled)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		overlay.visible = not overlay.visible


func _open() -> void:
	overlay.visible = true


func _close() -> void:
	overlay.visible = false


func _on_dialogic_event_handled(resource: DialogicEvent) -> void:
	if Dialogic.current_timeline == null:
		return

	if resource.event_name != "Text" and resource.event_name != "Choice":
		return

	var text_value = resource.get("text")
	var character_value = resource.get("character")
	var record := {
		"timeline": Dialogic.current_timeline.resource_path,
		"event_idx": Dialogic.current_event_idx,
		"type": resource.event_name,
		"text": "" if text_value == null else str(text_value),
		"character": "" if character_value == null else str(character_value),
	}

	var existing_index := -1
	for i in range(_entries.size()):
		if _entries[i].timeline == record.timeline and _entries[i].event_idx == record.event_idx:
			existing_index = i
			break

	if existing_index >= 0:
		_entries.resize(existing_index + 1)
	else:
		_entries.append(record)
		if _entries.size() > MAX_ENTRIES:
			_entries.pop_front()

	_rebuild_list()


func _rebuild_list() -> void:
	for child in list_box.get_children():
		child.queue_free()

	for i in range(_entries.size()):
		var button := Button.new()
		button.text = _format_entry(_entries[i])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_entry_pressed.bind(i))
		list_box.add_child(button)


func _format_entry(entry: Dictionary) -> String:
	var prefix := ""
	if entry.type == "Choice":
		prefix = "[选项] "
	elif not str(entry.character).is_empty():
		prefix = str(entry.character) + "："

	var text := str(entry.text).strip_edges().replace("\n", " ")
	if text.length() > MAX_TEXT_LEN:
		text = text.substr(0, MAX_TEXT_LEN) + "…"
	return prefix + text


func _on_entry_pressed(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return

	_close()
	Dialogic.Text.skip_text_reveal()
	Dialogic.start_timeline(_entries[index].timeline, _entries[index].event_idx + 1)
