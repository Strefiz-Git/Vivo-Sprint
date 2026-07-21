## steam_helpers.gd
## -----------------------------------------------------------------------
## Autoload principal do Steam. Trata da inicialização, callbacks, dados
## do utilizador local e da lista de amigos.
##
## COMO USAR:
## 1. Adiciona este script como Autoload em Project Settings > Autoload,
##    com o nome "SteamHelpers" (ou o nome que preferires).
## 2. Os outros ficheiros deste pacote (steam_lobbies.gd, steam_networking.gd,
##    etc.) assumem que este autoload existe e usam `SteamHelpers.steam_id`,
##    `SteamHelpers.lobby_id`, etc.
## -----------------------------------------------------------------------
extends Node

## App ID a usar para testes. Troca para o teu App ID real antes de publicares.
const TEST_APP_ID: int = 480

signal steam_initialized(success: bool)
signal friends_list_updated

var is_steam_initialized: bool = false
var steam_id: int = 0
var steam_username: String = ""
var lobby_id: int = 0  ## ID da lobby atual (0 = não está em nenhuma)


func _ready() -> void:
	initialize_steam()


func _process(_delta: float) -> void:
	# Só é preciso chamar isto manualmente se NÃO tiveres ativado
	# "Embed Callbacks" em Project Settings > Steam > Initialization.
	if is_steam_initialized:
		Steam.run_callbacks()


## Inicializa o Steam. Chama isto o mais cedo possível no arranque do jogo.
func initialize_steam(app_id: int = TEST_APP_ID) -> void:
	OS.set_environment("SteamAppId", str(app_id))
	OS.set_environment("SteamGameId", str(app_id))

	var init_response: Dictionary = Steam.steamInitEx(app_id)
	print("[Steam] Resposta de inicialização: %s" % init_response)

	if init_response["status"] > Steam.STEAM_API_INIT_RESULT_OK:
		printerr("[Steam] Falha ao inicializar: %s" % init_response.get("verbal", "erro desconhecido"))
		is_steam_initialized = false
		steam_initialized.emit(false)
		return

	is_steam_initialized = true
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()
	print("[Steam] Inicializado como %s (%s)" % [steam_username, steam_id])
	steam_initialized.emit(true)


## ---------------------------------------------------------------------
## Dados básicos do utilizador
## ---------------------------------------------------------------------

func is_online() -> bool:
	return Steam.loggedOn()


func owns_game() -> bool:
	return Steam.isSubscribed()


func is_on_steam_deck() -> bool:
	return Steam.isSteamRunningOnSteamDeck()


## ---------------------------------------------------------------------
## Amigos
## ---------------------------------------------------------------------

## Devolve um Array de dicionários {id, name} com todos os amigos "verdadeiros".
func get_friends_list() -> Array:
	var friends: Array = []
	var count: int = Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE)
	for i in range(count):
		var friend_id: int = Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)
		friends.append({
			"id": friend_id,
			"name": Steam.getFriendPersonaName(friend_id),
		})
	return friends


## Devolve um Dictionary { lobby_id: [friend_id, friend_id, ...] } com lobbies
## do TEU jogo onde tens amigos a jogar neste momento.
func get_friend_lobbies() -> Dictionary:
	var results: Dictionary = {}
	var count: int = Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE)

	for i in range(count):
		var friend_id: int = Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)
		var game_info: Dictionary = Steam.getFriendGamePlayed(friend_id)
		if game_info.is_empty():
			continue

		var app_id: int = game_info.get("id", 0)
		var lobby = game_info.get("lobby", "No valid lobby")

		if app_id != Steam.getAppID() or lobby is String:
			continue

		if not results.has(lobby):
			results[lobby] = []
		results[lobby].append(friend_id)

	return results


## Confirma se um amigo ainda está mesmo numa lobby específica (os dados
## de getFriendGamePlayed podem estar ligeiramente desatualizados).
func is_friend_still_in_lobby(friend_id: int, target_lobby_id: int) -> bool:
	var game_info: Dictionary = Steam.getFriendGamePlayed(friend_id)
	if game_info.is_empty():
		return false
	var lobby = game_info.get("lobby", null)
	return game_info.get("id", 0) == Steam.getAppID() and lobby is int and lobby == target_lobby_id


func get_friend_name(friend_id: int) -> String:
	return Steam.getFriendPersonaName(friend_id)


## ---------------------------------------------------------------------
## Overlay
## ---------------------------------------------------------------------

func open_friends_overlay() -> void:
	Steam.activateGameOverlay("friends")


func open_profile_overlay(target_steam_id: int) -> void:
	Steam.activateGameOverlayToUser("steamid", target_steam_id)


func send_friend_request(target_steam_id: int) -> void:
	Steam.activateGameOverlayToUser("friendadd", target_steam_id)


func open_invite_dialog() -> void:
	if lobby_id != 0:
		Steam.activateGameOverlayInviteDialog(lobby_id)
