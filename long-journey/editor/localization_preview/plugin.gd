@tool
extends EditorPlugin

const DEFAULT_LOCALE := "zh_CN"


func _enter_tree() -> void:
	var settings := EditorInterface.get_editor_settings()
	if str(settings.get_project_metadata("editor_metadata", "preview_locale", "")).is_empty():
		_enable_chinese_preview.call_deferred()


func _enable_chinese_preview() -> void:
	# Use Godot's native command so resource watching and preview controls stay in sync.
	var menus := EditorInterface.get_base_control().find_children("*", "EditorTranslationPreviewMenu", true, false)
	if menus.is_empty():
		push_error("Chinese preview requires Godot 4.7's EditorTranslationPreviewMenu")
		return
	var menu := menus[0] as PopupMenu
	menu.about_to_popup.emit()
	for index in menu.item_count:
		if str(menu.get_item_metadata(index)) == DEFAULT_LOCALE:
			menu.index_pressed.emit(index)
			return
	push_error("Chinese preview is missing the registered zh_CN translation")
