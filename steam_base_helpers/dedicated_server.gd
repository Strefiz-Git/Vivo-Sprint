## dedicated_server.gd
## -----------------------------------------------------------------------
## Script principal de um SERVIDOR DEDICADO headless (sem gráficos).
## Usa este script como a cena/autoload principal na build exportada com
## "Export as dedicated server" (Godot 4, --headless).
##
## Usa ENetMultiplayerPeer (NÃO SteamMultiplayerPeer — ainda não suportado
## em builds de servidor dedicado do GodotSteam). O Steam é opcional aqui,
## só para listagem pública / Game Server, se quiseres.
##
## Lê a configuração de um ficheiro server.cfg ao lado do executável
## (ver server_config.gd) e/ou de argumentos de linha de comandos.
## -----------------------------------------------------------------------
extends Node

var config: Dictionary = {}
var connected_players: Dictionary = {}  # peer_id -> nome/dados


func _ready() -> void:
	if not (OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_args()):
		print("[Server] Este script destina-se a correr como servidor dedicado. A sair.")
		return

	config = ServerConfig.load_config()
	print("[Server] Configuração carregada: %s" % config)

	_start_network()
	_connect_signals()

	print("[Server] '%s' a correr na porta %s (máx %s jogadores)" % [
		config["name"], config["port"], config["max_players"]
	])


func _start_network() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err: int = peer.create_server(config["port"], config["max_players"])
	if err != OK:
		printerr("[Server] Não foi possível abrir a porta %s (erro %s)" % [config["port"], err])
		get_tree().quit(1)
		return
	multiplayer.set_multiplayer_peer(peer)


func _connect_signals() -> void:
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)


func _on_player_connected(id: int) -> void:
	print("[Server] Jogador ligou-se: %s" % id)
	connected_players[id] = {}
	if not config.get("password", "").is_empty():
		# Dá alguns segundos para o cliente enviar a password antes de o kickares.
		get_tree().create_timer(5.0).timeout.connect(_check_password_timeout.bind(id))


func _check_password_timeout(id: int) -> void:
	if connected_players.has(id) and not connected_players[id].get("authenticated", false):
		print("[Server] Jogador %s não autenticou a tempo, a desligar." % id)
		multiplayer.multiplayer_peer.disconnect_peer(id)


@rpc("any_peer", "call_remote", "reliable")
func submit_password(attempt: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var expected: String = config.get("password", "")

	if expected.is_empty() or attempt.sha256_text() == expected.sha256_text():
		connected_players[sender_id] = {"authenticated": true}
		print("[Server] Jogador %s autenticado." % sender_id)
	else:
		print("[Server] Password errada de %s, a desligar." % sender_id)
		multiplayer.multiplayer_peer.disconnect_peer(sender_id)


func _on_player_disconnected(id: int) -> void:
	print("[Server] Jogador desligou-se: %s" % id)
	connected_players.erase(id)
	# Aqui é onde removerias o nó do jogador da cena, se este servidor
	# também gerir a simulação do jogo (ver player_spawn_requested em
	# steam_networking.gd para um exemplo de padrão de spawn/despawn).
