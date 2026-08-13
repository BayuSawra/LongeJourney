@tool
extends VBoxContainer

const LoreFilesystem = preload("res://addons/longe_lore_tools/helpers/lore_filesystem.gd")
const LoreMarkdownParser = preload("res://addons/longe_lore_tools/helpers/lore_markdown_parser.gd")
const LoreValidator = preload("res://addons/longe_lore_tools/helpers/lore_validator.gd")
const IndexWriter = preload("res://addons/longe_lore_tools/helpers/index_writer.gd")

var _category_option: OptionButton
var _search_input: LineEdit
var _list: ItemList
var _name_input: LineEdit
var _status_option: OptionButton
var _known_info_input: TextEdit
var _source_input: TextEdit
var _time_input: LineEdit
var _location_input: LineEdit
var _characters_input: LineEdit
var _result_input: TextEdit
var _thread_fields: Dictionary
var _preview: RichTextLabel
var _source_edit: TextEdit
var _status_label: Label
var _current_path := ""
var _current_section := ""
var _category_cache: Dictionary = {}
var _entries: Array[String] = []


func _ready() -> void:
	name = "LongeLoreDock"
	custom_minimum_size = Vector2(360, 520)
	add_theme_constant_override("separation", 6)
	_build_ui()
	_load_category()
	_validate_all()


func _build_ui() -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "Lore 正典工具"
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)
	header.add_spacer(true)
	_rebuild_button(header)
	add_child(header)

	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	_category_option = OptionButton.new()
	_category_option.custom_minimum_size = Vector2(110, 0)
	for category in LoreFilesystem.CATEGORIES.keys():
		_category_option.add_item(LoreFilesystem.CATEGORIES[category]["label"], _category_option.item_count)
		_category_option.set_item_metadata(_category_option.item_count - 1, category)
	_category_option.item_selected.connect(_on_category_selected)
	filter_row.add_child(_category_option)
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "搜索条目"
	_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_input.text_changed.connect(_on_search_changed)
	filter_row.add_child(_search_input)
	add_child(filter_row)

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 180)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_list_selected)
	add_child(_list)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	tabs.add_child(_build_editor_tab())
	tabs.add_child(_build_preview_tab())
	tabs.add_child(_build_validate_tab())
	tabs.add_child(_build_index_tab())
	tabs.current_tab = 0


func _rebuild_button(parent: Control) -> void:
	var button := Button.new()
	button.text = "刷新"
	button.pressed.connect(_on_refresh)
	parent.add_child(button)


