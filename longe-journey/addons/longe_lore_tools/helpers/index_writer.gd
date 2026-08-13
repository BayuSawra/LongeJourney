class_name IndexWriter
extends RefCounted

const LoreFilesystem = preload("res://addons/longe_lore_tools/helpers/lore_filesystem.gd")
const LoreMarkdownParser = preload("res://addons/longe_lore_tools/helpers/lore_markdown_parser.gd")

const HEADER := """# Lore Index

此文件由 `tools/update_lore_index.py` 自动生成；新增或修改条目后请重新运行该脚本，不要手工编辑。
"""

const SECTION_TITLES := {
	"characters": "## 角色",
	"locations": "## 地点",
	"items": "## 物品",
	"events": "## 事件",
	"plot-threads": "## 伏笔",
}


static func rebuild() -> Dictionary:
	var lines: Array[String] = [HEADER]
	var missing := 0
	for category in ["characters", "locations", "items", "events", "plot-threads"]:
		lines.append(SECTION_TITLES[category])
		var entries := _entries_for_category(category)
		if entries.is_empty():
			lines.append("")
			continue
		for entry in entries:
			lines.append("- %s%s" % [entry["name"], " —%s" % entry["summary"] if entry["summary"] != "" else ""])
		lines.append("")
	var text := "\n".join(lines).trim_suffix("\n") + "\n"
	if not LoreFilesystem.write_file(LoreFilesystem.INDEX_PATH, text):
		return {"ok": false, "error": "无法写入 INDEX.md"}
	return {"ok": true, "count": missing}


static func _entries_for_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if category == "plot-threads":
		var text := LoreFilesystem.read_file(LoreFilesystem.PLOT_THREADS_PATH)
		for section in LoreFilesystem.list_plot_thread_sections(text):
			var summary := LoreMarkdownParser.extract_value("\n".join(section["body_lines"]), "说明")
			result.append({
				"name": section["title"],
				"summary": summary,
			})
		return result
	for path in LoreFilesystem.list_category(category):
		var text := LoreFilesystem.read_file(path)
		var parsed := LoreMarkdownParser.parse_entry(text)
		var summary := LoreMarkdownParser.summary_for_entry(path, text)
		result.append({
			"name": parsed["title"] if parsed["title"] != "" else path.get_file().get_basename(),
			"summary": summary,
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	return result
