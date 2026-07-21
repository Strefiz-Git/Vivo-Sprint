extends Node3D

@export var checkpoints: Array[NodePath] = []
@export var default_laps: int = 3
@export var start_positions: Array[NodePath] = []


func _ready() -> void:
	if checkpoints.size() != 3:
		logger.error("RaceTrack", "Needs exactly 3 checkpoints (has %d)" % checkpoints.size())
		return
	for sector_index in range(checkpoints.size()):
		var area: Area3D = get_node(checkpoints[sector_index])
		if area:
			area.body_entered.connect(_on_checkpoint_entered.bind(sector_index))
		else:
			logger.error("RaceTrack", "Checkpoint sector %d not found" % sector_index)


func _on_checkpoint_entered(body: Node, sector_index: int) -> void:
	if not multiplayer.is_server():
		return
	if not body.is_in_group("race_car"):
		return
	var car_id: int = body.get_multiplayer_authority()
	race_manager.report_checkpoint_crossed(car_id, sector_index)


func start_race(laps: int = -1) -> void:
	if not multiplayer.is_server():
		return
	var laps_to_use: int = default_laps if laps < 0 else laps
	for car in get_tree().get_nodes_in_group("race_car"):
		race_manager.register_car(car.get_multiplayer_authority())
	race_manager.start_race(laps_to_use)


func get_start_position(grid_index: int) -> Transform3D:
	if grid_index < 0 or grid_index >= start_positions.size():
		return global_transform
	var marker: Node3D = get_node(start_positions[grid_index])
	return marker.global_transform if marker else global_transform