func _build_editor_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "编辑"
	tab.add_theme_constant_override("separation", 6)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	var name_label := Label.new()
	name_label.text = "名称"
	name_label.custom_minimum_size = Vector2(46, 0)
	name_row.add_child(name_label)
	_name_input = LineEdit.new()
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.text_changed.connect(_on_fields_changed)
	name_row.add_child(_name_input)
	tab.add_child(name_row)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 6)
	var status_label := Label.new()
	status_label.text = "状态"
	status_label.custom_minimum_size = Vector2(46, 0)
	status_row.add_child(status_label)
	_status_option = OptionButton.new()
	_status_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_option.item_selected.connect(_on_fields_changed)
	status_row.add_child(_status_option)
	tab.add_child(status_row)

	var known_label := Label.new()
	known_label.text = "已知信息（每行一条，格式：事实（来源：出处））"
	tab.add_child(known_label)
	_known_info_input = TextEdit.new()
	_known_info_input.custom_minimum_size = Vector2(0, 120)
	_known_info_input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_known_info_input.text_changed.connect(_on_fields_changed)
	tab.add_child(_known_info_input)

	var source_row := HBoxContainer.new()
	source_row.add_theme_constant_override("separation", 6)
	var source_label := Label.new()
	source_label.text = "来源"
	source_label.custom_minimum_size = Vector2(46, 0)
	source_row.add_child(source_label)
	_source_input = TextEdit.new()
	_source_input.custom_minimum_size = Vector2(0, 50)
	_source_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_input.text_changed.connect(_on_fields_changed)
	source_row.add_child(_source_input)
	tab.add_child(source_row)

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 6)
	var time_label := Label.new()
	time_label.text = "时间"
	time_label.custom_minimum_size = Vector2(46, 0)
	time_row.add_child(time_label)
	_time_input = LineEdit.new()
	_time_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_input.text_changed.connect(_on_fields_changed)
	time_row.add_child(_time_input)
	tab.add_child(time_row)

	var location_row := HBoxContainer.new()
	location_row.add_theme_constant_override("separation", 6)
	var location_label := Label.new()
	location_label.text = "地点"
	location_label.custom_minimum_size = Vector2(46, 0)
	location_row.add_child(location_label)
	_location_input = LineEdit.new()
	_location_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_location_input.text_changed.connect(_on_fields_changed)
	location_row.add_child(_location_input)
	tab.add_child(location_row)

	var characters_row := HBoxContainer.new()
	characters_row.add_theme_constant_override("separation", 6)
	var characters_label := Label.new()
	characters_label.text = "角色"
	characters_label.custom_minimum_size = Vector2(46, 0)
	characters_row.add_child(characters_label)
	_characters_input = LineEdit.new()
	_characters_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_characters_input.placeholder_text = "多个角色用逗号分隔"
	_characters_input.text_changed.connect(_on_fields_changed)
	characters_row.add_child(_characters_input)
	tab.add_child(characters_row)

	var result_row := HBoxContainer.new()
	result_row.add_theme_constant_override("separation", 6)
	var result_label := Label.new()
	result_label.text = "结果"
	result_label.custom_minimum_size = Vector2(46, 0)
	result_row.add_child(result_label)
	_result_input = TextEdit.new()
	_result_input.custom_minimum_size = Vector2(0, 60)
	_result_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_input.text_changed.connect(_on_fields_changed)
	result_row.add_child(_result_input)
	tab.add_child(result_row)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	var new_button := Button.new()
	new_button.text = "新建"
	new_button.pressed.connect(_on_new)
	actions.add_child(new_button)
	var save_button := Button.new()
	save_button.text = "保存"
	save_button.pressed.connect(_on_save)
	actions.add_child(save_button)
	var delete_button := Button.new()
	delete_button.text = "删除"
	delete_button.pressed.connect(_on_delete)
	actions.add_child(delete_button)
	var open_button := Button.new()
	open_button.text = "打开文件"
	open_button.pressed.connect(_on_open_file)
	actions.add_child(open_button)
	tab.add_child(actions)
	return tab


func _build_preview_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "预览"
	tab.add_theme_constant_override("separation", 6)
	var hint := Label.new()
	hint.text = "Markdown 源码与渲染预览"
	tab.add_child(hint)
	_source_edit = TextEdit.new()
	_source_edit.custom_minimum_size = Vector2(0, 160)
	_source_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_source_edit.text_changed.connect(_on_source_edit_changed)
	tab.add_child(_source_edit)
	_preview = RichTextLabel.new()
	_preview.bbcode_enabled = true
	_preview.fit_content = false
	_preview.scroll_active = true
	_preview.custom_minimum_size = Vector2(0, 120)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(_preview)
	return tab


func _build_validate_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "校验"
	tab.add_theme_constant_override("separation", 6)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	var validate_button := Button.new()
	validate_button.text = "重新校验"
	validate_button.pressed.connect(_validate_all)
	actions.add_child(validate_button)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_status_label)
	tab.add_child(actions)
	var output := RichTextLabel.new()
	output.name = "ValidationOutput"
	output.bbcode_enabled = true
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.custom_minimum_size = Vector2(0, 180)
	tab.add_child(output)
	return tab


