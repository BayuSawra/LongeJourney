extends SceneTree
## Run through verify.py: load the real entry scene, then allow orderly shutdown.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ProjectSettings.has_setting("validation/user_data_dir") or \
			OS.get_user_data_dir().replace("\\", "/") != str(ProjectSettings.get_setting("validation/user_data_dir")):
		push_error("Run smoke test through tools/verify.py with isolated user data")
		quit(1)
		return
	var result := change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	if result != OK:
		push_error("Main scene could not load")
		quit(1)
		return
	await scene_changed
	for frame in range(120):
		await physics_frame
	current_scene.queue_free()
	# Spatial audio releases playback references on physics ticks, not process frames.
	for frame in range(4):
		await physics_frame
	quit()
