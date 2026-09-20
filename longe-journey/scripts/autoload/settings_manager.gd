extends Node

const SETTINGS_PATH := "user://settings.cfg"

var _text_speed := 38.0
var _volume := 100
var _fullscreen := false
var _panel: Node = null
var _loading_settings := false

func _ready() -> void:
	_load_settings()
	save()

func set_text_speed(value: float) -> void:
	_text_speed = clampf(value, 1.0, 200.0)
	VisualFX.set_text_speed(_text_speed)
	save()

func get_text_speed() -> float:
	return _text_speed

func set_volume(value: int) -> void:
	_volume = clampi(value, 0, 100)
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(_volume / 100.0))
	save()

func get_volume() -> int:
	return _volume

func set_fullscreen(enabled: bool) -> void:
	_fullscreen = enabled
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	save()

func get_fullscreen() -> bool:
	return _fullscreen

func open_settings() -> void:
	if _panel != null:
		return
	_panel = (load("res://scenes/settings_panel.tscn") as PackedScene).instantiate()
	add_child(_panel)

func close_settings() -> void:
	if _panel == null:
		return
	var panel := _panel
	_panel = null
	panel.queue_free()

func get_language() -> String:
	return Localization.locale

func set_language(language: String) -> void:
	if Localization.set_locale(language):
		save()

func _load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_error("Cannot read settings: " + error_string(error))
		get_tree().quit(2)
		return
	_loading_settings = true
	set_language(config.get_value("localization", "language", Localization.SOURCE_LOCALE))
	set_text_speed(config.get_value("display", "text_speed", _text_speed))
	set_volume(int(config.get_value("audio", "volume", _volume)))
	set_fullscreen(config.get_value("display", "fullscreen", _fullscreen))
	_loading_settings = false

func save() -> void:
	if _loading_settings:
		return
	var config := ConfigFile.new()
	config.set_value("localization", "language", get_language())
	config.set_value("display", "text_speed", _text_speed)
	config.set_value("audio", "volume", _volume)
	config.set_value("display", "fullscreen", _fullscreen)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_error("Cannot save settings: " + error_string(error))
