extends Control #从开始界面跳转到场景1

func _on_button_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/scene_1.tscn")


func _on_button_save_pressed() -> void:
	var panel: PackedScene = load("res://scenes/save_slot_panel.tscn")
	if panel == null:
		return
	add_child(panel.instantiate())
