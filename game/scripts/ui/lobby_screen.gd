extends Control

@onready var title_label: Label = $VBoxContainer/title_label
@onready var player_list: ItemList = $VBoxContainer/player_list
@onready var ready_btn: Button = $VBoxContainer/HBoxContainer/ready_btn
@onready var start_btn: Button = $VBoxContainer/HBoxContainer/start_btn
@onready var transfer_btn: Button = $VBoxContainer/HBoxContainer/transfer_btn
@onready var kick_btn: Button = $VBoxContainer/HBoxContainer/kick_btn
@onready var config_btn: Button = $VBoxContainer/HBoxContainer/config_btn
@onready var leave_btn: Button = $VBoxContainer/HBoxContainer/leave_btn
@onready var status_label: Label = $VBoxContainer/status_label

# Config popup
@onready var config_window: Window = $config_window
@onready var cfg_name: LineEdit = $config_window/VBox/cfg_name
@onready var cfg_max: HSlider = $config_window/VBox/cfg_max
@onready var cfg_max_label: Label = $config_window/VBox/cfg_max_label
@onready var cfg_pass: LineEdit = $config_window/VBox/cfg_pass
@onready var cfg_vis: OptionButton = $config_window/VBox/cfg_vis

var _i_am_ready: bool = false

func _ready():
	logger.info("LobbyScreen", "Ecrã de lobby aberto")
	title_label.text = "Lobby: %s" % steam_manager.lobby_id
	transfer_btn.visible = false
	kick_btn.visible = false
	config_btn.visible = steam_manager.is_host
	start_btn.visible = steam_manager.is_host
	ready_btn.disabled = steam_manager.is_host
	_atualizar_jogadores()
	player_list.item_selected.connect(_on_player_selected)
	player_list.nothing_selected.connect(_on_player_deselected)
	cfg_max.value_changed.connect(func(v): cfg_max_label.text = str(v))
	cfg_vis.add_item("Público", Steam.LOBBY_TYPE_PUBLIC)
	cfg_vis.add_item("Amigos", Steam.LOBBY_TYPE_FRIENDS_ONLY)
	cfg_vis.add_item("Privado", Steam.LOBBY_TYPE_PRIVATE)
	cfg_vis.add_item("Invisível", Steam.LOBBY_TYPE_INVISIBLE)
	steam_manager.member_joined.connect(_on_member_changed)
	steam_manager.member_left.connect(_on_member_changed)
	steam_manager.lobby_data_updated.connect(_on_lobby_data_updated)
	steam_manager.lobby_left.connect(_on_lobby_left)

func _atualizar_jogadores():
	if steam_manager.lobby_id == 0:
		return
	player_list.clear()
	var count = steam_manager.get_lobby_member_count()
	var owner_id = steam_manager.get_lobby_owner()
	for i in range(count):
		var sid = steam_manager.get_lobby_member_by_index(i)
		var nome = Steam.getFriendPersonaName(sid)
		var ready_str = Steam.getLobbyMemberData(steam_manager.lobby_id, sid, "ready")
		var ready_icon = "✓" if ready_str == "true" else "○"
		if sid == steam_manager.steam_id:
			nome += " (tu)"
		if sid == owner_id:
			nome += " [HOST]"
		player_list.add_item("%s %s" % [ready_icon, nome])
		var idx = player_list.item_count - 1
		player_list.set_item_metadata(idx, sid)
	logger.info("LobbyScreen", "%d jogadores na lobby" % count)
	status_label.text = "%d/%d jogadores" % [count, steam_manager.get_lobby_member_count()]

func _on_player_selected(index: int):
	if not steam_manager.is_host:
		return
	var sid = player_list.get_item_metadata(index)
	if sid != steam_manager.steam_id:
		transfer_btn.visible = true
		kick_btn.visible = true

func _on_player_deselected():
	transfer_btn.visible = false
	kick_btn.visible = false

func _on_ready_pressed():
	_i_am_ready = not _i_am_ready
	Steam.setLobbyMemberData(steam_manager.lobby_id, "ready", "true" if _i_am_ready else "false")
	ready_btn.text = "Nao Pronto" if _i_am_ready else "Pronto"
	logger.info("LobbyScreen", "Ready toggled: %s" % _i_am_ready)

func _on_start_pressed():
	logger.info("LobbyScreen", "Host: iniciar corrida")
	status_label.text = "A iniciar corrida..."
	_on_leave_pressed()

func _on_transfer_pressed():
	var selected = player_list.get_selected_items()
	if selected.size() == 0:
		return
	var target_sid = player_list.get_item_metadata(selected[0])
	logger.info("LobbyScreen", "A transferir liderança para %s" % target_sid)
	steam_manager.transfer_ownership(target_sid)
	transfer_btn.visible = false
	kick_btn.visible = false
	start_btn.visible = false
	config_btn.visible = false

func _on_kick_pressed():
	var selected = player_list.get_selected_items()
	if selected.size() == 0:
		return
	var target_sid = player_list.get_item_metadata(selected[0])
	logger.info("LobbyScreen", "A expulsar %s" % target_sid)
	steam_manager.kick_user(target_sid)
	transfer_btn.visible = false
	kick_btn.visible = false

func _on_config_pressed():
	logger.info("LobbyScreen", "A abrir configuracao")
	_preencher_config()
	config_window.popup_centered()

func _preencher_config():
	var nome = steam_manager.get_lobby_data("lobby_name")
	cfg_name.text = nome if nome else "Lobby de %s" % steam_manager.steam_name
	cfg_max.value = steam_manager.get_lobby_member_count()
	cfg_max_label.text = str(cfg_max.value)
	var pass_val = steam_manager.get_lobby_data("lobby_password")
	cfg_pass.text = pass_val
	var vis_str = steam_manager.get_lobby_data("lobby_visibility")
	for i in range(cfg_vis.item_count):
		if cfg_vis.get_item_id(i) == int(vis_str):
			cfg_vis.select(i)
			break

func _on_config_save():
	logger.info("LobbyScreen", "A guardar configuracao")
	steam_manager.set_lobby_data("lobby_name", cfg_name.text)
	steam_manager.set_lobby_data("lobby_password", cfg_pass.text)
	steam_manager.set_lobby_data("lobby_visibility", str(cfg_vis.get_selected_id()))
	status_label.text = "Configuracao guardada"
	config_window.hide()
	title_label.text = "Lobby: %s" % steam_manager.lobby_id

func _on_config_cancel():
	config_window.hide()

func _on_leave_pressed():
	logger.info("LobbyScreen", "A sair da lobby")
	steam_manager.leave_lobby()

func _on_member_changed(_sid: int):
	_atualizar_jogadores()

func _on_lobby_data_updated(_key: String, _value: String):
	if _key == "ready":
		_atualizar_jogadores()

func _on_lobby_left():
	logger.info("LobbyScreen", "Saíu da lobby, voltar ao menu")
	scene_manager.goto_scene("res://scenes/ui/main_menu.tscn")