func _build_index_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "索引"
	tab.add_theme_constant_override("separation", 6)
	var hint := Label.new()
	hint.text = "按 Python 脚本规则重建 lore/INDEX.md"
	tab.add_child(hint)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	var rebuild_button := Button.new()
	rebuild_button.text = "重建索引"
	rebuild_button.pressed.connect(_on_rebuild_index)
	actions.add_child(rebuild_button)
	var open_button := Button.new()
	open_button.text = "打开 INDEX.md"
	open_button.pressed.connect(func() -> void: _open_in_editor(LoreFilesystem.INDEX_PATH))
	actions.add_child(open_button)
	tab.add_child(actions)
	var output := RichTextLabel.new()
	output.name = "IndexOutput"
	output.bbcode_enabled = true
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(output)
	return tab


func _load_category() -> void:
	var category := _current_category()
	_entries.clear()
	for path in LoreFilesystem.list_category(category):
		_entries.append(path)
	_refresh_list()
	_clear_editor()
	_category_cache.clear()


func _refresh_list() -> void:
	_list.clear()
	var query := _search_input.text.strip_edges().to_lower()
	for path in _entries:
		var display := _display_name(path)
		if query != "" and not display.to_lower().contains(query) and not path.to_lower().contains(query):
			continue
		_list.add_item(display)
		_list.set_item_metadata(_list.item_count - 1, path)


func _display_name(path: String) -> String:
	var category := _current_category()
	if category == "plot-threads":
		return path.get_file().get_basename()
	var text := LoreFilesystem.read_file(path)
	var parsed := LoreMarkdownParser.parse_entry(text)
	if parsed["title"] != "":
		return parsed["title"]
	return path.get_file().get_basename()


func _clear_editor() -> void:
	_current_path = ""
	_current_section = ""
	_name_input.text = ""
	_known_info_input.text = ""
	_source_input.text = ""
	_time_input.text = ""
	_location_input.text = ""
	_characters_input.text = ""
	_result_input.text = ""
	_source_edit.text = ""
	_preview.text = ""
	_refresh_status_options()
	_show_info("就绪")


func _refresh_status_options() -> void:
	_status_option.clear()
	var category := _current_category()
	var statuses: Array = LoreFilesystem.CATEGORIES[category]["statuses"]
	if statuses.is_empty():
		_status_option.add_item("不适用")
		_status_option.disabled = true
		return
	_status_option.disabled = false
	for status in statuses:
		_status_option.add_item(status)


func _current_category() -> String:
	var idx := _category_option.get_selected()
	if idx < 0:
		return "characters"
	return String(_category_option.get_item_metadata(idx))


func _on_category_selected(_index: int) -> void:
	_load_category()


func _on_search_changed(_text: String) -> void:
	_refresh_list()


func _on_refresh() -> void:
	_load_category()
	_validate_all()


func _on_list_selected(index: int) -> void:
	if index < 0 or index >= _list.item_count:
		return
	var path := String(_list.get_item_metadata(index))
	_load_entry(path)


func _load_entry(path: String) -> void:
	_current_path = path
	var text := LoreFilesystem.read_file(path)
	var category := _current_category()
	if category == "plot-threads":
		_load_plot_thread_from_path(path)
		return
	var parsed := LoreMarkdownParser.parse_entry(text)
	_name_input.text = parsed["title"]
	_known_info_input.text = "\n".join(parsed["known_info"])
	_source_input.text = LoreMarkdownParser.extract_value(text, "来源")
	_time_input.text = LoreMarkdownParser.extract_value(text, "时间")
	_location_input.text = LoreMarkdownParser.extract_value(text, "地点")
	_characters_input.text = LoreMarkdownParser.extract_value(text, "参与角色")
	_result_input.text = LoreMarkdownParser.extract_value(text, "结果")
	_refresh_status_options()
	var status := LoreMarkdownParser.extract_value(text, "状态")
	if status != "":
		var found := -1
		for i in _status_option.item_count:
			if _status_option.get_item_text(i) == status:
				found = i
				break
		_status_option.select(found if found >= 0 else 0)
	_source_edit.text = text
	_preview.text = _to_preview(text)
	_show_info(path)


