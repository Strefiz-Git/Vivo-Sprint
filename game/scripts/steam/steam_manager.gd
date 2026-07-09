extends Node

var initialized: bool = false
var steam_id: int = 0
var steam_name: String = "Offline"
var lobby_id: int = 0
var is_host: bool = false

var _debug_time: float = 0.0
var _pending_callbacks: Array[String] = []
var pending_lobby_name: String = ""
var pending_lobby_password: String = ""
var _pending_visibility: int = Steam.LOBBY_TYPE_PUBLIC
var _pending_max_players: int = 12

var _search_lobby_ids: Array[int] = []
var _search_lobby_data: Dictionary = {}
var _search_password_filter: bool = false

signal steam_ready(steam_id: int, name: String)
signal steam_init_failed(reason: String)
signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int)
signal lobby_join_failed(reason: String)
signal lobby_left()
signal member_joined(steam_id: int)
signal member_left(steam_id: int)
signal lobby_data_updated(member_id: int)
signal lobby_list_received(lobbies: Array)

func _ready():
	logger.info("SteamManager", "Initializing Steam...")
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
	logger.info("SteamManager", "Connecting Steam signals...")
	var signal_list = Steam.get_signal_list()
	for s in signal_list:
		logger.debug("SteamManager", "  Steam signal: %s" % s.name)
	var lobby_signals = ["lobby_created", "lobby_joined", "lobby_match_list", "lobby_chat_update", "lobby_data_update", "lobby_invite", "lobby_message"]
	for sig_name in lobby_signals:
		if Steam.has_signal(sig_name):
			Steam.connect(sig_name, Callable(self, "_on_" + sig_name))
			logger.info("SteamManager", "-> %s connected" % sig_name)
	# join_requested (guia) — parâmetros: lobby_id, friend_id
	for alt_name in ["join_requested", "join_lobby_requested", "lobby_join_requested"]:
		if Steam.has_signal(alt_name):
			Steam.connect(alt_name, Callable(self, "_on_join_requested"))
			logger.info("SteamManager", "-> %s connected" % alt_name)
	logger.info("SteamManager", "Signals connected.")

func _on_join_requested(lobby_id_val: int, _friend_id: int):
	logger.info("SteamManager", "Join requested: lobby=%s friend=%s" % [lobby_id_val, _friend_id])
	join_lobby(lobby_id_val)

func _debug_status():
	logger.info("SteamManager", "=== DEBUG: lobby_id=%s is_host=%s initialized=%s pending=%s ===" % [lobby_id, is_host, initialized, _pending_callbacks])

func _process(delta):
	# CRÍTICO: processar callbacks Steam a cada frame (secção 4 do guia)
	if initialized:
		Steam.run_callbacks()
	_debug_time += delta
	if _debug_time >= 10.0:
		_debug_time = 0.0
		if initialized:
			_checar_callback_pendente("lobby_created")
			_checar_callback_pendente("lobby_match_list")

func _checar_callback_pendente(tipo: String):
	if tipo in _pending_callbacks:
		logger.warn("SteamManager", "STILL WAITING for callback %s after %s seconds!" % [tipo, _debug_time])

func _steam_init_success():
	initialized = true
	steam_id = Steam.getSteamID()
	steam_name = Steam.getFriendPersonaName(steam_id)
	logger.info("SteamManager", "Steam OK! ID: %s, Name: %s" % [steam_id, steam_name])
	Steam.setAchievement("tester")
	Steam.storeStats()
	steam_ready.emit(steam_id, steam_name)

func _steam_init_offline():
	initialized = false
	steam_name = "Offline"
	logger.warn("SteamManager", "Steam offline. Local mode only.")
	steam_init_failed.emit("Steam not running or steam_appid.txt not found")

func is_on_steam() -> bool:
	return initialized

func create_lobby(visibility: int = Steam.LOBBY_TYPE_PUBLIC, max_players: int = 12):
	if not initialized:
		logger.warn("SteamManager", "Tried to create lobby but Steam offline")
		return
	logger.info("SteamManager", "Creating lobby... visibility=%s max=%s" % [visibility, max_players])
	_pending_visibility = visibility
	_pending_max_players = max_players
	Steam.createLobby(visibility, max_players)
	logger.info("SteamManager", "createLobby called (void, no return)")
	_pending_callbacks.append("lobby_created")

func join_lobby(target_lobby_id: int):
	if not initialized:
		return
	logger.info("SteamManager", "Joining lobby %s..." % target_lobby_id)
	Steam.joinLobby(target_lobby_id)

