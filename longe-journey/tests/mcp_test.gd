extends GdUnitTestSuite

const AtomicBridge = preload("res://addons/godot_dotnet_mcp/tools/intelligence/atomic_bridge.gd")
const SceneImpl = preload("res://addons/godot_dotnet_mcp/tools/intelligence/impl_scene.gd")
const ProjectImpl = preload("res://addons/godot_dotnet_mcp/tools/intelligence/impl_project.gd")
const RuntimeScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_bridge.gd")
const DebuggerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_debugger_bridge.gd")

class FailedBridge extends "res://addons/godot_dotnet_mcp/tools/intelligence/atomic_bridge.gd":
	func call_atomic(_name: String, _args: Dictionary = {}) -> Dictionary:
		return error("Injected atomic failure")

func test_file_collection_includes_project_files() -> void:
	var bridge = AtomicBridge.new()
	assert_array(bridge.collect_files("*.tscn")).contains(["res://scenes/mianMenu.tscn"])
	assert_array(bridge.collect_files("*.gd")).contains(["res://scripts/extends Control.gd"])

func test_dependency_uid_type_and_path_are_decoded() -> void:
	var bridge = AtomicBridge.new()
	for path in ["res://scripts/extends Control.gd", "uid://b1ssoxmh62qia::::res://scripts/extends Control.gd",
			"uid://b1ssoxmh62qia::GDScript::res://scripts/extends Control.gd"]:
		assert_str(bridge.normalize_dependency_path(path)).is_equal("res://scripts/extends Control.gd")

func test_main_scene_dependency_is_not_falsely_missing() -> void:
	var impl = SceneImpl.new()
	impl.bridge = AtomicBridge.new()
	var result: Dictionary = impl.execute("scene_validate", {"scene": "res://scenes/mianMenu.tscn"})
	assert_bool(result.success).is_true()
	assert_bool(result.data.valid).is_true()
	assert_array(result.data.missing_dependencies).is_empty()

func test_main_scene_analysis_counts_real_nodes_and_scripts() -> void:
	var impl = SceneImpl.new()
	impl.bridge = AtomicBridge.new()
	var result: Dictionary = impl.execute("scene_analyze", {"scene": "res://scenes/mianMenu.tscn"})
	assert_bool(result.success).is_true()
	assert_int(result.data.node_count).is_equal(14)
	assert_int(result.data.script_count).is_equal(1)
	assert_str(result.data.scripts[0].path).is_equal("res://scripts/extends Control.gd")

func test_scene_analysis_propagates_atomic_failure() -> void:
	var impl = SceneImpl.new()
	impl.bridge = FailedBridge.new()
	for tool in ["scene_validate", "scene_analyze"]:
		var result: Dictionary = impl.execute(tool, {"scene": "res://scenes/mianMenu.tscn"})
		assert_bool(result.success).is_false()
		assert_str(result.error).is_equal("Injected atomic failure")

func test_project_state_propagates_scan_failure() -> void:
	var impl = ProjectImpl.new()
	impl.bridge = FailedBridge.new()
	var result: Dictionary = impl.execute("project_state", {})
	assert_bool(result.success).is_false()
	assert_str(result.error).is_equal("Injected atomic failure")

func test_missing_scene_is_an_explicit_failure() -> void:
	var impl = SceneImpl.new()
	impl.bridge = AtomicBridge.new()
	for tool in ["scene_validate", "scene_analyze"]:
		assert_bool(impl.execute(tool, {"scene": "res://not-present.tscn"}).success).is_false()

func test_debugger_channel_uses_capture_prefix_separator() -> void:
	assert_str(RuntimeScript.EVENT_CHANNEL).is_equal("godot_mcp:runtime_event")
	assert_str(RuntimeScript.LOG_CHANNEL).is_equal("godot_mcp:runtime_log")
	assert_str(DebuggerScript.MESSAGE_PREFIX).is_equal("godot_mcp")
	assert_str(DebuggerScript.EVENT_CHANNEL).is_equal(RuntimeScript.EVENT_CHANNEL)
	assert_str(DebuggerScript.LOG_CHANNEL).is_equal(RuntimeScript.LOG_CHANNEL)

func test_loader_dispose_breaks_executor_context_cycle() -> void:
	var loader = load("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd").new()
	var executor = load("res://addons/godot_dotnet_mcp/tools/intelligence/executor.gd").new()
	executor.configure_runtime({"tool_loader": loader})
	loader._runtime_by_category = {"intelligence": {"instance": executor}}
	var reference = weakref(loader)
	loader.dispose()
	loader = null
	assert_object(reference.get_ref()).is_null()
