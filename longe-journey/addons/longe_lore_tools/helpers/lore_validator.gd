class_name LoreValidator
extends RefCounted

const LoreFilesystem = preload("res://addons/longe_lore_tools/helpers/lore_filesystem.gd")
const LoreMarkdownParser = preload("res://addons/longe_lore_tools/helpers/lore_markdown_parser.gd")

const ENTRY_RE := "^[a-z0-9]+(?:-[a-z0-9]+)*\\.md$"
const KNOWN_INFO_RE := "^\\- .+（来源：.+）$"


static func validate_all() -> Dictionary:
	var report := {
		"ok": true,
		"errors": [],
		"warnings": [],
	}
	for category in LoreFilesystem.CATEGORIES.keys():
		for path in LoreFilesystem.list_category(category):
			if category == "plot-threads":
				var sections := LoreFilesystem.list_plot_thread_sections(LoreFilesystem.read_file(path))
				for section in sections:
					_validate_plot_thread(section, report)
				continue
			var text := LoreFilesystem.read_file(path)
			_validate_entry(path, text, report)
	return report


static func _validate_entry(path: String, text: String, report: Dictionary) -> void:
	if not RegEx.create_from_string(ENTRY_RE).search(path.get_file()):
		report["errors"].append("%s：文件名必须是小写字母、数字和连字符，且以 .md 结尾" % path)
	var lines := text.split("\n")
	var heading_count := 0
	var in_known_info := false
	var known_info_lines: Array[String] = []
	var has_known_info := false
	var has_source := false
	for line in lines:
		if line.begins_with("# "):
			heading_count += 1
		if line.strip_edges().begins_with("- 已知信息:"):
			has_known_info = true
			in_known_info = true
			continue
		if line.strip_edges().begins_with("- 来源:"):
			has_source = true
			continue
		if in_known_info:
			if line.begins_with("  - ") or line.begins_with("\t- ") or line.begins_with("- "):
				known_info_lines.append(line.strip_edges().trim_prefix("- ").strip_edges())
			elif line.strip_edges().is_empty():
				continue
			else:
				in_known_info = false
	if heading_count != 1:
		report["errors"].append("%s：每个条目文件只能有一个 # 一级标题，当前有 %d 个" % [path, heading_count])
	var category := path.get_base_dir().get_file()
	if category in ["characters", "locations", "items"]:
		if not has_known_info:
			report["errors"].append("%s：缺少 - 已知信息:" % path)
		for info in known_info_lines:
			if not RegEx.create_from_string(KNOWN_INFO_RE).search(info):
				report["errors"].append("%s：已知信息行格式应为 - <事实>（来源：<来源>），当前：%s" % [path, info])
		var status := LoreMarkdownParser.extract_value(text, "状态")
		if status != "" and not status in LoreFilesystem.CATEGORIES[category]["statuses"]:
			report["errors"].append("%s：状态值 %s 不在允许范围 %s" % [path, status, str(LoreFilesystem.CATEGORIES[category]["statuses"])])
	elif category == "events":
		if not has_source:
			report["errors"].append("%s：事件缺少 - 来源:" % path)
	var referenced := _collect_markdown_links(text)
	for link in referenced:
		if not FileAccess.file_exists(link):
			report["errors"].append("%s：相对链接指向不存在的文件 %s" % [path, link])


static func _validate_plot_thread(section: Dictionary, report: Dictionary) -> void:
	var body := "\n".join(section["body_lines"])
	var status := LoreMarkdownParser.extract_value(body, "状态")
	if status == "":
		report["errors"].append("伏笔 %s：缺少 - 状态:" % section["title"])
	elif not status in LoreFilesystem.PLOT_THREAD_STATES:
		report["errors"].append("伏笔 %s：状态值 %s 不在允许范围 %s" % [section["title"], status, str(LoreFilesystem.PLOT_THREAD_STATES)])
	for required in ["埋设", "回收", "关联角色/地点", "说明"]:
		if LoreMarkdownParser.extract_value(body, required) == "":
			report["errors"].append("伏笔 %s：缺少 - %s:" % [section["title"], required])
	var referenced := _collect_markdown_links(body)
	for link in referenced:
		if not FileAccess.file_exists(link):
			report["errors"].append("伏笔 %s：相对链接指向不存在的文件 %s" % [section["title"], link])


static func _collect_markdown_links(text: String) -> Array[String]:
	var result: Array[String] = []
	var regex := RegEx.new()
	regex.compile("\\[([^\\]]+)\\]\\(([^\\)]+)\\)")
	for match in regex.search_all(text):
		var url := match.get_string(2).strip_edges()
		if url.begins_with("http://") or url.begins_with("https://") or url.begins_with("#"):
			continue
		result.append("res://lore/" + url.trim_prefix("./"))
	return result
