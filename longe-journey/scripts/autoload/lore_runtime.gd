class_name LoreRuntime
extends Node

## Read-only runtime view of lore data imported from lore/INDEX.md and canon files.

var _entries_by_slug: Dictionary = {}
var _entries_by_category: Dictionary = {}


func _ready() -> void:
	_load_index()


func get_all_entries() -> Array:
	var result: Array = []
	for category in _entries_by_category:
		for entry in _entries_by_category[category]:
			result.append(_copy_entry(entry))
	return result


func get_index() -> Dictionary:
	var categories := get_categories()
	var entries := get_all_entries()
	var counts: Dictionary = {}
	for category in categories:
		counts[category["key"]] = category["count"]
	return {
		"categories": categories,
		"entries": entries,
		"counts": counts,
		"total_entries": entries.size(),
	}


func get_category(category: String) -> Array:
	var result: Array = []
	for entry in _entries_by_category.get(category, []):
		result.append(_copy_entry(entry))
	return result


func get_categories() -> Array:
	var result: Array = []
	for category in _sorted_category_keys():
		var entries: Array = _entries_by_category[category]
		var meta: Dictionary = LoreFilesystem.CATEGORIES.get(category, {})
		var slugs: Array = []
		var summaries: Array = []
		for entry in entries:
			slugs.append(entry["slug"])
			summaries.append(_copy_entry(entry))
		result.append({
			"key": category,
			"label": meta.get("label", category),
			"count": entries.size(),
			"slugs": slugs,
			"entries": summaries,
		})
	return result


func get_detail(slug: String) -> Dictionary:
	if not _entries_by_slug.has(slug):
		return {}
	return _copy_entry(_entries_by_slug[slug])


func has_entry(slug: String) -> bool:
	return _entries_by_slug.has(slug)


func search(query: String) -> Array:
	var terms := query.to_lower().strip_edges().split(" ", false)
	if terms.is_empty():
		return []
	var result: Array = []
	for entry in get_all_entries():
		if _entry_matches_terms(entry, terms):
			result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["title"].to_lower() < b["title"].to_lower()
	)
	return result


func search_by_category(category: String) -> Array:
	var result: Array = []
	for entry in get_category(category):
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["title"].to_lower() < b["title"].to_lower()
	)
	return result


func _sorted_category_keys() -> Array:
	var keys := _entries_by_category.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return _category_label(a).to_lower() < _category_label(b).to_lower()
	)
	return keys


func _entry_matches_terms(entry: Dictionary, terms: Array) -> bool:
	var haystack := _searchable_text(entry).to_lower()
	for term in terms:
		if term.is_empty():
			continue
		if not haystack.contains(term):
			return false
	return true


func _searchable_text(entry: Dictionary) -> String:
	var parts: Array = [entry.get("title", ""), entry.get("summary", ""), entry.get("category", ""), entry.get("category_label", ""), entry.get("path", "")]
	for field_value in entry.get("fields", {}).values():
		parts.append(str(field_value))
	for info in entry.get("known_info", []):
		parts.append(str(info))
	return " ".join(parts)


func _load_index() -> void:
	var text := LoreFilesystem.read_file(LoreFilesystem.INDEX_PATH)
	if text.is_empty():
		return

	var category := ""
	var order := 0
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("## "):
			category = _category_for_label(trimmed.substr(3).strip_edges())
			if not category.is_empty() and not _entries_by_category.has(category):
				_entries_by_category[category] = []
			continue
		if category.is_empty() or not trimmed.begins_with("- "):
			continue

		var item := trimmed.substr(2).strip_edges()
		if item.is_empty():
			continue
		var parts := _split_index_item(item)
		var entry := _build_entry(category, parts[0], parts[1], order)
		order += 1
		if entry.is_empty():
			continue

		_entries_by_slug[entry["slug"]] = entry
		if not _entries_by_category.has(category):
			_entries_by_category[category] = []
		_entries_by_category[category].append(entry)


func _build_entry(category: String, title: String, summary: String, order: int) -> Dictionary:
	var canon := _find_canon(category, title)
	var entry := {
		"slug": _slug_for(category, title, canon.get("path", ""), order),
		"title": title,
		"summary": summary,
		"category": category,
		"category_label": _category_label(category),
		"path": canon.get("path", ""),
		"fields": canon.get("fields", {}),
		"known_info": canon.get("known_info", []),
	}
	return entry


func _find_canon(category: String, title: String) -> Dictionary:
	var result := {
		"path": "",
		"fields": {},
		"known_info": [],
	}

	if category == "plot-threads":
		var plot_text := LoreFilesystem.read_file(LoreFilesystem.PLOT_THREADS_PATH)
		if plot_text.is_empty():
			return result
		for section in LoreFilesystem.list_plot_thread_sections(plot_text):
			if not section is String:
				continue
			if _title_from_text(section) != title:
				continue
			var parsed := LoreMarkdownParser.parse_entry(section)
			result["path"] = LoreFilesystem.PLOT_THREADS_PATH
			result["fields"] = parsed.get("fields", {})
			result["known_info"] = parsed.get("known_info", [])
			return result
		return result

	for path in LoreFilesystem.list_category(category):
		var text := LoreFilesystem.read_file(path)
		if text.is_empty():
			continue
		var parsed := LoreMarkdownParser.parse_entry(text)
		if parsed.get("title", "").strip_edges() != title:
			continue
		result["path"] = str(path)
		result["fields"] = parsed.get("fields", {})
		result["known_info"] = parsed.get("known_info", [])
		return result
	return result


func _title_from_text(text: String) -> String:
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("# "):
			return trimmed.substr(2).strip_edges()
		if trimmed.begins_with("## "):
			return trimmed.substr(3).strip_edges()
	return text.strip_edges()


func _split_index_item(item: String) -> Array:
	var parts := item.split("—", true, 1)
	var title := parts[0].strip_edges()
	var summary := ""
	if parts.size() > 1:
		summary = parts[1].strip_edges()
	return [title, summary]


func _category_for_label(label: String) -> String:
	for category in LoreFilesystem.CATEGORIES:
		var meta: Dictionary = LoreFilesystem.CATEGORIES[category]
		if meta.get("label", "") == label:
			return category
	return ""


func _category_label(category: String) -> String:
	var meta: Dictionary = LoreFilesystem.CATEGORIES.get(category, {})
	return meta.get("label", category)


func _slug_for(category: String, title: String, path: String, order: int) -> String:
	if category != "plot-threads" and not path.is_empty():
		var path_slug := LoreFilesystem.slug_from_path(path)
		if not path_slug.is_empty():
			return path_slug
	return _unique_slug(title, order)


func _unique_slug(title: String, order: int) -> String:
	var base := _slugify(title)
	if base.is_empty():
		base = "entry"
	var slug := base
	var counter := order
	while _entries_by_slug.has(slug):
		counter += 1
		slug = "%s-%d" % [base, counter]
	return slug


func _slugify(text: String) -> String:
	var slug := ""
	var allowed := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	for i in text.length():
		var ch := text[i]
		if allowed.contains(ch):
			slug += ch.to_lower()
		elif ch == " " or ch == "-" or ch == "_":
			slug += "-"
	while slug.find("--") != -1:
		slug = slug.replace("--", "-")
	return slug.trim_prefix("-").trim_suffix("-")


func _copy_entry(entry: Dictionary) -> Dictionary:
	return entry.duplicate(true)
