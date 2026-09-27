@tool
extends "res://addons/dialogic/Modules/DefaultLayoutParts/Layer_TextInput/text_input_layer.gd"

var _theme_is_private := false


func _apply_export_overrides() -> void:
	var layer_theme := get(&"theme") as Theme
	if not _theme_is_private and layer_theme != null:
		set(&"theme", layer_theme.duplicate(true))
		_theme_is_private = true
	super._apply_export_overrides()
