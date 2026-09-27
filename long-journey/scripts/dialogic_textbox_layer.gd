@tool
extends "res://addons/dialogic/Modules/DefaultLayoutParts/Layer_VN_Textbox/vn_textbox_layer.gd"

const HORIZONTAL_GUTTER := 32.0
const MAX_BOX_WIDTH := 1000.0
const BOX_HEIGHT := 156.0
const BOTTOM_MARGIN := 24.0


func _ready() -> void:
	super._ready()
	if not get_viewport().size_changed.is_connected(_apply_box_settings):
		get_viewport().size_changed.connect(_apply_box_settings)
	_apply_box_settings()


func _apply_box_settings() -> void:
	super._apply_box_settings()
	var responsive_width := minf(MAX_BOX_WIDTH, maxf(0.0, get_viewport().get_visible_rect().size.x - HORIZONTAL_GUTTER * 2.0))
	var responsive_size := Vector2(responsive_width, BOX_HEIGHT)
	var sizer: Control = %Sizer
	sizer.size = responsive_size
	sizer.position = responsive_size * Vector2(-0.5, -1.0) + Vector2(0.0, -BOTTOM_MARGIN)
