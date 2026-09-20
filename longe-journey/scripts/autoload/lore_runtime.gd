extends Node

## Metadata keeps stable slugs/paths; every visible value comes from the selected PO.
const MANIFEST: JSON = preload("res://localization/lore.json")

var _entries_by_slug: Dictionary = {}
var _entries_by_category: Dictionary = {}
var _category_labels: Dictionary = {}


func _ready() -> void:
	var data: Dictionary = MANIFEST.data
	for category in data["categories"]:
		_category_labels[category["key"]] = category["label"]
		_entries_by_category[category["key"]] = []
	for entry in data["entries"]:
		if _entries_by_slug.has(entry["slug"]) or not _entries_by_category.has(entry["category"]):
			push_error("Duplicate lore slug or unknown category: " + entry["slug"])
			get_tree().quit(2)
			return
		_entries_by_slug[entry["slug"]] = entry
		_entries_by_category[entry["category"]].append(entry)


func _copy_entry(entry: Dictionary) -> Dictionary:
	var result := entry.duplicate(true)
	for property in ["title", "summary", "body"]:
		result[property] = Localization.text(entry[property])
	result["category_label"] = Localization.text(_category_labels[entry["category"]])
	result["fields"] = {}
	result["known_info"] = []
	for line in str(result["body"]).split("\n"):
		if line.begins_with("  - "):
			result["known_info"].append(line.trim_prefix("  - "))
		elif line.begins_with("- ") and line.contains(": "):
			var separator := line.find(": ")
			result["fields"][line.substr(2, separator - 2)] = line.substr(separator + 2)
	return result


func get_all_entries() -> Array:
	var result: Array = []
	for entry in _entries_by_slug.values():
		result.append(_copy_entry(entry))
	return result


func get_index_data() -> Dictionary:
	var categories := get_categories()
	var entries := get_all_entries()
	var counts: Dictionary = {}
	for category in categories:
		counts[category["key"]] = category["count"]
	return {"categories": categories, "entries": entries, "counts": counts, "total_entries": entries.size()}


func get_category(category: String) -> Array:
	var result: Array = []
	for entry in _entries_by_category.get(category, []):
		result.append(_copy_entry(entry))
	return result


func get_categories() -> Array:
	var result: Array = []
	for category in _entries_by_category:
		var entries := get_category(category)
		result.append({"key": category, "label": Localization.text(_category_labels[category]),
			"count": entries.size(), "slugs": entries.map(func(entry: Dictionary): return entry["slug"]),
			"entries": entries})
	result.sort_custom(func(a: Dictionary, b: Dictionary): return a["label"] < b["label"])
	return result


func get_detail(slug: String) -> Dictionary:
	return _copy_entry(_entries_by_slug[slug]) if _entries_by_slug.has(slug) else {}


func has_entry(slug: String) -> bool:
	return _entries_by_slug.has(slug)


func search(query: String) -> Array:
	var terms := query.to_lower().strip_edges().split(" ", false)
	if terms.is_empty():
		return []
	var result: Array = []
	for entry in get_all_entries():
		var haystack: String = (entry["title"] + " " + entry["summary"] + " " + entry["body"] + " " + entry["category_label"]).to_lower()
		if Array(terms).all(func(term: String): return haystack.contains(term)):
			result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary): return a["title"] < b["title"])
	return result


func search_by_category(category: String) -> Array:
	var result := get_category(category)
	result.sort_custom(func(a: Dictionary, b: Dictionary): return a["title"] < b["title"])
	return result
