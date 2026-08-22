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

var slot_buttons: Array[Button] = []
var pending_overwrite_id := 0
var pending_new_slot_id := 0


func _ready() -> void:
	slot_buttons = [save_1, save_2, save_3]
	for i in slot_buttons.size():
		var slot_id := i + 1
		slot_buttons[i].pressed.connect(_on_slot_pressed.bind(slot_id))
	close_button.pressed.connect(queue_free)
	overwrite_dialog.confirmed.connect(_confirm_overwrite)
	new_slot_dialog.confirmed.connect(_confirm_new_slot)
	refresh_slots()


func refresh_slots() -> void:
	var slots := SaveManager.get_slots()
	var slots_by_id := {}
	for slot in slots:
		slots_by_id[slot.id] = slot
	for i in slot_buttons.size():
		var slot_id := i + 1
		var button := slot_buttons[i]
		if slots_by_id.has(slot_id):
			var slot: Dictionary = slots_by_id[slot_id]
			var timestamp: Dictionary = slot.timestamp
			var time_text := "%04d-%02d-%02d %02d:%02d" % [
				timestamp.year, timestamp.month, timestamp.day,
				timestamp.hour, timestamp.minute
			]
			button.text = "%s\n%s\n%s | %s" % [
				slot.name, time_text, slot.scene, slot.timeline
			]
		else:
			button.text = "%d. 空" % slot_id


func _on_slot_pressed(slot_id: int) -> void:
	var slot := SaveManager.get_slot_meta(slot_id)
	if slot.is_empty():
		pending_new_slot_id = slot_id
		name_edit.text = ""
		new_slot_dialog.popup_centered()
	else:
		pending_overwrite_id = slot_id
		overwrite_dialog.dialog_text = "覆盖存档 %d（%s）？" % [slot_id, slot.name]
		overwrite_dialog.popup_centered()


func _confirm_overwrite() -> void:
	var slot := SaveManager.get_slot_meta(pending_overwrite_id)
	if SaveManager.save(pending_overwrite_id, slot.name):
		refresh_slots()


func _confirm_new_slot() -> void:
	var slot_name := name_edit.text.strip_edges()
	if slot_name.is_empty():
		slot_name = "存档 %d" % pending_new_slot_id
	if SaveManager.save(pending_new_slot_id, slot_name):
		refresh_slots()
