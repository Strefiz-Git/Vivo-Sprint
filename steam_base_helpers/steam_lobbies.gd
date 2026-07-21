## steam_lobbies.gd
## -----------------------------------------------------------------------
## Autoload responsável por criar, procurar, entrar e gerir lobbies Steam
## (incluindo password, chat de texto, e kick de jogadores).
##
## Depende de "SteamHelpers" (steam_helpers.gd) já estar carregado como
## autoload antes deste, para poder guardar SteamHelpers.lobby_id.
##
## COMO USAR: adiciona como Autoload com o nome "SteamLobbies".
## -----------------------------------------------------------------------
extends Node

signal lobby_create_failed(reason: String)
signal lobby_created_successfully(lobby_id: int)
signal lobby_join_failed(reason: String)
signal lobby_joined_successfully(lobby_id: int)
signal lobby_list_received(lobbies: Array)
signal lobby_members_changed
signal chat_message_received(sender_id: int, sender_name: String, message: String)
signal kicked_from_lobby

const KEY_LOBBY_NAME: String = "lobby_name"
const KEY_MODE: String = "mode"
const KEY_HAS_PASSWORD: String = "has_password"
const KEY_PASSWORD_HASH: String = "pw_hash"

var _pending_password: String = ""


func _ready() -> void:
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.lobby_message.connect(_on_lobby_message)
	Steam.join_requested.connect(_on_join_requested)
	Steam.lobby_data_update.connect(_on_lobby_data_update)


## ---------------------------------------------------------------------
## Criar lobby
## ---------------------------------------------------------------------

func create_lobby(lobby_type: Steam.LobbyType, max_players: int, lobby_name: String, mode: String = "", password: String = "") -> void:
	_pending_password = password
	_pending_lobby_name = lobby_name
	_pending_mode = mode
	Steam.createLobby(lobby_type, max_players)

var _pending_lobby_name: String = ""
var _pending_mode: String = ""


func _on_lobby_created(connect_status: int, new_lobby_id: int) -> void:
	if connect_status != Steam.Result.RESULT_OK:
		lobby_create_failed.emit(str(connect_status))
		return

	SteamHelpers.lobby_id = new_lobby_id

	Steam.setLobbyData(new_lobby_id, KEY_LOBBY_NAME, _pending_lobby_name)
	if not _pending_mode.is_empty():
		Steam.setLobbyData(new_lobby_id, KEY_MODE, _pending_mode)

	if not _pending_password.is_empty():
		Steam.setLobbyData(new_lobby_id, KEY_HAS_PASSWORD, "true")
		Steam.setLobbyData(new_lobby_id, KEY_PASSWORD_HASH, _pending_password.sha256_text())
	else:
		Steam.setLobbyData(new_lobby_id, KEY_HAS_PASSWORD, "false")

	_pending_password = ""
	lobby_created_successfully.emit(new_lobby_id)


## ---------------------------------------------------------------------
## Procurar lobbies
## ---------------------------------------------------------------------

