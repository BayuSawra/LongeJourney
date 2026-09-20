extends Node

## PO files are the only runtime text source. Never substitute another locale.
signal locale_changed

const SOURCE_LOCALE := "zh_CN"
const UI_FONT := preload("res://font/HYZIKUTANGJINGJIEKAITIW.TTF")
var locale := SOURCE_LOCALE
var catalogs: Dictionary = {}
var dialogue: Dictionary = {}
var _variables := RegEx.create_from_string(r"(?<!\\)\{([^{}]+)\}")


func _ready() -> void:
	for path in ProjectSettings.get_setting("internationalization/locale/translations", []):
		var catalog := load(path) as Translation
		if catalog == null or catalogs.has(catalog.locale):
			_fail("Invalid or duplicate translation resource: " + path)
			return
		catalogs[catalog.locale] = catalog
	if not _validate_catalogs():
		return
	TranslationServer.set_locale(locale)
	# Extend Dialogic's parser, before its variable expansion; no business framework.
	Dialogic.Text.text_modifiers.append({"method": _default_player_name, "type": -1, "order": 20})
	Dialogic.Text.load_parse_stack()
	Dialogic.Text.text_started.connect(_text_started)
	Dialogic.timeline_ended.connect(func() -> void: dialogue.clear())
	get_tree().node_added.connect(_apply_font)


func _validate_catalogs() -> bool:
	if not catalogs.has(SOURCE_LOCALE):
		return _fail("Missing source locale " + SOURCE_LOCALE)
	var keys: PackedStringArray = catalogs[SOURCE_LOCALE].get_message_list()
	for language in catalogs:
		var catalog: Translation = catalogs[language]
		if catalog.get_message_count() != keys.size():
			return _fail("Translation key count differs: " + language)
		for key in keys:
			if String(catalog.get_message(key)).strip_edges().is_empty():
				return _fail("Missing translation: %s / %s" % [language, key])
	return true


func supported_locales() -> Array:
	var result := catalogs.keys()
	result.sort()
	return result


func language_name(language: String) -> String:
	return text_in(language, "locale.name")


func set_locale(language: String) -> bool:
	if not catalogs.has(language):
		return _fail("Unsupported locale: " + language)
	if language == locale:
		return true
	locale = language
	TranslationServer.set_locale(locale)
	refresh_dialogue()
	_refresh_choices()
	locale_changed.emit()
	return true


func text(key: String) -> String:
	return text_in(locale, key)


func text_in(language: String, key: String) -> String:
	if not catalogs.has(language):
		_fail("Unsupported locale: " + language)
		return ""
	var value := String((catalogs[language] as Translation).get_message(key))
	if value.is_empty():
		_fail("Missing translation: %s / %s" % [language, key])
	return value


func format_text(key: String, values: Dictionary) -> String:
	return substitute(text(key), values)


func substitute(template: String, values: Dictionary) -> String:
	# Reverse offsets avoid interpreting braces inside user-provided values a second time.
	var matches := _variables.search_all(template)
	matches.reverse()
	for found in matches:
		var variable := found.get_string(1)
		if not values.has(variable):
			_fail("Missing text parameter: " + variable)
			return ""
		template = template.substr(0, found.get_start()) + str(values[variable]) + template.substr(found.get_end())
	return template


func player_name(raw_name: String) -> String:
	return text("player.default_name") if raw_name.is_empty() else raw_name


func _default_player_name(value: String) -> String:
	if str(Dialogic.VAR.get_variable("player_name")).is_empty():
		return value.replace("{player_name}", text("player.default_name"))
	return value


func record_event(event: DialogicEvent) -> Dictionary:
	var values: Dictionary = {}
	for found in _variables.search_all(text(event.get_property_translation_key("text"))):
		var variable := found.get_string(1)
		values[variable] = Dialogic.VAR.get_variable(variable)
	return {
		"key": event.get_property_translation_key("text"),
		"variables": values,
		"character": event.character.resource_path if event is DialogicTextEvent and event.character != null else "",
		"timeline": Dialogic.current_timeline.resource_path,
		"event_idx": Dialogic.current_event_idx,
		"type": event.event_name,
	}