func _load_plot_thread_from_path(path: String) -> void:
	var text := LoreFilesystem.read_file(path)
	var sections := LoreFilesystem.list_plot_thread_sections(text)
	if sections.is_empty():
		_clear_editor()
		return
	var selected := _find_section(sections)
	if selected < 0:
		return
	var section: Dictionary = sections[selected]
	_current_section = section["title"]
	var body := "\n".join(section["body_lines"])
	_name_input.text = section["title"]
	_source_input.text = ""
	_time_input.text = ""
	_location_input.text = ""
	_characters_input.text = ""
	_result_input.text = ""
	_refresh_status_options()
	var status := LoreMarkdownParser.extract_value(body, "状态")
	for i in _status_option.item_count:
		if _status_option.get_item_text(i) == status:
			_status_option.select(i)
			break
	_known_info_input.text = body
	_source_edit.text = body
	_preview.text = _to_preview(body)
	_show_info("伏笔：%s" % section["title"])


func _find_section(sections: Array) -> int:
	for i in sections.size():
		if String(sections[i]["title"]).to_lower() == String(_current_section).to_lower():
			return i
	return -1


func _on_new() -> void:
	var category := _current_category()
	if category == "plot-threads":
		_current_section = ""
		_current_path = LoreFilesystem.PLOT_THREADS_PATH
		_name_input.text = ""
		_known_info_input.text = ""
		_source_edit.text = ""
		_preview.text = ""
		_show_info("伏笔：填写名称与字段后保存")
		return
	_current_path = ""
	_current_section = ""
	_name_input.text = ""
	_known_info_input.text = ""
	_source_input.text = ""
	_time_input.text = ""
	_location_input.text = ""
	_characters_input.text = ""
	_result_input.text = ""
	_source_edit.text = ""
	_preview.text = ""
	_refresh_status_options()
	_show_info("新建 %s：填写名称与字段后保存" % LoreFilesystem.CATEGORIES[category]["label"])


func _on_save() -> void:
	var category := _current_category()
	var name := _name_input.text.strip_edges()
	if name == "":
		_show_error("名称不能为空")
		return
	if category == "plot-threads":
		_save_plot_thread(name)
		return
	var slug := _to_slug(name)
	if slug == "":
		_show_error("名称需包含至少一个汉字或字母")
		return
	var path := LoreFilesystem.lore_path(category, slug)
	if _current_path != "" and _current_path != path and FileAccess.file_exists(path):
		_show_error("已存在同名条目 %s" % path)
		return
	if not LoreFilesystem.ensure_entry_dir(path):
		_show_error("无法创建目录 %s" % path.get_base_dir())
		return
	var text := _build_entry_text(category, name, slug)
	if not LoreFilesystem.write_file(path, text):
		_show_error("无法写入 %s" % path)
		return
	_current_path = path
	_load_category()
	_select_path(path)
	_validate_all()
	_show_info("已保存 %s" % path)


func _build_entry_text(category: String, name: String, slug: String) -> String:
	var lines: Array[String] = ["# %s" % name, ""]
	if category in ["characters", "locations", "items"]:
		var status := _status_option.get_item_text(_status_option.get_selected())
		if status != "" and status != "不适用":
			lines.append("- 状态: %s" % status)
			lines.append("")
		lines.append("- 已知信息:")
		var info := _known_info_input.text.strip_edges()
		if info == "":
			lines.append("  - 待补充（来源：暂无）")
		else:
			for line in info.split("\n"):
				var content := line.strip_edges().trim_prefix("- ")
				if content != "":
					lines.append("  - %s" % content)
		return "\n".join(lines) + "\n"
	if category == "events":
		lines.append("- 来源: %s" % _source_input.text.strip_edges())
		if _time_input.text.strip_edges() != "":
			lines.append("- 时间: %s" % _time_input.text.strip_edges())
		if _location_input.text.strip_edges() != "":
			lines.append("- 地点: %s" % _location_input.text.strip_edges())
		if _characters_input.text.strip_edges() != "":
			lines.append("- 参与角色: %s" % _characters_input.text.strip_edges())
		if _result_input.text.strip_edges() != "":
			lines.append("- 结果: %s" % _result_input.text.strip_edges())
		return "\n".join(lines) + "\n"
	return ""


