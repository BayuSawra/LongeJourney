class_name LoreFilesystem
extends RefCounted

## 所有 lore 路径统一从这里取，避免在 UI 层散落字符串。

const LORE_DIR := "res://lore"
const INDEX_PATH := "res://lore/INDEX.md"
const PLOT_THREADS_PATH := "res://lore/plot-threads.md"

const CATEGORIES := {
	"characters": {
		"label": "角色",
		"dir": "res://lore/characters",
		"statuses": ["unknown", "alive", "dead", "missing", "sealed", "destroyed"],
	},
	"locations": {
		"label": "地点",
		"dir": "res://lore/locations",
		"statuses": ["unknown", "alive", "dead", "missing", "sealed", "destroyed"],
	},
	"items": {
		"label": "物品",
		"dir": "res://lore/items",
		"statuses": ["unknown", "alive", "dead", "missing", "sealed", "destroyed"],
	},
	"events": {
		"label": "事件",
		"dir": "res://lore/events",
		"statuses": [],
	},
	"plot-threads": {
		"label": "伏笔",
		"dir": "res://lore/plot-threads.md",
		"statuses": ["open", "paid-off", "abandoned"],
	},
}

const PLOT_THREAD_STATES := ["open", "paid-off", "abandoned"]


static func lore_path(category: String, slug: String) -> String:
	var meta: Dictionary = CATEGORIES.get(category, {})
	var dir: String = meta.get("dir", "")
	if category == "plot-threads":
		return PLOT_THREADS_PATH
	return "%s/%s.md" % [dir, slug]


static func slug_from_path(path: String) -> String:
	var base := path.get_file().get_basename()
	return base


static func list_category(category: String) -> Array[String]:
	var meta: Dictionary = CATEGORIES.get(category, {})
	if meta.is_empty():
		return []
	if category == "plot-threads":
		return [PLOT_THREADS_PATH]
	var dir := String(meta.get("dir", ""))
	var result: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return result
	var dir_access := DirAccess.open(dir)
	if dir_access == null:
		return result
	dir_access.list_dir_begin()
	var file := dir_access.get_next()
	while file != "":
		if not dir_access.current_is_dir() and file.ends_with(".md") and file != "README.md":
			result.append("%s/%s" % [dir, file])
		file = dir_access.get_next()
	dir_access.list_dir_end()
	result.sort()
	return result


static func read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


static func write_file(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


static func ensure_entry_dir(path: String) -> bool:
	var dir_path := path.get_base_dir()
	if DirAccess.dir_exists_absolute(dir_path):
		return true
	var parent := dir_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		return false
	var err := DirAccess.make_dir_recursive_absolute(dir_path)
	return err == OK


static func delete_entry(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var err := DirAccess.remove_absolute(path)
	return err == OK


static func list_plot_thread_sections(text: String) -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	var lines := text.split("\n")
	var current: Dictionary = {}
	for line in lines:
		if line.begins_with("## "):
			if not current.is_empty():
				sections.append(current)
			current = {
				"title": line.trim_prefix("## ").strip_edges(),
				"body_lines": [],
			}
		elif not current.is_empty():
			current["body_lines"].append(line)
	if not current.is_empty():
		sections.append(current)
	return sections