func leave_lobby():
	if lobby_id == 0:
		return
	logger.info("SteamManager", "Leaving lobby %s" % lobby_id)
	Steam.leaveLobby(lobby_id)
	lobby_id = 0
	is_host = false
	pending_lobby_name = ""
	pending_lobby_password = ""
	lobby_left.emit()

func request_lobby_list():
	request_lobby_list_filtered(Steam.LOBBY_DISTANCE_FILTER_DEFAULT, false)

func request_lobby_list_filtered(distance_filter: int, no_password: bool):
	if not initialized:
		logger.warn("SteamManager", "Tried to search lobbies but Steam offline")
		return
	logger.info("SteamManager", "Searching lobbies... distance=%s no_password=%s" % [distance_filter, no_password])
	_search_lobby_ids.clear()
	_search_lobby_data.clear()
	_search_password_filter = no_password
	Steam.addRequestLobbyListDistanceFilter(distance_filter)
	Steam.addRequestLobbyListResultCountFilter(50)
	Steam.requestLobbyList()
	logger.info("SteamManager", "requestLobbyList called (void, no return)")
	_pending_callbacks.append("lobby_match_list")

func set_lobby_data(key: String, value: String):
	if lobby_id == 0:
		return
	logger.debug("SteamManager", "Lobby data: %s = %s" % [key, value])
	Steam.setLobbyData(lobby_id, key, value)

func set_lobby_name(name: String):
	set_lobby_data("lobby_name", name)

func set_lobby_password(password: String):
	set_lobby_data("lobby_password", password)

func set_lobby_joinable(joinable: bool):
	if lobby_id == 0:
		return
	logger.debug("SteamManager", "Lobby joinable: %s" % joinable)
	Steam.setLobbyJoinable(lobby_id, joinable)

func get_lobby_data(key: String) -> String:
	if lobby_id == 0:
		return ""
	return Steam.getLobbyData(lobby_id, key)

func get_lobby_member_count() -> int:
	if lobby_id == 0:
		return 0
	return Steam.getNumLobbyMembers(lobby_id)

func get_lobby_member_limit() -> int:
	if lobby_id == 0:
		return 0
	return Steam.getLobbyMemberLimit(lobby_id)

func get_lobby_member_by_index(index: int) -> int:
	if lobby_id == 0:
		return 0
	return Steam.getLobbyMemberByIndex(lobby_id, index)

func get_lobby_owner() -> int:
	if lobby_id == 0:
		return 0
	return Steam.getLobbyOwner(lobby_id)

func transfer_ownership(target_steam_id: int):
	if lobby_id == 0 or not is_host:
		logger.warn("SteamManager", "Only host can transfer ownership")
		return
	logger.info("SteamManager", "Transferring ownership to %s" % target_steam_id)
	Steam.setLobbyOwner(lobby_id, target_steam_id)
	is_host = false

func kick_user(target_steam_id: int):
	logger.warn("SteamManager", "Kick not supported in this GodotSteam version")

func _on_lobby_created(connect_status: int, lobby_id_val: int):
	_pending_callbacks.erase("lobby_created")
	logger.info("SteamManager", "Callback lobby_created: status=%s lobby_id=%s (RESULT_OK=%s)" % [connect_status, lobby_id_val, Steam.Result.RESULT_OK])
	if connect_status == Steam.Result.RESULT_OK:
		lobby_id = lobby_id_val
		is_host = true
		set_lobby_data("game", "Vivo Sprint")
		set_lobby_data("version", "0.1.0")
		set_lobby_data("lobby_name", "%s's Lobby" % steam_name)
		set_lobby_data("lobby_visibility", str(_pending_visibility))
		set_lobby_data("lobby_max_players", str(_pending_max_players))
		lobby_created.emit(lobby_id)
	else:
		logger.warn("SteamManager", "Failed to create lobby. Code: %s" % connect_status)
		lobby_join_failed.emit("Failed to create lobby (code %s)" % connect_status)

func _on_lobby_joined(lobby_id_val: int, _permissions: int, _locked: bool, response: int):
	_pending_callbacks.erase("lobby_joined")
	logger.info("SteamManager", "Callback lobby_joined: lobby_id=%s response=%s (SUCCESS=%s)" % [lobby_id_val, response, Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_SUCCESS])
	if response == Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		lobby_id = lobby_id_val
		lobby_joined.emit(lobby_id)
	else:
		var reason = "unknown"
		match response:
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST:
				reason = "lobby does not exist"
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_FULL:
				reason = "lobby is full"
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_BANNED:
				reason = "banned"
		logger.warn("SteamManager", "Failed to join lobby: %s" % reason)
		lobby_join_failed.emit(reason)