func _save_plot_thread(name: String) -> void:
	var text := LoreFilesystem.read_file(LoreFilesystem.PLOT_THREADS_PATH)
	var sections := LoreFilesystem.list_plot_thread_sections(text)
	var existing := -1
	for i in sections.size():
		if String(sections[i]["title"]).to_lower() == name.to_lower():
			existing = i
			break
	var body := _known_info_input.text.strip_edges()
	if body == "":
		body = "- 状态: open\n- 埋设:\n- 回收:\n- 关联角色/地点:\n- 说明:"
	var new_section := "## %s\n\n%s\n" % [name, body]
	var lines := text.split("\n")
	if existing >= 0:
		var start := _section_start_line(lines, sections[existing]["title"])
		var end := _section_end_line(lines, start)
		var new_lines: Array[String] = []
		for i in lines.size():
			if i < start or i >= end:
				new_lines.append(lines[i])
		text = "\n".join(new_lines).strip_edges() + "\n"
		text += new_section
	else:
		text = text.strip_edges() + "\n\n" + new_section
	if not LoreFilesystem.write_file(LoreFilesystem.PLOT_THREADS_PATH, text):
		_show_error("无法写入伏笔文件")
		return
	_current_path = LoreFilesystem.PLOT_THREADS_PATH
	_current_section = name
	_load_category()
	_select_path(LoreFilesystem.PLOT_THREADS_PATH)
	_validate_all()
	_show_info("已保存伏笔 %s" % name)


func _section_start_line(lines: Array, title: String) -> int:
	for i in lines.size():
		if String(lines[i]).strip_edges() == "## " + title:
			return i
	return 0


func _section_end_line(lines: Array, start: int) -> int:
	for i in range(start + 1, lines.size()):
		if String(lines[i]).begins_with("## "):
			return i
	return lines.size()


func _on_delete() -> void:
	if _current_path == "":
		_show_error("先选择一个条目")
		return
	var category := _current_category()
	if category == "plot-threads":
		if _current_section == "":
			_show_error("先选择一个伏笔")
			return
		var text := LoreFilesystem.read_file(LoreFilesystem.PLOT_THREADS_PATH)
		var lines := text.split("\n")
		var start := _section_start_line(lines, _current_section)
		var end := _section_end_line(lines, start)
		var new_lines: Array[String] = []
		for i in lines.size():
			if i < start or i >= end:
				new_lines.append(lines[i])
		text = "\n".join(new_lines).strip_edges() + "\n"
		if not LoreFilesystem.write_file(LoreFilesystem.PLOT_THREADS_PATH, text):
			_show_error("无法删除伏笔")
			return
		_current_section = ""
		_load_category()
		_validate_all()
		_show_info("已删除伏笔")
		return
	if not LoreFilesystem.delete_entry(_current_path):
		_show_error("无法删除 %s" % _current_path)
		return
	var removed := _current_path
	_current_path = ""
	_load_category()
	_validate_all()
	_show_info("已删除 %s" % removed)


func _on_open_file() -> void:
	if _current_path == "":
		_show_error("先选择一个条目")
		return
	_open_in_editor(_current_path)


