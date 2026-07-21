extends Control

@onready var results_list: VBoxContainer = $Panel/VBox/ResultsList
@onready var back_button: Button = $Panel/VBox/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	race_manager.race_finished.connect(_on_race_finished)


func _on_race_finished(finishing_order: Array) -> void:
	for child in results_list.get_children():
		child.queue_free()
	for i in range(finishing_order.size()):
		var car_id: int = finishing_order[i]
		var progress: Dictionary = race_manager.get_car_progress(car_id)
		var label := Label.new()
		var name_str: String = str(car_id)
		for p in globals.players:
			if p.steam_id == car_id:
				name_str = p.name
				break
		var best_lap: String = _format_time(progress.get("best_lap_ms", 0))
		label.text = "%dº  %s  |  Melhor volta: %s" % [i + 1, name_str, best_lap]
		results_list.add_child(label)


func _on_back_pressed() -> void:
	scene_manager.goto_scene("res://scenes/ui/main_menu.tscn")


func _format_time(ms: int) -> String:
	if ms <= 0:
		return "--:--.---"
	var total_seconds: float = ms / 1000.0
	var minutes: int = int(total_seconds) / 60
	var seconds: float = fmod(total_seconds, 60.0)
	return "%02d:%06.3f" % [minutes, seconds]