func valid_saved_dialogue(record: Dictionary) -> bool:
	if record.is_empty():
		return true
	for field in ["key", "character", "timeline", "type"]:
		if not record.get(field) is String:
			return false
	if not record.get("variables") is Dictionary or not record.get("event_idx") is int or not record.get("segment") is int:
		return false
	if record.type != "Text" or record.segment < 0 or record.event_idx < 0:
		return false
	if not record.timeline in ProjectSettings.get_setting("dialogic/directories/dtl_directory").values():
		return false
	if not record.character.is_empty() and not record.character in ProjectSettings.get_setting("dialogic/directories/dch_directory").values():
		return false
	var timeline := load(record.timeline) as DialogicTimeline
	timeline.process()
	if record.event_idx >= timeline.events.size():
		return false
	var event: DialogicEvent = timeline.events[record.event_idx]
	if not event is DialogicTextEvent or event.get_property_translation_key("text") != record.key:
		return false
	var variables := {}
	for found in _variables.search_all(text(record.key)):
		variables[found.get_string(1)] = true
	if record.variables.size() != variables.size():
		return false
	for variable_name in variables:
		if not record.variables.has(variable_name) or typeof(record.variables[variable_name]) not in [TYPE_STRING, TYPE_BOOL, TYPE_INT, TYPE_FLOAT]:
			return false
	return record.segment < event._split_translated_text().size()


func render_record(record: Dictionary) -> String:
	var values: Dictionary = record["variables"].duplicate(true)
	if values.has("player_name"):
		values["player_name"] = player_name(str(values["player_name"]))
	return substitute(text(record["key"]), values)


func _text_started(_info: Dictionary) -> void:
	var event: DialogicEvent = Dialogic.current_timeline_events[Dialogic.current_event_idx]
	if not event is DialogicTextEvent:
		return
	dialogue = record_event(event)
	dialogue["segment"] = maxi(Dialogic.Text.text_sub_index, 0)
	# A language change can occur during the awaited textbox animation.
	refresh_dialogue()


func refresh_dialogue() -> void:
	if dialogue.is_empty():
		return
	var event := DialogicTextEvent.new()
	var segments := event.split_regex.search_all(render_record(dialogue))
	var index: int = dialogue["segment"]
	if index >= segments.size():
		_fail("Translated dialogue segment count changed")
		return
	var start := index
	while start > 0 and segments[start].get_string().begins_with("[n+]"):
		start -= 1
	var value := ""
	for i in range(start, index + 1):
		value += segments[i].get_string().trim_prefix("[n]").trim_prefix("[n+]")
	# Parsing rebuilds effect positions, but never executes effects or advances events.
	var pending_count: int = Dialogic.Text.parsed_text_effect_info.size()
	var parsed := value
	# Snapshots are already expanded: never interpret braces inside a user's name again.
	for parser in Dialogic.Text.parse_stack:
		if parser["type"] not in [-1, 0] or parser["method"] == Dialogic.VAR.parse_variables or parser["method"] == _default_player_name:
			continue
		parsed = parser["method"].call(parsed)
	var rebuilt: Array = Dialogic.Text.parsed_text_effect_info
	while rebuilt.size() > pending_count:
		rebuilt.pop_front()
	Dialogic.Text.dialog_text = parsed
	for node in Dialogic.Text.get_textboxes(Dialogic.Text.active_textbox):
		var ratio: float = node.visible_ratio
		var alignment_prefix := ""
		if node.alignment == DialogicNode_DialogText.Alignment.CENTER:
			alignment_prefix = "[center]"
		elif node.alignment == DialogicNode_DialogText.Alignment.RIGHT:
			alignment_prefix = "[right]"
		node.text = alignment_prefix + parsed
		node.visible_ratio = ratio
		Dialogic.Text.dialog_text_parsed = node.get_parsed_text()
	Dialogic.Text.update_name_label(Dialogic.Text.get_current_speaker(), true)


func _refresh_choices() -> void:
	if Dialogic.current_timeline == null or Dialogic.current_state != Dialogic.States.AWAITING_CHOICE:
		return
	# Use the displayed question snapshot; never re-evaluate conditions or restart delays.
	for choice in Dialogic.Choices.last_question_info.get("choices", []):
		if not choice["visible"]:
			continue
		var event: DialogicChoiceEvent = Dialogic.current_timeline_events[choice["event_index"]]
		var property := "disabled_text" if choice["disabled"] and not event.disabled_text.is_empty() else "text"
		choice["text"] = Dialogic.Text.parse_text(event.get_property_translated(property), 1)
		var button: DialogicNode_ChoiceButton = Dialogic.Choices.get_choice_button(choice["button_index"])
		if button != null and button.visible:
			button.set_choice_text(choice["text"])


func _apply_font(node: Node) -> void:
	if node is Control:
		node.add_theme_font_override("font", UI_FONT)
		if node is RichTextLabel:
			for font_property in ["normal_font", "bold_font", "italics_font", "bold_italics_font"]:
				node.add_theme_font_override(font_property, UI_FONT)


func _fail(reason: String) -> bool:
	push_error("Localization: " + reason)
	get_tree().quit(2)
	return false
