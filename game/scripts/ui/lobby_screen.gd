extends Control

@onready var title_label: Label = $VBoxContainer/header/title_label
@onready var lbl_password_status: Label = $VBoxContainer/header/lbl_password_status
@onready var player_tree: Tree = $VBoxContainer/player_tree
@onready var status_label: Label = $VBoxContainer/status_label

@onready var player_actions: HBoxContainer = $VBoxContainer/player_actions
@onready var add_friend_btn: Button = $VBoxContainer/player_actions/add_friend_btn
@onready var transfer_btn: Button = $VBoxContainer/player_actions/transfer_btn
@onready var kick_btn: Button = $VBoxContainer/player_actions/kick_btn

@onready var ready_btn: Button = $VBoxContainer/HBoxContainer/ready_btn
@onready var start_btn: Button = $VBoxContainer/HBoxContainer/start_btn
@onready var invite_btn: Button = $VBoxContainer/HBoxContainer/invite_btn
@onready var leave_btn: Button = $VBoxContainer/HBoxContainer/leave_btn

@onready var config_btn: Button = $VBoxContainer/header/config_btn
@onready var config_window: Window = $config_window
@onready var cfg_name: LineEdit = $config_window/VBox/cfg_name
@onready var cfg_max: HSlider = $config_window/VBox/cfg_max
@onready var cfg_max_label: Label = $config_window/VBox/cfg_max_label
@onready var cfg_pass: LineEdit = $config_window/VBox/cfg_pass
@onready var cfg_vis: OptionButton = $config_window/VBox/cfg_vis

var _i_am_ready: bool = false
var _selected_sid: int = 0
var _player_rows: Dictionary = {}  # steam_id -> TreeItem
var _pings: Dictionary = {}  # steam_id -> ping string

func _ready():
	logger.info("LobbyScreen", "Lobby screen opened")
	_setup_tree()
	_apply_texts()
	var lobby_nome = steam_manager.get_lobby_data("lobby_name")
	title_label.text = tr("LOBBY_TITLE") % (lobby_nome if lobby_nome else steam_manager.lobby_id)
	_atualizar_password_status()
	config_btn.visible = false
	start_btn.visible = false
	_atualizar_jogadores()
	steam_manager.member_joined.connect(_on_member_changed)
	steam_manager.member_left.connect(_on_member_changed)
	steam_manager.lobby_data_updated.connect(_on_lobby_data_updated)
	steam_manager.lobby_left.connect(_on_lobby_left)
	steam_manager.kicked.connect(_on_kicked)
	if steam_manager.is_host:
		Steam.setLobbyJoinable(steam_manager.lobby_id, true)

func _setup_tree():
	player_tree.set_column_title(0, tr("LOBBY_RDY"))
	player_tree.set_column_title(1, tr("LOBBY_PLAYER_NAME"))
	player_tree.set_column_title(2, tr("LOBBY_PING"))
	player_tree.set_column_title(3, "")
	player_tree.set_column_custom_minimum_width(0, 40)
	player_tree.set_column_custom_minimum_width(2, 70)
	player_tree.set_column_custom_minimum_width(3, 120)
	player_tree.set_column_expand(0, false)
	player_tree.set_column_expand(1, true)
	player_tree.set_column_expand(2, false)
	player_tree.set_column_expand(3, false)

func _apply_texts():
	ready_btn.text = tr("LOBBY_READY")
	start_btn.text = tr("LOBBY_START_RACE")
	transfer_btn.text = tr("LOBBY_TRANSFER")
	kick_btn.text = tr("LOBBY_KICK")
	add_friend_btn.text = tr("LOBBY_ADD_FRIEND")
	config_btn.text = tr("LOBBY_CONFIG")
	invite_btn.text = tr("LOBBY_INVITE")
	leave_btn.text = tr("LOBBY_LEAVE")
	config_window.title = tr("CONFIG_TITLE")
	$config_window/VBox/lbl_name.text = tr("CONFIG_NAME_LABEL")
	$config_window/VBox/lbl_max.text = tr("CONFIG_MAX_LABEL")
	$config_window/VBox/lbl_pass.text = tr("CONFIG_PASS_LABEL")
	$config_window/VBox/lbl_vis.text = tr("CONFIG_VIS_LABEL")
	$config_window/VBox/HB/cfg_save.text = tr("CONFIG_SAVE")
	$config_window/VBox/HB/cfg_cancel.text = tr("CONFIG_CANCEL")
	player_tree.set_column_title(1, tr("LOBBY_PLAYER_NAME"))
	player_tree.set_column_title(2, tr("LOBBY_PING"))

