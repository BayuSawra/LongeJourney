extends CanvasLayer

const FONT_PATH := "res://font/HYZIKUTANGJINGJIEKAITIW.TTF"

var _list_box: VBoxContainer
var _title_label: Label
var _back_button: Button
var _search_line: LineEdit
var _category_option: OptionButton
var _clear_button: Button
var _search_bar: HBoxContainer
var _rendered_entries: Array
var _rendered_title: String
var _showing_detail: bool
var _detail_slug := ""


func _ready() -> void:
	_list_box = %ListBox
	_title_label = %LabelTitle
	_back_button = %ButtonBack
	_search_line = %LineEditSearch
	_category_option = %OptionButtonCategory
	_clear_button = %ButtonClear
	_search_bar = %SearchBar
	%ButtonBack.pressed.connect(_on_back_pressed)
	%ButtonClose.pressed.connect(_close)
	_search_line.text_changed.connect(_refresh_results)
	_category_option.item_selected.connect(_refresh_results)
	_clear_button.pressed.connect(_clear_search)
	_populate_category_options()
	_show_categories()
	Localization.locale_changed.connect(_locale_changed)


func _populate_category_options() -> void:
	_category_option.clear()
	_category_option.add_item(Localization.text("ui.lore.all_categories"))
	_category_option.set_item_metadata(0, "")
	for category in LoreRuntime.get_categories():
		_category_option.add_item(category.label)
		_category_option.set_item_metadata(_category_option.item_count - 1, category.key)
	_category_option.select(0)


func _refresh_results(_signal_argument: Variant = null) -> void:
	var query := _search_line.text.strip_edges()
	var category_key := _category_option.get_item_metadata(_category_option.selected) as String

	if query.is_empty() and category_key.is_empty():
		_show_categories()
		return

	var entries: Array
	var title := Localization.text("ui.lore.results")
	if query.is_empty():
		entries = LoreRuntime.search_by_category(category_key)
		title = _category_label(category_key)
	else:
		entries = LoreRuntime.search(query)
		if not category_key.is_empty():
			var filtered: Array = []
			for entry in entries:
				if entry.category == category_key:
					filtered.append(entry)
			entries = filtered
			title = Localization.format_text("ui.lore.filtered_results", {"title": title, "category": _category_label(category_key)})
	_render_entries(entries, title)


func _clear_search() -> void:
	_search_line.text = ""
	_category_option.select(0)
	_refresh_results()


func _category_label(category_key: String) -> String:
	for category in LoreRuntime.get_categories():
		if category.key == category_key:
			return category.label
	return ""


func _show_categories() -> void:
	_back_button.visible = false
	_title_label.text = Localization.text("ui.lore.title")
	_showing_detail = false
	_search_bar.visible = true
	_clear_list()
	for category in LoreRuntime.get_categories():
		var button := Button.new()
		button.text = Localization.format_text("ui.lore.category_count", {"category": category.label, "count": category.count})
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 44)
		button.theme_type_variation = &"SlotButton"
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = button.text
		button.pressed.connect(_show_category.bind(category.key))
		_apply_font(button)
		_list_box.add_child(button)

	if _list_box.get_child_count() == 0:
		_add_empty_label()


func _show_category(category_key: String) -> void:
	for index in _category_option.item_count:
		if _category_option.get_item_metadata(index) == category_key:
			_category_option.select(index)
			break
	_refresh_results()


func _render_entries(entries: Array, title: String) -> void:
	_search_bar.visible = true
	_rendered_entries = entries
	_rendered_title = title
	_showing_detail = false
	_back_button.visible = true
	_title_label.text = title
	_clear_list()

	for entry in entries:
		var entry_button := Button.new()
		entry_button.text = entry.title
		entry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry_button.custom_minimum_size = Vector2(0, 44)
		entry_button.theme_type_variation = &"SlotButton"
		entry_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		entry_button.tooltip_text = entry.title
		entry_button.pressed.connect(_show_detail.bind(entry.slug))
		_apply_font(entry_button)
		_list_box.add_child(entry_button)

		if not entry.summary.is_empty():
			var summary := Label.new()
			summary.text = entry.summary
			summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			summary.theme_type_variation = &"MutedLabel"
			summary.modulate = Color(0.72, 0.72, 0.72)
			_apply_font(summary)
			_list_box.add_child(summary)

	if _list_box.get_child_count() == 0:
		_add_empty_label()


func _show_detail(slug: String) -> void:
	var entry := LoreRuntime.get_detail(slug)
	if entry.is_empty():
		return
	_search_bar.visible = false
	_title_label.text = entry.title
	_clear_list()
	var body: String = entry["body"]
	_detail_slug = slug
	if body.is_empty():
		_add_empty_label()
	else:
		var body_label := Label.new()
		body_label.text = body
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_label.theme_type_variation = &"MutedLabel"
		_apply_font(body_label)
		_list_box.add_child(body_label)
	_showing_detail = true


func _on_back_pressed() -> void:
	if _showing_detail:
		_search_bar.visible = true
		_refresh_results()
	else:
		_clear_search()


func _close() -> void:
	queue_free()


func _clear_list() -> void:
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()


func _add_empty_label() -> void:
	var empty_label := Label.new()
	empty_label.text = Localization.text("ui.lore.empty")
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(empty_label)
	_list_box.add_child(empty_label)


func _apply_font(node: Control) -> void:
	var font := load(FONT_PATH) as Font
	if font != null:
		node.add_theme_font_override("font", font)


func _locale_changed() -> void:
	var category: String = _category_option.get_item_metadata(_category_option.selected)
	var was_detail := _showing_detail
	var slug := _detail_slug
	_populate_category_options()
	for index in _category_option.item_count:
		if _category_option.get_item_metadata(index) == category:
			_category_option.select(index)
	_refresh_results()
	if was_detail:
		_show_detail(slug)
