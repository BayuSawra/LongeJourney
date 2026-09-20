extends CanvasLayer

const SAVE_SCENE := "res://scenes/save_slot_panel.tscn"

@onready var title_label: Label = %TitleLabel
@onready var save_1: Button = %Save1
@onready var save_2: Button = %Save2
@onready var save_3: Button = %Save3
@onready var close_button: Button = %CloseButton
@onready var overwrite_dialog: AcceptDialog = %OverwriteDialog
@onready var new_slot_dialog: ConfirmationDialog = %NewSlotDialog
@onready var name_edit: LineEdit = %NameEdit
@onready var load_dialog: AcceptDialog = %LoadDialog

var slot_buttons: Array[Button] = []
var pending_overwrite_id := 0
var pending_new_slot_id := 0
var load_mode := false
var pending_load_id := 0


func _ready() -> void:
	title_label.text = Localization.text("save.load_title" if load_mode else "save.title")
	slot_buttons = [save_1, save_2, save_3]
	for i in slot_buttons.size():
		var slot_id := i + 1
		slot_buttons[i].pressed.connect(_on_slot_pressed.bind(slot_id))
	close_button.pressed.connect(queue_free)
	overwrite_dialog.confirmed.connect(_confirm_overwrite)
	new_slot_dialog.confirmed.connect(_confirm_new_slot)
	load_dialog.confirmed.connect(_confirm_load)
	Localization.locale_changed.connect(refresh_slots)
	refresh_slots()


func refresh_slots() -> void:
	title_label.text = Localization.text("save.load_title" if load_mode else "save.title")
	for dialog in [overwrite_dialog, new_slot_dialog, load_dialog]:
		dialog.get_ok_button().text = Localization.text("save.confirm")
	new_slot_dialog.get_cancel_button().text = Localization.text("save.cancel")
	var slots := SaveManager.get_slots()
	var slots_by_id := {}
	for slot in slots:
		slots_by_id[str(slot.id)] = slot
	for i in slot_buttons.size():
		var slot_id := i + 1
		var button := slot_buttons[i]
		if slots_by_id.has(str(slot_id)):
			var slot: Dictionary = slots_by_id[str(slot_id)]
			var timestamp: Dictionary = slot.timestamp
			var time_text := "%04d-%02d-%02d %02d:%02d" % [
				timestamp.year, timestamp.month, timestamp.day,
				timestamp.hour, timestamp.minute
			]
			button.text = Localization.format_text("save.details", {
				"name": SaveManager.display_name(str(slot_id), slot.name), "time": time_text,
				"scene": Localization.text("save.scene." + str(slot.scene).get_file().get_basename()) if not str(slot.scene).is_empty() else Localization.text("save.location_unknown"),
				"timeline": Localization.text("save.timeline." + str(slot.timeline).get_file().get_basename()) if not str(slot.timeline).is_empty() else Localization.text("save.location_unknown"),
			})
		else:
			button.text = Localization.format_text("save.empty", {"slot": slot_id})

	if overwrite_dialog.visible:
		var slot := SaveManager.get_slot_meta(str(pending_overwrite_id))
		overwrite_dialog.dialog_text = Localization.format_text("save.confirm_overwrite", {"slot": pending_overwrite_id, "name": SaveManager.display_name(str(pending_overwrite_id), slot.name)})
	if load_dialog.visible:
		var slot := SaveManager.get_slot_meta(str(pending_load_id))
		load_dialog.dialog_text = Localization.format_text("save.confirm_load", {"name": SaveManager.display_name(str(pending_load_id), slot.name)})


func _on_slot_pressed(slot_id: int) -> void:
	var slot := SaveManager.get_slot_meta(str(slot_id))
	if slot.is_empty():
		if load_mode:
			return
		pending_new_slot_id = slot_id
		name_edit.text = ""
		new_slot_dialog.popup_centered()
	else:
		if load_mode:
			pending_load_id = slot_id
			load_dialog.dialog_text = Localization.format_text("save.confirm_load", {"name": SaveManager.display_name(str(slot_id), slot.name)})
			load_dialog.popup_centered()
			return
		pending_overwrite_id = slot_id
		overwrite_dialog.dialog_text = Localization.format_text("save.confirm_overwrite", {"slot": slot_id, "name": SaveManager.display_name(str(slot_id), slot.name)})
		overwrite_dialog.popup_centered()


func _confirm_overwrite() -> void:
	var slot := SaveManager.get_slot_meta(str(pending_overwrite_id))
	if SaveManager.save(str(pending_overwrite_id), slot.name):
		refresh_slots()


func _confirm_new_slot() -> void:
	var slot_name := name_edit.text.strip_edges()
	if SaveManager.save(str(pending_new_slot_id), slot_name):
		refresh_slots()


func _confirm_load() -> void:
	if await SaveManager.load(str(pending_load_id)):
		refresh_slots()
	else:
		var error_dialog := AcceptDialog.new()
		error_dialog.title = "save.error_title"
		error_dialog.dialog_text = SaveManager.last_error
		error_dialog.get_ok_button().text = "save.confirm"
		error_dialog.confirmed.connect(error_dialog.queue_free)
		error_dialog.canceled.connect(error_dialog.queue_free)
		add_child(error_dialog)
		error_dialog.popup_centered()
