extends Node3D

const CAR_SCENE: PackedScene = preload("res://scenes/vehicles/base_car.tscn")

@onready var players_node: Node3D = $Players
@onready var track: Node3D = $TestTrack


func _ready() -> void:
	logger.info("RaceScene", "Race scene loaded")
	_spawn_player_car()


func _spawn_player_car() -> void:
	var car: VehicleBody3D = CAR_SCENE.instantiate()
	var peer_id: int = multiplayer.get_unique_id()
	car.name = str(peer_id)
	car.set_multiplayer_authority(peer_id)
	players_node.add_child(car, true)

	var track_node: Node3D = get_node_or_null("TestTrack")
	if track_node and track_node.has_method("get_start_position"):
		var grid_index: int = _get_grid_index()
		car.teleport_to(track_node.get_start_position(grid_index))

	logger.info("RaceScene", "Spawned car for peer %d" % peer_id)


func _get_grid_index() -> int:
	var peer_id: int = multiplayer.get_unique_id()
	if multiplayer.is_server():
		return 0
	var peers: Array = multiplayer.get_peers()
	peers.sort()
	var index: int = peers.find(peer_id)
	return index + 1 if index >= 0 else 0
