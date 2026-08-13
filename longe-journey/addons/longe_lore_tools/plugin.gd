@tool
extends EditorPlugin

const LoreDock = preload("res://addons/longe_lore_tools/ui/lore_dock.gd")

var _dock: Control


func _enter_tree() -> void:
	_dock = LoreDock.new()
	_dock.name = "LongeLoreDock"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
