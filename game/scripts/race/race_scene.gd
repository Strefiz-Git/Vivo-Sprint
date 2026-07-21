extends Node3D

const CAR_SCENE: PackedScene = preload("res://scenes/vehicles/base_car.tscn")

@onready var players_node: Node3D = $Players
@onready var track: Node3D = $TestTrack


func _ready() -> void:
	logger.info("RaceScene", "Race scene loaded, spawning cars...")
	_spawn_player_car()


func _spawn_player_car() -> void:
	var car: VehicleBody3D = CAR_SCENE.instantiate()
	var peer_id: int = multiplayer.get_unique_id()
	car.name = str(peer_id)
	players_node.add_child(car, true)

	car.set_multiplayer_authority(peer_id)

	var track_node: Node3D = get_node_or_null("TestTrack")
	if track_node and track_node.has_method("get_start_position"):
		var grid_index: int = _get_grid_index()
		var start_xform: Transform3D = track_node.get_start_position(grid_index)
		car.global_transform = start_xform
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO
		logger.info("RaceScene", "Car spawned at grid %d for peer %d (authority=%d)" % [grid_index, peer_id, car.get_multiplayer_authority()])
	else:
		logger.warn("RaceScene", "Track not found or no get_start_position!")
		car.global_position = Vector3(0, 2, 0)


func _get_grid_index() -> int:
	if multiplayer.is_server():
		return 0
	var peers: Array = multiplayer.get_peers()
	peers.sort()
	var peer_id: int = multiplayer.get_unique_id()
	var index: int = peers.find(peer_id)
	return index + 1 if index >= 0 else 0
