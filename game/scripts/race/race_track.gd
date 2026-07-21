extends Node3D

@export var default_laps: int = 3

var _checkpoints: Array[Area3D] = []


func _ready() -> void:
	_discover_checkpoints()
	if _checkpoints.size() != 3:
		logger.error("RaceTrack", "Needs exactly 3 checkpoints (has %d)" % _checkpoints.size())
		return
	for sector_index in range(_checkpoints.size()):
		var area: Area3D = _checkpoints[sector_index]
		if area:
			area.body_entered.connect(_on_checkpoint_entered.bind(sector_index))
		else:
			logger.error("RaceTrack", "Checkpoint sector %d not found" % sector_index)


func _discover_checkpoints() -> void:
	var checkpoints_node: Node3D = get_node_or_null("Checkpoints")
	if checkpoints_node:
		for child in checkpoints_node.get_children():
			if child is Area3D:
				_checkpoints.append(child)
	_checkpoints.sort_custom(func(a, b):
		return a.name < b.name
	)


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
	var grid_positions: Node3D = get_node_or_null("GridPositions")
	if not grid_positions:
		return global_transform
	var children: Array[Node] = grid_positions.get_children()
	if grid_index < 0 or grid_index >= children.size():
		return global_transform
	var marker: Node3D = children[grid_index]
	return marker.global_transform if marker else global_transform
