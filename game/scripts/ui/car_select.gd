extends Control

@onready var car_name_label: Label = $CarName
@onready var prev_button: Button = $PrevButton
@onready var next_button: Button = $NextButton
@onready var confirm_button: Button = $ConfirmButton

var _car_configs: Array[Dictionary] = []
var _current_index: int = 0


func _ready() -> void:
	prev_button.pressed.connect(_on_prev)
	next_button.pressed.connect(_on_next)
	confirm_button.pressed.connect(_on_confirm)
	_load_car_configs()
	_update_display()


func _load_car_configs() -> void:
	var dir := DirAccess.open("res://config/cars/")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var file := FileAccess.open("res://config/cars/" + file_name, FileAccess.READ)
			if file:
				var json := JSON.new()
				var err := json.parse(file.get_as_text())
				if err == OK:
					_car_configs.append(json.data)
				file.close()
		file_name = dir.get_next()
	dir.list_dir_end()


func _update_display() -> void:
	if _car_configs.is_empty():
		car_name_label.text = "Nenhum carro encontrado"
		return
	var car: Dictionary = _car_configs[_current_index]
	car_name_label.text = car.get("name", "Carro %d" % (_current_index + 1))


func _on_prev() -> void:
	if _car_configs.is_empty():
		return
	_current_index = (_current_index - 1 + _car_configs.size()) % _car_configs.size()
	_update_display()


func _on_next() -> void:
	if _car_configs.is_empty():
		return
	_current_index = (_current_index + 1) % _car_configs.size()
	_update_display()


func _on_confirm() -> void:
	if _car_configs.is_empty():
		return
	var car: Dictionary = _car_configs[_current_index]
	globals.local_player.car_index = _current_index
	scene_manager.goto_scene("res://scenes/ui/lobby_screen.tscn")
