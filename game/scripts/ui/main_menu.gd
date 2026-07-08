extends Control

@onready var status_label: Label = $VBoxContainer/lbl_status
@onready var steam_id_label: Label = $VBoxContainer/lbl_steamid
@onready var lobby_label: Label = $VBoxContainer/lbl_lobby
@onready var create_lobby_btn: Button = $VBoxContainer/HBoxContainer/btn_createLobby
@onready var leave_lobby_btn: Button = $VBoxContainer/HBoxContainer/btn_leaveLobby
@onready var lobby_list: ItemList = $VBoxContainer/ItemList

func _ready():
	if steam_manager.initialized:
		status_label.text = "Steam: CONECTADO"
		steam_id_label.text = "ID: %s  |  Nome: %s" % [steam_manager.steam_id, steam_manager.steam_name]
		create_lobby_btn.disabled = false
		leave_lobby_btn.disabled = false
	else:
		status_label.text = "Steam: OFFLINE (modo local)"
		steam_id_label.text = "A testar sem Steam"

	steam_manager.lobby_created.connect(_on_lobby_created)
	steam_manager.lobby_joined.connect(_on_lobby_joined)
	steam_manager.lobby_join_failed.connect(func(r): lobby_label.text = "Falhou: " + r)
	steam_manager.lobby_left.connect(func(): lobby_label.text = "Saiu do lobby")
	steam_manager.lobby_list_received.connect(_on_lobby_list)
	steam_manager.member_joined.connect(func(sid): lobby_label.text += "\nJogador entrou: %s" % sid)
	steam_manager.member_left.connect(func(sid): lobby_label.text += "\nJogador saiu: %s" % sid)

func _on_create_lobby_pressed():
	steam_manager.create_lobby(Steam.LOBBY_TYPE_PUBLIC, 8)

func _on_leave_lobby_pressed():
	steam_manager.leave_lobby()

func _on_search_lobby_pressed():
	steam_manager.request_lobby_list()
	lobby_label.text = "A procurar lobbies..."

func _on_enter_lobby_pressed():
	var selected = lobby_list.get_selected_items()
	if selected.size() > 0:
		var meta = lobby_list.get_item_metadata(selected[0])
		steam_manager.join_lobby(meta)

func _on_lobby_created(lobby_id: int):
	lobby_label.text = "Lobby criado! ID: %s" % lobby_id

func _on_lobby_joined(lobby_id: int):
	lobby_label.text = "Entraste no lobby! ID: %s" % lobby_id

func _on_lobby_list(lobbies: Array):
	lobby_list.clear()
	for l in lobbies:
		var idx = lobby_list.add_item("%s (%d/%d)" % [l.name, l.players, l.max_players])
		lobby_list.set_item_metadata(idx, l.id)
	lobby_label.text = "%d lobbies encontrados" % lobbies.size()

func _on_start_server_pressed():
	network_manager.start_server()

func _on_connect_client_pressed():
	network_manager.connect_to_server("127.0.0.1", 27015)

func _on_quit_game_pressed():
	get_tree().quit()
