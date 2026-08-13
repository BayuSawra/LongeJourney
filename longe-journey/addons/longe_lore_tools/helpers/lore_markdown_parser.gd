class_name LoreMarkdownParser
extends RefCounted

const LoreFilesystem = preload("res://addons/longe_lore_tools/helpers/lore_filesystem.gd")


static func parse_entry(text: String) -> Dictionary:
	var result := {
		"title": "",
		"fields": {},
		"known_info": [],
		"raw": text,
	}
	if text.strip_edges().is_empty():
		return result
	var lines := text.split("\n")
	var in_known_info := false
	for line in lines:
		if line.begins_with("# ") and result["title"] == "":
			result["title"] = line.trim_prefix("# ").strip_edges()
			continue
		if line.strip_edges().is_empty():
			continue
		if in_known_info:
			if line.begins_with("- ") or line.begins_with("\t- ") or line.begins_with("  - "):
				result["known_info"].append(line.strip_edges().trim_prefix("- ").strip_edges())
			elif not line.begins_with(" ") and not line.begins_with("\t"):
				in_known_info = false
			else:
				continue
		if not in_known_info and (line.begins_with("- ") or line.begins_with("  - ")):
			var content := line.strip_edges().trim_prefix("- ").strip_edges()
			var colon := content.find(":")
			if colon > 0:
				var key := content.substr(0, colon).strip_edges()
				var value := content.substr(colon + 1).strip_edges()
				result["fields"][key] = value
				if key == "已知信息":
					in_known_info = true
	return result


static func parse_known_info_field(text: String) -> Array[String]:
	var result: Array[String] = []
	var lines := text.split("\n")
	var active := false
	for line in lines:
		if line.begins_with("- 已知信息:"):
			active = true
			continue
		if not active:
			continue
		if line.begins_with("  - ") or line.begins_with("\t- ") or line.begins_with("- "):
			result.append(line.strip_edges().trim_prefix("- ").strip_edges())
		elif line.strip_edges().is_empty():
			continue
		else:
			active = false
	return result


static func summary_for_entry(path: String, text: String) -> String:
	var meta: Dictionary = LoreFilesystem.CATEGORIES.get(LoreFilesystem.slug_from_path(path), {})
	var category := LoreFilesystem.slug_from_path(path)
	if category == "plot-threads":
		return ""
	if category == "events":
		return extract_value(text, "结果")
	var known := parse_known_info_field(text)
	if known.is_empty():
		return ""
	var first := known[0]
	return strip_source_suffix(first)


static func strip_source_suffix(line: String) -> String:
	var idx := line.rfind("（来源：")
	if idx == -1:
		return line
	return line.substr(0, idx).strip_edges()


static func extract_value(text: String, key: String) -> String:
	var prefix := "- %s:" % key
	for line in text.split("\n"):
		if line.strip_edges().begins_with(prefix):
			return line.strip_edges().trim_prefix(prefix).strip_edges()
	return ""
