extends Node

var initialized: bool = false
var steam_id: int = 0
var steam_name: String = "Offline"
var lobby_id: int = 0
var is_host: bool = false

var _debug_time: float = 0.0
var _pending_callbacks: Array[String] = []

signal steam_ready(steam_id: int, name: String)
signal steam_init_failed(reason: String)
signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int)
signal lobby_join_failed(reason: String)
signal lobby_left()
signal member_joined(steam_id: int)
signal member_left(steam_id: int)
signal lobby_data_updated(key: String, value: String)
signal lobby_list_received(lobbies: Array)

func _ready():
	logger.info("SteamManager", "A inicializar Steam...")
	var init_result = Steam.steamInitEx()
	logger.info("SteamManager", "steamInitEx result: %s" % init_result)
	if init_result is Dictionary and init_result.get("status", -1) == 0:
		_steam_init_success()
	else:
		_steam_init_offline()
	_connect_steam_signals()
	if initialized:
		get_tree().create_timer(5.0).timeout.connect(_debug_status)

func _connect_steam_signals():
	logger.info("SteamManager", "A ligar sinais Steam...")
	var signal_list = Steam.get_signal_list()
	for s in signal_list:
		logger.debug("SteamManager", "  Sinal Steam: %s" % s.name)
	var lobby_signals = ["lobby_created", "lobby_joined", "lobby_match_list", "lobby_chat_update", "lobby_data_update", "lobby_invite"]
	for sig_name in lobby_signals:
		if Steam.has_signal(sig_name):
			Steam.connect(sig_name, Callable(self, "_on_" + sig_name))
			logger.info("SteamManager", "-> %s ligado" % sig_name)
	# join_lobby_requested / lobby_join_requested
	for alt_name in ["join_lobby_requested", "lobby_join_requested", "join_requested"]:
		if Steam.has_signal(alt_name):
			Steam.connect(alt_name, Callable(self, "_on_lobby_join_requested"))
			logger.info("SteamManager", "-> %s ligado" % alt_name)
	logger.info("SteamManager", "Sinais ligados.")

func _debug_status():
	logger.info("SteamManager", "=== DEBUG: lobby_id=%s is_host=%s initialized=%s pendentes=%s ===" % [lobby_id, is_host, initialized, _pending_callbacks])

func _process(delta):
	_debug_time += delta
	if _debug_time >= 10.0:
		_debug_time = 0.0
		if initialized:
			_checar_callback_pendente("lobby_created")
			_checar_callback_pendente("lobby_match_list")

func _checar_callback_pendente(tipo: String):
	if tipo in _pending_callbacks:
		logger.warn("SteamManager", "AINDA A ESPERAR callback %s após %s segundos!" % [tipo, _debug_time])

func _steam_init_success():
	initialized = true
	steam_id = Steam.getSteamID()
	steam_name = Steam.getFriendPersonaName(steam_id)
	logger.info("SteamManager", "Steam OK! ID: %s, Nome: %s" % [steam_id, steam_name])
	Steam.setAchievement("tester")
	Steam.storeStats()
	steam_ready.emit(steam_id, steam_name)

func _steam_init_offline():
	initialized = false
	steam_name = "Offline"
	logger.warn("SteamManager", "Steam offline. Só modo local.")
	steam_init_failed.emit("Steam not running or steam_appid.txt not found")

func is_on_steam() -> bool:
	return initialized

func create_lobby(visibility: int = Steam.LOBBY_TYPE_PUBLIC, max_players: int = 12):
	if not initialized:
		logger.warn("SteamManager", "Tentou criar lobby mas Steam offline")
		return
	logger.info("SteamManager", "A criar lobby... visibilidade=%s max=%s" % [visibility, max_players])
	var ret = Steam.createLobby(visibility, max_players)
	logger.info("SteamManager", "createLobby retornou: %s" % ret)
	_pending_callbacks.append("lobby_created")

func join_lobby(target_lobby_id: int):
	if not initialized:
		return
	logger.info("SteamManager", "A entrar no lobby %s..." % target_lobby_id)
	Steam.joinLobby(target_lobby_id)

func leave_lobby():
	if lobby_id == 0:
		return
	logger.info("SteamManager", "A sair do lobby %s" % lobby_id)
	Steam.leaveLobby(lobby_id)
	lobby_id = 0
	is_host = false
	lobby_left.emit()

