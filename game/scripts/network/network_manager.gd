extends Node

const DEFAULT_PORT: int = 27015
const MAX_PLAYERS: int = 20

var peer: ENetMultiplayerPeer = null
var is_server: bool = false
var is_client: bool = false
var server_ip: String = "127.0.0.1"

signal server_started(port: int)
signal server_start_failed(reason: String)
signal client_connected()
signal client_disconnected(reason: String)
signal player_connected(id: int)
signal player_disconnected(id: int)

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func start_server(port: int = DEFAULT_PORT, max_players: int = MAX_PLAYERS):
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, max_players)
	if err != OK:
		server_start_failed.emit("Failed to create server: %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	is_server = true
	is_client = false
	server_started.emit(port)

func stop_server():
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
	is_server = false

func connect_to_server(ip: String = "127.0.0.1", port: int = DEFAULT_PORT):
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		client_disconnected.emit("Failed to connect: %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	is_client = true
	is_server = false
	server_ip = ip

func disconnect_from_server():
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
	is_client = false

func get_player_list() -> Array[int]:
	var ids: Array[int] = []
	ids.append(multiplayer.get_unique_id())
	for id in multiplayer.get_peers():
		ids.append(id)
	return ids

func is_multiplayer_active() -> bool:
	return peer != null and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED

func _on_player_connected(id: int):
	player_connected.emit(id)

func _on_player_disconnected(id: int):
	player_disconnected.emit(id)

func _on_connected_to_server():
	client_connected.emit()

func _on_connection_failed():
	client_disconnected.emit("Connection failed")

func _on_server_disconnected():
	client_disconnected.emit("Server disconnected")
	is_client = false

func start_dedicated_server(port: int = DEFAULT_PORT):
	start_server(port, MAX_PLAYERS)