## filters: Dictionary opcional, ex: {"mode": "coop"}
func search_lobbies(filters: Dictionary = {}, max_results: int = 50, distance: Steam.LobbyDistanceFilter = Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE) -> void:
	Steam.addRequestLobbyListDistanceFilter(distance)
	Steam.addRequestLobbyListResultCountFilter(max_results)
	for key in filters:
		Steam.addRequestLobbyListStringFilter(key, str(filters[key]), Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()


func _on_lobby_match_list(lobbies: Array) -> void:
	var parsed: Array = []
	for id in lobbies:
		parsed.append({
			"id": id,
			"name": Steam.getLobbyData(id, KEY_LOBBY_NAME),
			"mode": Steam.getLobbyData(id, KEY_MODE),
			"has_password": Steam.getLobbyData(id, KEY_HAS_PASSWORD) == "true",
			"players": Steam.getNumLobbyMembers(id),
			"max_players": Steam.getLobbyMemberLimit(id),
		})
	lobby_list_received.emit(parsed)


## ---------------------------------------------------------------------
## Entrar numa lobby
## ---------------------------------------------------------------------

## Verifica a password (se existir) antes de tentar entrar de facto.
## Devolve false imediatamente se a password estiver errada.
func try_join_lobby(target_lobby_id: int, password_attempt: String = "") -> bool:
	var has_password: bool = Steam.getLobbyData(target_lobby_id, KEY_HAS_PASSWORD) == "true"
	if has_password:
		var correct_hash: String = Steam.getLobbyData(target_lobby_id, KEY_PASSWORD_HASH)
		if password_attempt.sha256_text() != correct_hash:
			lobby_join_failed.emit("password_incorreta")
			return false
	Steam.joinLobby(target_lobby_id)
	return true


func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		var reason: String = "erro_desconhecido"
		match response:
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST:
				reason = "lobby_nao_existe"
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_FULL:
				reason = "lobby_cheia"
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_BANNED:
				reason = "banido"
		lobby_join_failed.emit(reason)
		return

	SteamHelpers.lobby_id = joined_lobby_id
	lobby_joined_successfully.emit(joined_lobby_id)


## Chamado quando o utilizador aceita um convite Steam com o jogo já aberto.
func _on_join_requested(requested_lobby_id: int, _friend_id: int) -> void:
	Steam.joinLobby(requested_lobby_id)


## Chama isto no arranque do jogo (main.gd) para tratar de "+connect_lobby"
## quando o jogo é lançado a partir de um convite com o jogo fechado.
func check_launch_args_for_lobby_invite() -> void:
	var args: Array = OS.get_cmdline_args()
	if args.size() >= 2 and args[0] == "+connect_lobby":
		var target: int = int(args[1])
		if target > 0:
			Steam.joinLobby(target)


## ---------------------------------------------------------------------
## Dados / membros da lobby
## ---------------------------------------------------------------------

func set_lobby_data(key: String, value: String, target_lobby_id: int = -1) -> void:
	var id: int = target_lobby_id if target_lobby_id != -1 else SteamHelpers.lobby_id
	Steam.setLobbyData(id, key, value)


func get_lobby_data(key: String, target_lobby_id: int = -1) -> String:
	var id: int = target_lobby_id if target_lobby_id != -1 else SteamHelpers.lobby_id
	return Steam.getLobbyData(id, key)


func get_lobby_members() -> Array:
	var members: Array = []
	var count: int = Steam.getNumLobbyMembers(SteamHelpers.lobby_id)
	for i in range(count):
		var member_id: int = Steam.getLobbyMemberByIndex(SteamHelpers.lobby_id, i)
		members.append({
			"id": member_id,
			"name": Steam.getFriendPersonaName(member_id),
		})
	return members


func get_lobby_owner() -> int:
	return Steam.getLobbyOwner(SteamHelpers.lobby_id)


func is_local_player_owner() -> bool:
	return get_lobby_owner() == SteamHelpers.steam_id


func set_lobby_joinable(joinable: bool) -> void:
	Steam.setLobbyJoinable(SteamHelpers.lobby_id, joinable)


func promote_to_owner(new_owner_id: int) -> void:
	if is_local_player_owner():
		Steam.setLobbyOwner(SteamHelpers.lobby_id, new_owner_id)


func leave_lobby() -> void:
	if SteamHelpers.lobby_id != 0:
		Steam.leaveLobby(SteamHelpers.lobby_id)
		SteamHelpers.lobby_id = 0


func _on_lobby_chat_update(_lobby_id: int, _changed_id: int, _making_change_id: int, _chat_state: int) -> void:
	lobby_members_changed.emit()


func _on_lobby_data_update(_lobby_id: int, _member_id: int, _key: int) -> void:
	lobby_members_changed.emit()


## ---------------------------------------------------------------------
## Chat de texto
## ---------------------------------------------------------------------

func send_chat_message(message: String) -> void:
	Steam.sendLobbyChatMsg(SteamHelpers.lobby_id, message)


func _on_lobby_message(_lobby_id: int, sender_id: int, message: String, _chat_type: int) -> void:
	# Comando de kick convencionado: "/kick <steam_id>". Só o dono da lobby
	# tem poder para isto ser respeitado; qualquer outra origem é ignorada.
	if message.begins_with("/kick ") and sender_id == get_lobby_owner():
		var target_id: int = int(message.substr(6).strip_edges())
		if target_id == SteamHelpers.steam_id:
			leave_lobby()
			kicked_from_lobby.emit()
		return

	chat_message_received.emit(sender_id, Steam.getFriendPersonaName(sender_id), message)


## Só deve ser chamado pelo dono da lobby.
func kick_player(target_steam_id: int) -> void:
	if is_local_player_owner():
		send_chat_message("/kick %s" % target_steam_id)
