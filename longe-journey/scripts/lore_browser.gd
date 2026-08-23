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


func _populate_category_options() -> void:
	_category_option.clear()
	_category_option.add_item("全部分类")
	_category_option.set_item_metadata(0, "")
	for category in LoreRuntime.get_categories():
		_category_option.add_item(category.label)
		_category_option.set_item_metadata(_category_option.item_count - 1, category.key)
	_category_option.select(0)


func _refresh_results() -> void:
	var query := _search_line.text.strip_edges()
	var category_key := _category_option.get_item_metadata(_category_option.selected) as String

	if query.is_empty() and category_key.is_empty():
		_show_categories()
		return

	var entries: Array
	var title := "搜索结果"
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
			title = "%s - %s" % [title, _category_label(category_key)]
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
	_title_label.text = "图鉴"
	_clear_list()
	for category in LoreRuntime.get_categories():
		var button := Button.new()
		button.text = "%s（%d）" % [category.label, category.count]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		entry_button.pressed.connect(_show_detail.bind(entry.slug))
		_apply_font(entry_button)
		_list_box.add_child(entry_button)

		if not entry.summary.is_empty():
			var summary := Label.new()
			summary.text = entry.summary
			summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var body: String
	if entry.category == "plot-threads":
		var text := LoreFilesystem.read_file(LoreFilesystem.PLOT_THREADS_PATH)
		for section in LoreFilesystem.list_plot_thread_sections(text):
			if section.title == entry.title:
				body = "\n".join(section.body_lines)
				break
	else:
		body = LoreFilesystem.read_file(entry["path"]).strip_edges()
	if body.is_empty():
		_add_empty_label()
	else:
		var body_label := Label.new()
		body_label.text = body
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_font(body_label)
		_list_box.add_child(body_label)
	_showing_detail = true


func _on_back_pressed() -> void:
	if _showing_detail:
		_search_bar.visible = true
		_render_entries(_rendered_entries, _rendered_title)
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
	empty_label.text = "暂无条目"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(empty_label)
	_list_box.add_child(empty_label)


func _apply_font(node: Control) -> void:
	var font := load(FONT_PATH) as Font
	if font != null:
		node.add_theme_font_override("font", font)
