extends Node2D #场景1一开始就播放第一段对话

func _ready() -> void:
	VisualFX.set_dialog_text_speed_on_timeline_start()
	Dialogic.start("00_start")
