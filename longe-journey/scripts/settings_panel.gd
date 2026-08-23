extends CanvasLayer

@onready var text_speed_slider: HSlider = %TextSpeedSlider
@onready var volume_slider: HSlider = %VolumeSlider
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var close_button: Button = %CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	text_speed_slider.value = SettingsManager.get_text_speed()
	volume_slider.value = SettingsManager.get_volume()
	fullscreen_check.button_pressed = SettingsManager.get_fullscreen()
	text_speed_slider.value_changed.connect(
		func(value: float) -> void: SettingsManager.set_text_speed(value)
	)
	volume_slider.value_changed.connect(
		func(value: float) -> void: SettingsManager.set_volume(int(value))
	)
	fullscreen_check.toggled.connect(
		func(enabled: bool) -> void: SettingsManager.set_fullscreen(enabled)
	)
	close_button.pressed.connect(func() -> void: SettingsManager.close_settings())
