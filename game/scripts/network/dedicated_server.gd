extends Node

var config: Dictionary = {}
var connected_players: Dictionary = {}

func _ready() -> void:
	if not (OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_args()):
		return
	config = server_config.load_config()
	logger.info("DedicatedServer", "Config loaded: %s" % config)
	_start_network()
	_connect_signals()
	logger.info("DedicatedServer", "'%s' running on port %s (max %s players)" % [
		config["name"], config["port"], config["max_players"]
	])

func _start_network() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err: int = peer.create_server(config["port"], config["max_players"])
	if err != OK:
		logger.error("DedicatedServer", "Failed to open port %s (error %s)" % [config["port"], err])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer

func _connect_signals() -> void:
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)

func _on_player_connected(id: int) -> void:
	logger.info("DedicatedServer", "Player connected: %s" % id)
	connected_players[id] = {}
	if not config.get("password", "").is_empty():
		get_tree().create_timer(5.0).timeout.connect(_check_password_timeout.bind(id))

func _check_password_timeout(id: int) -> void:
	if connected_players.has(id) and not connected_players[id].get("authenticated", false):
		logger.warn("DedicatedServer", "Player %s did not authenticate in time" % id)
		multiplayer.multiplayer_peer.disconnect_peer(id)

@rpc("any_peer", "call_remote", "reliable")
func submit_password(attempt: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var expected: String = config.get("password", "")
	if expected.is_empty() or attempt.sha256_text() == expected.sha256_text():
		connected_players[sender_id] = {"authenticated": true}
		logger.info("DedicatedServer", "Player %s authenticated" % sender_id)
	else:
		logger.warn("DedicatedServer", "Wrong password from %s" % sender_id)
		multiplayer.multiplayer_peer.disconnect_peer(sender_id)

func _on_player_disconnected(id: int) -> void:
	logger.info("DedicatedServer", "Player disconnected: %s" % id)
	connected_players.erase(id)
