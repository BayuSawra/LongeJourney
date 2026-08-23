extends CanvasLayer

const FONT_PATH := "res://font/HYZIKUTANGJINGJIEKAITIW.TTF"

var _list_box: VBoxContainer
var _title_label: Label
var _back_button: Button


func _ready() -> void:
	_list_box = %ListBox
	_title_label = %LabelTitle
	_back_button = %ButtonBack
	%ButtonBack.pressed.connect(_on_back_pressed)
	%ButtonClose.pressed.connect(_close)
	_show_categories()


func _show_categories() -> void:
	_back_button.visible = false
	_title_label.text = "图鉴"
	_clear_list()
	for category in LoreRuntime.get_categories():
		var button := Button.new()
		button.text = "%s（%d）" % [category.label, category.count]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_show_category.bind(category.key))
		_apply_font(button)
		_list_box.add_child(button)

	if _list_box.get_child_count() == 0:
		_add_empty_label()


func _show_category(category_key: String) -> void:
	_back_button.visible = true
	var entries := LoreRuntime.get_category(category_key)
	var category_label := ""
	for category in LoreRuntime.get_categories():
		if category.key == category_key:
			category_label = category.label
			break
	_title_label.text = category_label
	_clear_list()

	for entry in entries:
		var entry_title := Label.new()
		entry_title.text = entry.title
		entry_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_font(entry_title)
		_list_box.add_child(entry_title)

		if not entry.summary.is_empty():
			var summary := Label.new()
			summary.text = entry.summary
			summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			summary.modulate = Color(0.72, 0.72, 0.72)
			_apply_font(summary)
			_list_box.add_child(summary)

	if _list_box.get_child_count() == 0:
		_add_empty_label()


func _on_back_pressed() -> void:
	_show_categories()


func _close() -> void:
	queue_free()


func _clear_list() -> void:
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()


func _add_empty_label() -> void:
	var empty_label := Label.new()
	empty_label.text = "暂无条目"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(empty_label)
	_list_box.add_child(empty_label)


func _apply_font(node: Control) -> void:
	var font := load(FONT_PATH) as Font
	if font != null:
		node.add_theme_font_override("font", font)
