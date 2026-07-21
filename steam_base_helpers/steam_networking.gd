## steam_networking.gd
## -----------------------------------------------------------------------
## Autoload responsável pela ligação P2P via SteamMultiplayerPeer:
## criar host/cliente, spawn de jogadores, migração de host, e troca
## de cena sincronizada para todos os jogadores.
##
## Depende de "SteamHelpers" e "SteamLobbies" já estarem carregados.
## COMO USAR: adiciona como Autoload com o nome "SteamNetworking".
## -----------------------------------------------------------------------
extends Node

signal player_spawn_requested(peer_id: int)
signal player_despawn_requested(peer_id: int)
signal host_migration_started
signal host_migration_finished(am_i_the_new_host: bool)

## Muda para o caminho da cena do teu jogador.
@export var player_scene_path: String = "res://player/player.tscn"


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## ---------------------------------------------------------------------
## Criar Host / Ligar como Cliente
## ---------------------------------------------------------------------

## Chama isto depois de a lobby ser criada com sucesso (SteamLobbies.lobby_created_successfully).
func start_as_host() -> void:
	var peer: SteamMultiplayerPeer = SteamMultiplayerPeer.new()
	peer.create_host(0)
	peer.server_relay = true
	multiplayer.set_multiplayer_peer(peer)
	print("[Networking] A funcionar como host (peer id = 1)")


## Chama isto depois de entrar numa lobby (SteamLobbies.lobby_joined_successfully),
## se NÃO fores o dono da lobby.
func start_as_client(host_steam_id: int) -> void:
	var peer: SteamMultiplayerPeer = SteamMultiplayerPeer.new()
	peer.create_client(host_steam_id, 0)
	peer.server_relay = true
	multiplayer.set_multiplayer_peer(peer)
	print("[Networking] A ligar como cliente ao host %s" % host_steam_id)


func stop_networking() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.set_multiplayer_peer(null)


## ---------------------------------------------------------------------
## Spawn / despawn de jogadores
## ---------------------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	player_spawn_requested.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	player_despawn_requested.emit(peer_id)


## Chama isto no cliente assim que a cena de jogo estiver pronta, para
## pedires ao servidor que faça o teu spawn (útil quando entras a meio
## de uma partida já em curso).
@rpc("any_peer", "call_local", "reliable")
func request_my_spawn() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	player_spawn_requested.emit(sender_id)


## ---------------------------------------------------------------------
## Migração de Host
## ---------------------------------------------------------------------

func _on_server_disconnected() -> void:
	host_migration_started.emit()

	# O Steam já escolheu automaticamente um novo dono para a lobby.
	var new_owner_id: int = Steam.getLobbyOwner(SteamHelpers.lobby_id)
	var i_am_new_host: bool = new_owner_id == SteamHelpers.steam_id

	if i_am_new_host:
		start_as_host()
	else:
		# Pequena espera para dar tempo ao novo host de preparar o servidor.
		await get_tree().create_timer(1.0).timeout
		start_as_client(new_owner_id)

	host_migration_finished.emit(i_am_new_host)


## ---------------------------------------------------------------------
## Troca de cena sincronizada (ex: escolher e carregar o mapa)
## ---------------------------------------------------------------------

## Chama do lado do host para anunciar o mapa escolhido na sala de espera
## (só atualiza a UI de pré-visualização, não troca de cena ainda).
func host_announce_map(map_path: String) -> void:
	if not multiplayer.is_server():
		return
	Steam.setLobbyData(SteamHelpers.lobby_id, "selected_map", map_path)
	_notify_map_selected.rpc(map_path)


@rpc("authority", "call_local", "reliable")
func _notify_map_selected(map_path: String) -> void:
	get_tree().call_group("map_preview_listeners", "on_map_selected", map_path)


## Chama do lado do host para mandar todos (incluindo ele próprio) carregar
## a mesma cena ao mesmo tempo.
func host_start_game() -> void:
	if not multiplayer.is_server():
		return
	var map_path: String = Steam.getLobbyData(SteamHelpers.lobby_id, "selected_map")
	if map_path.is_empty():
		map_path = player_scene_path.get_base_dir()  # fallback, ajusta conforme o teu projeto
	_change_scene_for_all.rpc(map_path)


@rpc("authority", "call_local", "reliable")
func _change_scene_for_all(map_path: String) -> void:
	get_tree().change_scene_to_file(map_path)
	await get_tree().process_frame
	request_my_spawn.rpc_id(1)
