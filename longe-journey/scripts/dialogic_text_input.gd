extends DialogicNode_TextInput


func _ready() -> void:
	super._ready()
	Localization.locale_changed.connect(_locale_changed)


func _locale_changed() -> void:
	if not visible or Dialogic.current_timeline == null:
		return
	var event: DialogicEvent = Dialogic.current_timeline_events[Dialogic.current_event_idx]
	if not event is DialogicTextInputEvent:
		return
	set_text(event.get_property_translated("text"))
	# Preserve typed input, caret and focus; changing the language must not reset an edit.
	get_node(input_line_edit).placeholder_text = event.get_property_translated("placeholder")