func _open_in_editor(path: String) -> void:
	if Engine.has_singleton("EditorInterface"):
		EditorInterface.get_resource_filesystem().scan()
		var script := load(path)
		if script:
			EditorInterface.edit_resource(script)


func _on_rebuild_index() -> void:
	var result := IndexWriter.rebuild()
	var output := _find_named_label("IndexOutput")
	if result["ok"]:
		output.text = "[color=#7fd9a0]索引已重建，写入 %s[/color]" % LoreFilesystem.INDEX_PATH
	else:
		output.text = "[color=#e06666]%s[/color]" % result["error"]
	_validate_all()


func _on_source_edit_changed() -> void:
	_preview.text = _to_preview(_source_edit.text)


func _on_fields_changed(_value = null) -> void:
	if _current_path != "" and _source_edit != null:
		var category := _current_category()
		if category == "plot-threads":
			_source_edit.text = _known_info_input.text
			_preview.text = _to_preview(_known_info_input.text)
			return
		var text := _build_entry_text(category, _name_input.text.strip_edges(), "")
		if text != "":
			_source_edit.text = text
			_preview.text = _to_preview(text)


func _to_preview(text: String) -> String:
	if text.strip_edges() == "":
		return ""
	var out := ""
	var in_list := false
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("# "):
			out += "[font_size=22]%s[/font_size]\n" % trimmed.trim_prefix("# ").strip_edges()
		elif trimmed.begins_with("## "):
			out += "[font_size=18][b]%s[/b][/font_size]\n" % trimmed.trim_prefix("## ").strip_edges()
		elif trimmed.begins_with("- "):
			if not in_list:
				out += "[ul]"
				in_list = true
			out += "[li]%s[/li]" % trimmed.trim_prefix("- ").strip_edges()
		else:
			if in_list:
				out += "[/ul]\n"
				in_list = false
			if trimmed != "":
				out += "%s\n" % trimmed
	if in_list:
		out += "[/ul]\n"
	return out


func _validate_all() -> void:
	var report := LoreValidator.validate_all()
	var output := _find_named_label("ValidationOutput")
	var parts: Array[String] = []
	if report["errors"].is_empty():
		parts.append("[color=#7fd9a0]全部条目校验通过[/color]")
	else:
		for error in report["errors"]:
			parts.append("[color=#e06666]- %s[/color]" % error)
	for warning in report["warnings"]:
		parts.append("[color=#f5c86d]- %s[/color]" % warning)
	output.text = "\n".join(parts)
	if _status_label:
		_status_label.text = "错误 %d 项" % report["errors"].size()


func _find_named_label(name: String) -> RichTextLabel:
	for child in get_children():
		if child is TabContainer:
			for tab in child.get_children():
				for node in tab.get_children():
					if node is RichTextLabel and node.name == name:
						return node
	return null


func _show_info(text: String) -> void:
	if _status_label:
		_status_label.text = text


func _show_error(text: String) -> void:
	if _status_label:
		_status_label.text = "[color=#e06666]%s[/color]" % text


func _select_path(path: String) -> void:
	for i in _list.item_count:
		if String(_list.get_item_metadata(i)) == path:
			_list.select(i)
			_list.ensure_current_is_visible()
			return


func _to_slug(name: String) -> String:
	var slug := name.to_lower().strip_edges()
	slug = slug.replace(" ", "-")
	slug = slug.replace("_", "-")
	slug = slug.replace("（", "")
	slug = slug.replace("）", "")
	slug = slug.replace("(", "")
	slug = slug.replace(")", "")
	slug = slug.replace("，", "-")
	slug = slug.replace(",", "-")
	var regex := RegEx.new()
	regex.compile("[^a-z0-9\\u4e00-\\u9fff-]")
	slug = regex.sub(slug, "", true)
	while slug.begins_with("-"):
		slug = slug.substr(1)
	while slug.ends_with("-"):
		slug = slug.substr(0, slug.length() - 1)
	return slug
