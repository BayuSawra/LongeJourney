extends CanvasLayer

## Runtime sign for the blank plaque in hospital_ward_door_505.png.

const DOOR_BACKGROUND := "res://art/backgrounds/hospital_ward_door_505.png"
const BACKGROUND_SIZE := Vector2(1672.0, 941.0)
const PLAQUE_POSITION := Vector2(1320.0, 28.0)
const PLAQUE_SIZE := Vector2(150.0, 72.0)

@onready var sign: Label = $Sign
var attached_sign: Label


func _ready() -> void:
	sign.modulate.a = 0.0
	if not Dialogic.Backgrounds.background_changed.is_connected(_on_background_changed):
		Dialogic.Backgrounds.background_changed.connect(_on_background_changed)
	_on_background_changed({"argument": Dialogic.Backgrounds.argument})
	if not get_viewport().size_changed.is_connected(_position_sign):
		get_viewport().size_changed.connect(_position_sign)
	_position_sign()


func _exit_tree() -> void:
	_clear_attached_sign()
	if Dialogic.Backgrounds.background_changed.is_connected(_on_background_changed):
		Dialogic.Backgrounds.background_changed.disconnect(_on_background_changed)
	var viewport := get_viewport()
	if viewport != null and viewport.size_changed.is_connected(_position_sign):
		viewport.size_changed.disconnect(_position_sign)


func _on_background_changed(_info: Dictionary) -> void:
	# Dialogic's change payload carries an empty argument for its default image
	# scene; the subsystem state is the authoritative current image path.
	var background := str(Dialogic.Backgrounds.argument)
	sign.visible = background == DOOR_BACKGROUND
	if sign.visible:
		call_deferred("_attach_sign_to_background")
	else:
		_clear_attached_sign()


func _position_sign() -> void:
	var plaque_rect := _plaque_rect(get_viewport().get_visible_rect().size)
	sign.position = plaque_rect.position
	sign.size = plaque_rect.size
	if is_instance_valid(attached_sign):
		attached_sign.position = plaque_rect.position
		attached_sign.size = plaque_rect.size


func _plaque_rect(viewport_size: Vector2) -> Rect2:
	var cover_scale: float = maxf(viewport_size.x / BACKGROUND_SIZE.x, viewport_size.y / BACKGROUND_SIZE.y)
	var rendered_size: Vector2 = BACKGROUND_SIZE * cover_scale
	var crop_offset: Vector2 = (viewport_size - rendered_size) * 0.5
	return Rect2(crop_offset + PLAQUE_POSITION * cover_scale, PLAQUE_SIZE * cover_scale)


func _attach_sign_to_background() -> void:
	_clear_attached_sign()
	if not sign.visible:
		return
	var background_node := Dialogic.Backgrounds.get_background_node()
	if background_node == null:
		return
	attached_sign = sign.duplicate() as Label
	attached_sign.name = "AttachedDoorSign"
	attached_sign.modulate = Color.WHITE
	attached_sign.add_theme_color_override("font_color", Color(0.08, 0.09, 0.09, 1.0))
	attached_sign.add_theme_color_override("font_outline_color", Color(0.92, 0.92, 0.87, 0.9))
	attached_sign.add_theme_constant_override("outline_size", 3)
	attached_sign.add_theme_font_size_override("font_size", 16)
	attached_sign.visible = true
	attached_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_node.add_child(attached_sign)
	_position_sign()


func _clear_attached_sign() -> void:
	if is_instance_valid(attached_sign):
		attached_sign.queue_free()
	attached_sign = null