func request_lobby_list():
	if not initialized:
		logger.warn("SteamManager", "Tentou procurar lobbies mas Steam offline")
		return
	logger.info("SteamManager", "A procurar lobbies...")
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_DEFAULT)
	Steam.addRequestLobbyListResultCountFilter(50)
	var ret = Steam.requestLobbyList()
	logger.info("SteamManager", "requestLobbyList retornou: %s" % ret)
	_pending_callbacks.append("lobby_match_list")

func set_lobby_data(key: String, value: String):
	if lobby_id == 0:
		return
	logger.debug("SteamManager", "Lobby data: %s = %s" % [key, value])
	Steam.setLobbyData(lobby_id, key, value)

func get_lobby_data(key: String) -> String:
	if lobby_id == 0:
		return ""
	return Steam.getLobbyData(lobby_id, key)

func get_lobby_member_count() -> int:
	if lobby_id == 0:
		return 0
	return Steam.getNumLobbyMembers(lobby_id)

func get_lobby_member_by_index(index: int) -> int:
	if lobby_id == 0:
		return 0
	return Steam.getLobbyMemberByIndex(lobby_id, index)

func _on_lobby_created(connectivity: int, new_lobby_id: int):
	_pending_callbacks.erase("lobby_created")
	logger.info("SteamManager", "Callback lobby_created: connectivity=%s lobby_id=%s" % [connectivity, new_lobby_id])
	if connectivity == 1:
		lobby_id = new_lobby_id
		is_host = true
		set_lobby_data("game", "Vivo Sprint")
		set_lobby_data("version", "0.1.0")
		lobby_created.emit(lobby_id)
	else:
		logger.warn("SteamManager", "Falha ao criar lobby. Código: %s" % connectivity)
		lobby_join_failed.emit("Failed to create lobby (code %s)" % connectivity)

func _on_lobby_joined(new_lobby_id: int, _permissions: int, _locked: bool, _response: int):
	_pending_callbacks.erase("lobby_joined")
	logger.info("SteamManager", "Callback lobby_joined: lobby_id=%s permissions=%s locked=%s response=%s" % [new_lobby_id, _permissions, _locked, _response])
	lobby_id = new_lobby_id
	lobby_joined.emit(lobby_id)

func _on_lobby_join_requested(_lobby_id: int):
	logger.info("SteamManager", "Pedido de entrada no lobby %s" % _lobby_id)
	join_lobby(_lobby_id)

func _on_lobby_data_update(_lobby_id: int, _key: String, _value: String):
	logger.debug("SteamManager", "Lobby data updated: %s = %s" % [_key, _value])
	lobby_data_updated.emit(_key, _value)

func _on_lobby_chat_update(_lobby_id: int, _changed_id: int, _making_change_id: int, _chat_state: int):
	logger.info("SteamManager", "Lobby chat update: lobby=%s changed=%s state=%s" % [_lobby_id, _changed_id, _chat_state])
	if _chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
		member_joined.emit(_changed_id)
	elif _chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_LEFT:
		member_left.emit(_changed_id)

func _on_lobby_match_list(lobby_list: Array):
	_pending_callbacks.erase("lobby_match_list")
	logger.info("SteamManager", "Callback lobby_match_list: %s lobbies encontrados" % lobby_list.size())
	var lobbies: Array[Dictionary] = []
	for id in lobby_list:
		var name := Steam.getLobbyData(id, "name")
		var player_count := Steam.getNumLobbyMembers(id)
		var max_players := Steam.getLobbyMemberLimit(id)
		logger.debug("SteamManager", "  Lobby %s: %s (%s/%s)" % [id, name, player_count, max_players])
		lobbies.append({
			"id": id,
			"name": name if name else "Unnamed Lobby",
			"players": player_count,
			"max_players": max_players
		})
	lobby_list_received.emit(lobbies)

func _on_lobby_invite(_inviter: int, _lobby_id: int, _game_id: int):
	logger.info("SteamManager", "Convite para lobby %s de %s" % [_lobby_id, _inviter])
	join_lobby(_lobby_id)

func _on_lobby_kicked(lobby_id_kicked: int, admin_id: int, kicked_due_to_disconnect: bool):
	logger.info("SteamManager", "Foste expulso do lobby %s pelo admin %s (disconnect=%s)" % [lobby_id_kicked, admin_id, kicked_due_to_disconnect])
	lobby_id = 0
	is_host = false
	lobby_left.emit()

func _on_lobby_game_created(_lobby_id: int, _ip: int, _port: int):
	logger.info("SteamManager", "Lobby game created: lobby=%s" % _lobby_id)

func _on_game_overlay_activated(_user: bool):
	pass
