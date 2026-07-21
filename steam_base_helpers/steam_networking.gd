## steam_networking.gd
## -----------------------------------------------------------------------
## Autoload responsável pela ligação P2P via SteamMultiplayerPeer:
## criar host/cliente, spawn de carros, migração de host, e troca
## de pista sincronizada para todos os jogadores.
##
## Depende de "SteamHelpers" e "SteamLobbies" já estarem carregados.
## COMO USAR: adiciona como Autoload com o nome "SteamNetworking".
## -----------------------------------------------------------------------
extends Node

signal car_spawn_requested(peer_id: int)
signal car_despawn_requested(peer_id: int)
signal host_migration_started
signal host_migration_finished(am_i_the_new_host: bool)

## Muda para o caminho da cena do teu carro.
@export var car_scene_path: String = "res://cars/car.tscn"


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
## Spawn / despawn de carros
## ---------------------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	car_spawn_requested.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	car_despawn_requested.emit(peer_id)


## Chama isto no cliente assim que a pista estiver pronta, para pedires
## ao servidor que faça o teu spawn (útil quando entras a meio de uma
## corrida já em curso, ex: como espetador que decide juntar-se).
@rpc("any_peer", "call_local", "reliable")
func request_my_spawn() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	car_spawn_requested.emit(sender_id)


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
## Troca de pista sincronizada (escolher e carregar a pista de corrida)
## ---------------------------------------------------------------------

## Chama do lado do host para anunciar a pista escolhida na sala de espera
## (só atualiza a UI de pré-visualização, não troca de cena ainda).
func host_announce_track(track_path: String) -> void:
	if not multiplayer.is_server():
		return
	Steam.setLobbyData(SteamHelpers.lobby_id, "selected_track", track_path)
	_notify_track_selected.rpc(track_path)


@rpc("authority", "call_local", "reliable")
func _notify_track_selected(track_path: String) -> void:
	get_tree().call_group("track_preview_listeners", "on_track_selected", track_path)


## Chama do lado do host para mandar todos (incluindo ele próprio) carregar
## a mesma pista ao mesmo tempo. Depois de carregar, cada cliente pede o
## seu spawn e o host trata de arrancar a corrida (ver race_track.gd /
## RaceManager.start_race() — normalmente chamado após um pequeno delay
## para dar tempo a todos os carros aparecerem na grelha).
func host_start_race(track_path: String = "") -> void:
	if not multiplayer.is_server():
		return
	var path: String = track_path
	if path.is_empty():
		path = Steam.getLobbyData(SteamHelpers.lobby_id, "selected_track")
	if path.is_empty():
		printerr("[Networking] Nenhuma pista selecionada.")
		return
	_change_track_for_all.rpc(path)


@rpc("authority", "call_local", "reliable")
func _change_track_for_all(track_path: String) -> void:
	get_tree().change_scene_to_file(track_path)
	await get_tree().process_frame
	request_my_spawn.rpc_id(1)
