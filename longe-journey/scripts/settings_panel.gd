extends CanvasLayer

@onready var language_option: OptionButton = %LanguageOption

@onready var text_speed_slider: HSlider = %TextSpeedSlider
@onready var bgm_volume_slider: HSlider = %BgmVolumeSlider
@onready var sfx_volume_slider: HSlider = %SfxVolumeSlider
@onready var ui_volume_slider: HSlider = %UiVolumeSlider
@onready var text_speed_value: Label = %TextSpeedValue
@onready var bgm_volume_value: Label = %BgmVolumeValue
@onready var sfx_volume_value: Label = %SfxVolumeValue
@onready var ui_volume_value: Label = %UiVolumeValue
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var close_button: Button = %CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for language in Localization.supported_locales():
		language_option.add_item(Localization.language_name(language))
		language_option.set_item_metadata(language_option.item_count - 1, language)
		if language == SettingsManager.get_language():
			language_option.select(language_option.item_count - 1)
	language_option.item_selected.connect(func(index: int) -> void:
		SettingsManager.set_language(language_option.get_item_metadata(index)))

	text_speed_slider.value = SettingsManager.get_text_speed()
	bgm_volume_slider.value = SettingsManager.get_bgm_volume()
	sfx_volume_slider.value = SettingsManager.get_sfx_volume()
	ui_volume_slider.value = SettingsManager.get_ui_volume()
	fullscreen_check.button_pressed = SettingsManager.get_fullscreen()
	text_speed_slider.value_changed.connect(
		func(value: float) -> void:
			text_speed_value.text = str(int(value))
			SettingsManager.set_text_speed(value)
	)
	bgm_volume_slider.value_changed.connect(
		func(value: float) -> void:
			bgm_volume_value.text = "%d%%" % int(value)
			SettingsManager.set_bgm_volume(int(value))
	)
	sfx_volume_slider.value_changed.connect(
		func(value: float) -> void:
			sfx_volume_value.text = "%d%%" % int(value)
			SettingsManager.set_sfx_volume(int(value))
	)
	ui_volume_slider.value_changed.connect(
		func(value: float) -> void:
			ui_volume_value.text = "%d%%" % int(value)
			SettingsManager.set_ui_volume(int(value))
	)
	fullscreen_check.toggled.connect(
		func(enabled: bool) -> void: SettingsManager.set_fullscreen(enabled)
	)
	close_button.pressed.connect(func() -> void: SettingsManager.close_settings())
	text_speed_value.text = str(int(text_speed_slider.value))
	bgm_volume_value.text = "%d%%" % int(bgm_volume_slider.value)
	sfx_volume_value.text = "%d%%" % int(sfx_volume_slider.value)
	ui_volume_value.text = "%d%%" % int(ui_volume_slider.value)
