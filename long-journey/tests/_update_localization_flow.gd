extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	ResourceLoader.add_resource_format_loader(load("res://addons/dialogic/Resources/TimelineResourceLoader.gd").new())
	ResourceLoader.add_resource_format_loader(load("res://addons/dialogic/Resources/CharacterResourceLoader.gd").new())
	var baseline: Dictionary = {}
	var paths: Dictionary = ProjectSettings.get_setting("dialogic/directories/dtl_directory")
	for path in paths.values():
		var timeline := load(path) as DialogicTimeline
		if timeline == null:
			push_error("Cannot load timeline: " + str(path))
			quit(1)
			return
		timeline.process()
		var hashes: Array[String] = []
		for event: DialogicEvent in timeline.events:
			if event is DialogicAudioEvent:
				continue
			var serialized: String = event._store_as_string().replace("\r\n", "\n").trim_suffix("\r")
			hashes.append(serialized.sha256_text())
		baseline[path] = hashes
	var output := FileAccess.open("res://tests/fixtures/localization_flow.json", FileAccess.WRITE)
	if output == null:
		push_error("Cannot write localization flow fixture")
		quit(1)
		return
	output.store_string(JSON.stringify(baseline, "  ", false))
	output.close()
	print("LOCALIZATION_FLOW_UPDATED")
	quit()