func _on_lobby_join_requested(_lobby_id: int):
	logger.info("SteamManager", "Join request for lobby %s" % _lobby_id)
	join_lobby(_lobby_id)

func _on_lobby_data_update(lobby_id: int, member_id: int, _success: int):
	if member_id == 0:
		if lobby_id in _search_lobby_ids and not _search_lobby_data.has(lobby_id):
			_coletar_dados_lobby(lobby_id)
		return
	if lobby_id == self.lobby_id:
		logger.debug("SteamManager", "Lobby member data update: lobby=%s member=%s" % [lobby_id, member_id])
		lobby_data_updated.emit(member_id)

func _coletar_dados_lobby(lobby_id: int):
	var name = Steam.getLobbyData(lobby_id, "lobby_name")
	var player_count = Steam.getNumLobbyMembers(lobby_id)
	var max_players = Steam.getLobbyMemberLimit(lobby_id)
	var password = Steam.getLobbyData(lobby_id, "lobby_password")
	logger.debug("SteamManager", "Data received lobby %s: name='%s' (%s/%s) pass='%s'" % [lobby_id, name, player_count, max_players, password])
	_search_lobby_data[lobby_id] = {
		"id": lobby_id,
		"name": name if name else "%s's Lobby" % Steam.getFriendPersonaName(Steam.getLobbyOwner(lobby_id)),
		"players": player_count,
		"max_players": max_players,
		"password": password
	}
	if _search_lobby_data.size() >= _search_lobby_ids.size():
		logger.info("SteamManager", "All data received, emitting list")
		_emit_lobby_list()

func _on_lobby_chat_update(_lobby_id: int, _changed_id: int, _making_change_id: int, _chat_state: int):
	logger.info("SteamManager", "Lobby chat update: lobby=%s changed=%s state=%s" % [_lobby_id, _changed_id, _chat_state])
	if _chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
		member_joined.emit(_changed_id)
	elif _chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_LEFT:
		member_left.emit(_changed_id)

func _on_lobby_match_list(lobby_list: Array):
	_pending_callbacks.erase("lobby_match_list")
	logger.info("SteamManager", "Callback lobby_match_list: %s lobbies found" % lobby_list.size())
	_search_lobby_ids.clear()
	_search_lobby_data.clear()
	for id in lobby_list:
		_search_lobby_ids.append(id)
		Steam.requestLobbyData(id)
	logger.info("SteamManager", "requestLobbyData called for %s lobbies, waiting for data..." % _search_lobby_ids.size())
	get_tree().create_timer(3.0).timeout.connect(_emit_lobby_list)

func _emit_lobby_list():
	if _search_lobby_ids.is_empty():
		return
	logger.info("SteamManager", "Emitting list with %s/%s lobbies with data" % [_search_lobby_data.size(), _search_lobby_ids.size()])
	var lobbies: Array[Dictionary] = []
	for id in _search_lobby_ids:
		var data = _search_lobby_data.get(id)
		if data:
			if _search_password_filter and data.password != "":
				continue
			lobbies.append(data)
	lobby_list_received.emit(lobbies)
	_search_lobby_ids.clear()
	_search_lobby_data.clear()

func _on_lobby_invite(_inviter: int, _lobby_id: int, _game_id: int):
	logger.info("SteamManager", "Invite to lobby %s from %s" % [_lobby_id, _inviter])
	join_lobby(_lobby_id)

func _on_lobby_message(lobby_id_val: int, sender: int, message: String, chat_type: int):
	logger.info("SteamManager", "Message lobby %s from %s: %s" % [lobby_id_val, sender, message])

func _on_lobby_kicked(lobby_id_kicked: int, admin_id: int, kicked_due_to_disconnect: bool):
	logger.info("SteamManager", "Kicked from lobby %s by admin %s (disconnect=%s)" % [lobby_id_kicked, admin_id, kicked_due_to_disconnect])
	lobby_id = 0
	is_host = false
	pending_lobby_name = ""
	pending_lobby_password = ""
	lobby_left.emit()

func _on_lobby_game_created(_lobby_id: int, _ip: int, _port: int):
	logger.info("SteamManager", "Lobby game created: lobby=%s" % _lobby_id)

func _on_game_overlay_activated(_user: bool):
	pass
