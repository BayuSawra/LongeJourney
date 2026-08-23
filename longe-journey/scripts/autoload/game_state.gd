extends Node

## GameState 是 Dialogic 变量的统一镜像层。
## timeline 内继续用 Dialogic 原生 {} 变量；外部代码统一经 GameState 读写。

signal value_changed(variable: String, new_value: Variant)

var energy: int = 100
var calm: int = 100
var money: int = 20
var earthworm: int = 0
var flower: int = 0
var wife: int = 0
var hualan: bool = false
var jiahua: bool = false
var player_name: String = "无名王"
var visit_huadian: int = 0
var visit_shiling: int = 0
var visit_luyuan: int = 0
var visit_ting_shifang: int = 0


func _ready() -> void:
	if not Dialogic.VAR.variable_changed.is_connected(_on_dialogic_variable_changed):
		Dialogic.VAR.variable_changed.connect(_on_dialogic_variable_changed)


func get_var(variable_name: String) -> Variant:
	return get(variable_name)


func set_var(variable_name: String, value: Variant) -> void:
	if Dialogic.VAR.set_variable(variable_name, value):
		set(variable_name, value)
		value_changed.emit(variable_name, value)


func _on_dialogic_variable_changed(info: Dictionary) -> void:
	var variable: String = info.get("variable", "")
	if _has_property(variable):
		set(variable, info.get("new_value"))
		value_changed.emit(variable, get(variable))


func _has_property(property_name: String) -> bool:
	for property in get_property_list():
		if property["name"] == property_name:
			return true
	return false