func _atualizar_password_status():
	var hash_val = steam_manager.get_lobby_data("lobby_password_hash")
	if hash_val and hash_val != "" and hash_val != "0":
		lbl_password_status.text = "🔒"
		lbl_password_status.tooltip_text = tr("LOBBY_PASSWORD_PROTECTED")
	else:
		lbl_password_status.text = "🔓"
		lbl_password_status.tooltip_text = tr("LOBBY_NO_PASSWORD")

func _obter_ping(steam_id: int) -> String:
	if steam_id == steam_manager.steam_id:
		return "0ms"
	if _pings.has(steam_id):
		return _pings[steam_id]
	if steam_manager.initialized:
		var state = Steam.getP2PSessionState(steam_id)
		if state and state.has("m_nPing"):
			var ping = state["m_nPing"]
			_pings[steam_id] = "%dms" % ping
			return _pings[steam_id]
	return "---"

func _atualizar_jogadores():
	if steam_manager.lobby_id == 0:
		return
	var count = steam_manager.get_lobby_member_count()
	var owner_id = steam_manager.get_lobby_owner()
	var max_count = steam_manager.get_lobby_member_limit()
	var era_host = steam_manager.is_host
	steam_manager.is_host = (owner_id == steam_manager.steam_id)
	# Remover linhas de players que saíram
	var active_sids: Array[int] = []
	for i in range(count):
		var sid = steam_manager.get_lobby_member_by_index(i)
		active_sids.append(sid)
	for sid in _player_rows.keys():
		if not sid in active_sids:
			_player_rows[sid].free()
			_player_rows.erase(sid)
	# Adicionar/atualizar linhas
	for i in range(count):
		var sid = steam_manager.get_lobby_member_by_index(i)
		var nome = Steam.getFriendPersonaName(sid)
		var ready_str = Steam.getLobbyMemberData(steam_manager.lobby_id, sid, "ready")
		var is_ready = (ready_str == "true")
		var ping = _obter_ping(sid)
		var badges = ""
		if sid == steam_manager.steam_id:
			badges += tr("LOBBY_YOU")
		if sid == owner_id:
			if badges:
				badges += " "
			badges += tr("LOBBY_HOST")
		if _player_rows.has(sid):
			var item = _player_rows[sid]
			item.set_text(0, "✓" if is_ready else "—")
			item.set_custom_color(0, Color.GREEN_YELLOW if is_ready else Color.GRAY)
			item.set_text(1, nome)
			item.set_text(2, ping)
			item.set_text(3, badges)
		else:
			var item = player_tree.create_item()
			item.set_text(0, "✓" if is_ready else "—")
			item.set_custom_color(0, Color.GREEN_YELLOW if is_ready else Color.GRAY)
			item.set_text(1, nome)
			item.set_text(2, ping)
			item.set_text(3, badges)
			item.set_metadata(0, sid)
			_player_rows[sid] = item
	if steam_manager.is_host != era_host:
		config_btn.visible = steam_manager.is_host
		start_btn.visible = steam_manager.is_host
		ready_btn.disabled = steam_manager.is_host
		if not steam_manager.is_host:
			player_actions.visible = false
	logger.info("LobbyScreen", "%d players in lobby" % count)
	status_label.text = tr("LOBBY_PLAYERS") % [count, max_count]

func _on_player_selected():
	var selected = player_tree.get_selected()
	if not selected:
		return
	var sid = selected.get_metadata(0) as int
	_selected_sid = sid
	if not steam_manager.is_host or sid == steam_manager.steam_id:
		player_actions.visible = false
		return
	player_actions.visible = true
	var is_friend = Steam.hasFriend(sid, Steam.FRIEND_FLAG_IMMEDIATE) if steam_manager.initialized else false
	add_friend_btn.visible = not is_friend
	transfer_btn.visible = true
	kick_btn.visible = true

