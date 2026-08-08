extends Node2D #场景1一开始就播放第一段对话

func _ready() -> void:
	Dialogic.start("timeline1_0")
