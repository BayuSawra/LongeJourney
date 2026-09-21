extends Node

const SETTINGS_PATH := "user://settings.cfg"

var _text_speed := 38.0
var _bgm_volume := 100
var _sfx_volume := 100
var _ui_volume := 100
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

func set_bgm_volume(value: int) -> void:
	_bgm_volume = clampi(value, 0, 100)
	_apply_bus_volume("BGM", _bgm_volume)
	save()

func get_bgm_volume() -> int:
	return _bgm_volume

func set_sfx_volume(value: int) -> void:
	_sfx_volume = clampi(value, 0, 100)
	_apply_bus_volume("SFX", _sfx_volume)
	save()

func get_sfx_volume() -> int:
	return _sfx_volume

func set_ui_volume(value: int) -> void:
	_ui_volume = clampi(value, 0, 100)
	_apply_bus_volume("UI", _ui_volume)
	save()

func get_ui_volume() -> int:
	return _ui_volume

## Compatibility API for older callers and pre-split settings.
func set_volume(value: int) -> void:
	var normalized := clampi(value, 0, 100)
	_bgm_volume = normalized
	_sfx_volume = normalized
	_ui_volume = normalized
	_apply_audio_volumes()
	save()

func get_volume() -> int:
	return _bgm_volume

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
	var legacy_volume := int(config.get_value("audio", "volume", 100))
	set_bgm_volume(int(config.get_value("audio", "bgm_volume", legacy_volume)))
	set_sfx_volume(int(config.get_value("audio", "sfx_volume", legacy_volume)))
	set_ui_volume(int(config.get_value("audio", "ui_volume", legacy_volume)))
	set_fullscreen(config.get_value("display", "fullscreen", _fullscreen))
	_loading_settings = false

func save() -> void:
	if _loading_settings:
		return
	var config := ConfigFile.new()
	config.set_value("localization", "language", get_language())
	config.set_value("display", "text_speed", _text_speed)
	config.set_value("audio", "volume", _bgm_volume)
	config.set_value("audio", "bgm_volume", _bgm_volume)
	config.set_value("audio", "sfx_volume", _sfx_volume)
	config.set_value("audio", "ui_volume", _ui_volume)
	config.set_value("display", "fullscreen", _fullscreen)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_error("Cannot save settings: " + error_string(error))

func _apply_audio_volumes() -> void:
	_apply_bus_volume("BGM", _bgm_volume)
	_apply_bus_volume("SFX", _sfx_volume)
	_apply_bus_volume("UI", _ui_volume)

func _apply_bus_volume(bus_name: String, value: int) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_error("Required audio bus is missing: " + bus_name)
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value / 100.0))