func _on_player_deselected():
	_selected_sid = 0
	player_actions.visible = false

func _on_ready_pressed():
	_i_am_ready = not _i_am_ready
	Steam.setLobbyMemberData(steam_manager.lobby_id, "ready", "true" if _i_am_ready else "false")
	ready_btn.text = tr("LOBBY_NOT_READY") if _i_am_ready else tr("LOBBY_READY")
	logger.info("LobbyScreen", "Ready toggled: %s" % _i_am_ready)

func _on_start_pressed():
	logger.info("LobbyScreen", "Host: starting race via P2P")
	status_label.text = tr("LOBBY_STARTING")
	start_btn.disabled = true
	Steam.setLobbyJoinable(steam_manager.lobby_id, false)
	_enviar_iniciar_corrida.rpc()

@rpc("any_peer", "call_local", "reliable")
func _enviar_iniciar_corrida():
	logger.info("LobbyScreen", "Race start RPC received by peer %s" % multiplayer.get_unique_id())
	status_label.text = tr("LOBBY_STARTING")
	if not steam_manager.is_host:
		ready_btn.disabled = true
	start_btn.disabled = true
	logger.info("LobbyScreen", "Race would start now! Loading race scene...")

func _on_invite_pressed():
	logger.info("LobbyScreen", "Opening Steam invite overlay")
	if steam_manager.initialized and steam_manager.lobby_id != 0:
		Steam.activateGameOverlayInviteDialog(steam_manager.lobby_id)

func _on_add_friend_pressed():
	logger.info("LobbyScreen", "Opening Steam add friend overlay for %s" % _selected_sid)
	if steam_manager.initialized and _selected_sid != 0:
		Steam.activateGameOverlayToUser("friendadd", _selected_sid)

func _on_transfer_pressed():
	if _selected_sid == 0:
		return
	logger.info("LobbyScreen", "Transferring ownership to %s" % _selected_sid)
	steam_manager.transfer_ownership(_selected_sid)
	player_actions.visible = false

func _on_kick_pressed():
	if _selected_sid == 0:
		return
	logger.info("LobbyScreen", "Kicking %s" % _selected_sid)
	steam_manager.kick_user(_selected_sid)
	player_actions.visible = false

func _on_config_pressed():
	logger.info("LobbyScreen", "Opening config")
	_preencher_config()
	config_window.popup_centered()

func _preencher_config():
	var nome = steam_manager.get_lobby_data("lobby_name")
	cfg_name.text = nome if nome else "%s's Lobby" % steam_manager.steam_name
	cfg_max.value = steam_manager.get_lobby_member_limit()
	cfg_max_label.text = str(cfg_max.value)
	cfg_pass.text = ""
	var vis_str = steam_manager.get_lobby_data("lobby_visibility")
	for i in range(cfg_vis.item_count):
		if cfg_vis.get_item_id(i) == int(vis_str):
			cfg_vis.select(i)
			break

func _on_config_save():
	logger.info("LobbyScreen", "Saving config")
	steam_manager.set_lobby_data("lobby_name", cfg_name.text)
	if cfg_pass.text:
		steam_manager.set_lobby_password(cfg_pass.text)
	steam_manager.set_lobby_data("lobby_visibility", str(cfg_vis.get_selected_id()))
	status_label.text = tr("LOBBY_CONFIG_SAVED")
	config_window.hide()
	title_label.text = tr("LOBBY_TITLE") % cfg_name.text
	_atualizar_password_status()

func _on_config_cancel():
	config_window.hide()

func _on_leave_pressed():
	logger.info("LobbyScreen", "Leaving lobby")
	steam_manager.leave_lobby()

func _on_member_changed(_sid: int):
	_atualizar_jogadores()

func _on_lobby_data_updated(_member_id: int):
	_atualizar_jogadores()

func _on_kicked(_lobby_id: int):
	logger.warn("LobbyScreen", "Was kicked from lobby")
	status_label.text = tr("LOBBY_KICKED")

func _on_lobby_left():
	logger.info("LobbyScreen", "Left lobby, back to menu")
	scene_manager.goto_scene("res://scenes/ui/main_menu.tscn")
