extends Node2D #场景1一开始就播放第一段对话

const ENDING_TIMELINE_PATH := "res://timelines/09_ending.dtl"
const MAIN_MENU_PATH := "res://scenes/mainMenu.tscn"

var _active_timeline_path := ""
var _returning_to_menu := false


func _ready() -> void:
	Dialogic.timeline_started.connect(_on_timeline_started)
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	VisualFX.set_dialog_text_speed_on_timeline_start()
	Dialogic.start("00_start")


func _exit_tree() -> void:
	if Dialogic.timeline_started.is_connected(_on_timeline_started):
		Dialogic.timeline_started.disconnect(_on_timeline_started)
	if Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.disconnect(_on_timeline_ended)


func _on_timeline_started() -> void:
	if Dialogic.current_timeline == null:
		_active_timeline_path = ""
		return
	_active_timeline_path = Dialogic.current_timeline.resource_path


func _on_timeline_ended() -> void:
	var ended_timeline_path := _active_timeline_path
	_active_timeline_path = ""
	if ended_timeline_path != ENDING_TIMELINE_PATH or _returning_to_menu:
		return
	_returning_to_menu = true
	call_deferred("_return_to_main_menu")


func _return_to_main_menu() -> void:
	var error := get_tree().change_scene_to_file(MAIN_MENU_PATH)
	if error != OK:
		push_error("故事结束后返回主菜单失败，错误码: %s" % error)
