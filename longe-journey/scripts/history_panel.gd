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
	Dialogic.Choices.choice_selected.connect(_choice_selected)
	Dialogic.History.open_requested.connect(_open)
	Dialogic.History.close_requested.connect(_close)
	Localization.locale_changed.connect(_rebuild_list)


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

	if resource.event_name != "Text":
		return

	_append_record(Localization.record_event(resource))


func _choice_selected(info: Dictionary) -> void:
	var record := Localization.record_event(Dialogic.current_timeline_events[info["event_index"]])
	record["event_idx"] = info["event_index"]
	_append_record(record)


func _append_record(record: Dictionary) -> void:

	var existing_index := -1
	for i in range(_entries.size()):
		if _entries[i].timeline == record.timeline and _entries[i].event_idx == record.event_idx:
			existing_index = i
			break

	if existing_index >= 0:
		_entries.resize(existing_index + 1)
		_entries[existing_index] = record
	else:
		_entries.append(record)
		if _entries.size() > MAX_ENTRIES:
			_entries.pop_front()

	_rebuild_list()


func _rebuild_list() -> void:
	for child in list_box.get_children():
		list_box.remove_child(child)
		child.queue_free()

	for i in range(_entries.size()):
		var button := Button.new()
		button.text = _format_entry(_entries[i])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 44)
		button.theme_type_variation = &"SlotButton"
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = button.text
		button.pressed.connect(_on_entry_pressed.bind(i))
		list_box.add_child(button)


func _format_entry(entry: Dictionary) -> String:
	var value := Localization.render_record(entry).strip_edges().replace("\n", " ")
	var markup := RichTextLabel.new()
	markup.bbcode_enabled = true
	markup.text = value
	value = markup.get_parsed_text()
	markup.free()
	if value.length() > MAX_TEXT_LEN:
		value = value.substr(0, MAX_TEXT_LEN) + "…"
	if entry.type == "Choice":
		return Localization.format_text("history.choice", {"text": value})
	if not str(entry.character).is_empty():
		var character := load(entry.character) as DialogicCharacter
		return Localization.format_text("history.speaker", {"text": value, "name": character.get_display_name_translated()})
	return value


func _on_entry_pressed(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return

	_close()
	Dialogic.Text.skip_text_reveal()
	Dialogic.start_timeline(_entries[index].timeline, _entries[index].event_idx + 1)
