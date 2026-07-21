extends Control

@onready var title_label: Label = $VBoxContainer/header/title_label
@onready var lbl_password_status: Label = $VBoxContainer/header/lbl_password_status
@onready var player_tree: Tree = $VBoxContainer/main_split/player_tree
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

@onready var chat_display: RichTextLabel = $VBoxContainer/main_split/chat_box/chat_display
@onready var chat_input: LineEdit = $VBoxContainer/main_split/chat_box/chat_bottom/chat_input
@onready var chat_send_btn: Button = $VBoxContainer/main_split/chat_box/chat_bottom/chat_send
@onready var debug_label: Label = $VBoxContainer/debug_label

var _i_am_ready: bool = false
var _selected_sid: int = 0
var _player_rows: Dictionary = {}
var _pings: Dictionary = {}
var _ping_timer: Timer = null
var _auto_start_timer: Timer = null
var _auto_start_seconds: int = 0

func _ready():
	logger.info("LobbyScreen", "Lobby screen opened")
	_setup_tree()
	_apply_texts()
	var lobby_nome = steam_manager.get_lobby_data("lobby_name")
	title_label.text = tr("LOBBY_TITLE") % (lobby_nome if lobby_nome else steam_manager.lobby_id)
	_atualizar_password_status()
	config_btn.visible = false
	start_btn.visible = false
	# Inicializar chat
	chat_display.bbcode_enabled = true
	chat_input.text_submitted.connect(_on_chat_send)
	chat_send_btn.pressed.connect(_on_chat_send_btn)
	steam_manager.lobby_chat_message.connect(_on_lobby_chat_message)
	chat_display.append_text("[color=green]%s[/color]\n" % tr("CHAT_WELCOME"))
	# Inicializar auto-start timer (criar antes de _atualizar_jogadores)
	_auto_start_timer = Timer.new()
	_auto_start_timer.one_shot = false
	_auto_start_timer.wait_time = 1.0
	_auto_start_timer.timeout.connect(_on_auto_start_tick)
	add_child(_auto_start_timer)
	# Inicializar ping timer (host faz ping periódico)
	_ping_timer = Timer.new()
	_ping_timer.wait_time = 3.0
	_ping_timer.timeout.connect(_enviar_ping)
	add_child(_ping_timer)
	# Preencher lista de jogadores (retry progressivo se os dados Steam ainda não estiverem prontos)
	_atualizar_jogadores()
	if _player_rows.is_empty():
		get_tree().create_timer(0.3).timeout.connect(_retry_jogadores)
		get_tree().create_timer(1.0).timeout.connect(_retry_jogadores)
		get_tree().create_timer(2.5).timeout.connect(_retry_jogadores)
	steam_manager.member_joined.connect(_on_member_joined)
	steam_manager.member_left.connect(_on_member_left)
	steam_manager.lobby_data_updated.connect(_on_lobby_data_updated)
	steam_manager.lobby_left.connect(_on_lobby_left)
	steam_manager.kicked.connect(_on_kicked)
	if steam_manager.is_host:
		Steam.setLobbyJoinable(steam_manager.lobby_id, true)
		_ping_timer.start()

func _setup_tree():
	player_tree.clear()
	_player_rows.clear()
	var root = player_tree.create_item()
	root.set_text(0, "")
	root.set_text(1, "Players (%d)" % steam_manager.get_lobby_member_count() if steam_manager.lobby_id != 0 else "Players")
	root.set_text(2, "")
	root.set_text(3, "")
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
	chat_input.placeholder_text = tr("CHAT_PLACEHOLDER")
	chat_send_btn.text = tr("CHAT_SEND")

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
	return "---"

func _retry_jogadores():
	_atualizar_jogadores()
	if _player_rows.is_empty():
		logger.warn("LobbyScreen", "Player list still empty after retry, lobby_id=%s" % steam_manager.lobby_id)

func _atualizar_jogadores():
	if steam_manager.lobby_id == 0:
		logger.warn("LobbyScreen", "_atualizar_jogadores: lobby_id=0, skipping")
		return
	var count = steam_manager.get_lobby_member_count()
	var owner_id = steam_manager.get_lobby_owner()
	logger.info("LobbyScreen", "_atualizar_jogadores count=%d owner=%s rows=%d" % [count, owner_id, _player_rows.size()])
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
	var root = player_tree.get_root()
	if not root:
		root = player_tree.create_item()
		root.set_text(0, "")
		root.set_text(1, "Players")
		root.set_text(2, "")
		root.set_text(3, "")
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
		var nome_colorido = nome
		if sid == owner_id:
			nome_colorido = "★ " + nome
		if sid == steam_manager.steam_id:
			nome_colorido = "[%s]" % nome
		if _player_rows.has(sid):
			var item = _player_rows[sid]
			item.set_checked(0, is_ready)
			item.set_text(1, nome_colorido)
			item.set_text(2, ping)
			item.set_text(3, badges)
		else:
			var item = player_tree.create_item(root)
			item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			item.set_checked(0, is_ready)
			item.set_editable(0, false)
			item.set_text(1, nome_colorido)
			item.set_text(2, ping)
			item.set_text(3, badges)
			item.set_metadata(0, sid)
			_player_rows[sid] = item
	config_btn.visible = steam_manager.is_host
	start_btn.visible = steam_manager.is_host
	if steam_manager.is_host != era_host:
		ready_btn.disabled = steam_manager.is_host
		if not steam_manager.is_host:
			player_actions.visible = false
	logger.info("LobbyScreen", "%d players in lobby" % count)
	if not _auto_start_timer.is_stopped():
		status_label.text = "Starting in %ds..." % _auto_start_seconds
	elif steam_manager.is_host and count > 0:
		var all_ready = true
		for sid in active_sids:
			if Steam.getLobbyMemberData(steam_manager.lobby_id, sid, "ready") != "true":
				all_ready = false
				break
		if all_ready:
			if _auto_start_timer.is_stopped():
				_start_auto_countdown()
		else:
			_cancel_auto_start()
			status_label.text = tr("LOBBY_PLAYERS") % [count, max_count]
	else:
		status_label.text = tr("LOBBY_PLAYERS") % [count, max_count]
	# Forçar refresh visual da Tree
	player_tree.queue_redraw()
	# Mostrar dados crus no debug_label
	var dbg = "lobby=%s count=%d owner=%s is_host=%s\n" % [steam_manager.lobby_id, count, owner_id, steam_manager.is_host]
	for sid in active_sids:
		var n = Steam.getFriendPersonaName(sid)
		var r = Steam.getLobbyMemberData(steam_manager.lobby_id, sid, "ready")
		dbg += "  %s (%s) ready=%s\n" % [n, sid, r]
	debug_label.text = dbg

func _on_player_selected():
	var selected = player_tree.get_selected()
	if not selected:
		return
	var sid = selected.get_metadata(0)
	if not sid is int:
		return
	_selected_sid = sid as int
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
	_cancel_auto_start()
	logger.info("LobbyScreen", "Host: starting race via P2P")
	status_label.text = tr("LOBBY_STARTING")
	start_btn.disabled = true
	Steam.setLobbyJoinable(steam_manager.lobby_id, false)
	_enviar_iniciar_corrida.rpc()

func _start_auto_countdown():
	_auto_start_seconds = 15
	_auto_start_timer.start()
	_update_auto_start_ui()

func _cancel_auto_start():
	if not _auto_start_timer.is_stopped():
		_auto_start_timer.stop()
	_auto_start_seconds = 0
	start_btn.text = tr("LOBBY_START_RACE")
	start_btn.disabled = false

func _on_auto_start_tick():
	_auto_start_seconds -= 1
	if _auto_start_seconds <= 0:
		_auto_start_timer.stop()
		_enviar_iniciar_corrida.rpc()
	else:
		_update_auto_start_ui()

func _update_auto_start_ui():
	start_btn.text = "Auto %ds" % _auto_start_seconds
	status_label.text = "Starting in %ds..." % _auto_start_seconds

@rpc("any_peer", "call_local", "reliable")
func _enviar_iniciar_corrida():
	_cancel_auto_start()
	logger.info("LobbyScreen", "Race start RPC received by peer %s" % multiplayer.get_unique_id())
	status_label.text = tr("LOBBY_STARTING")
	if not steam_manager.is_host:
		ready_btn.disabled = true
	start_btn.disabled = true
	logger.info("LobbyScreen", "Loading race scene...")
	scene_manager.goto_scene("res://scenes/race/race_scene.tscn", scene_manager.TransitionType.FADE_BLACK)

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

# --- RPC Ping ---

func _enviar_ping():
	if not steam_manager.is_host or multiplayer.multiplayer_peer == null:
		return
	_envia_pingo.rpc()

@rpc("any_peer", "call_remote", "unreliable")
func _envia_pingo():
	var sender_peer = multiplayer.get_remote_sender_id()
	_volta_pong.rpc_id(sender_peer, steam_manager.steam_id)

@rpc("any_peer", "call_remote", "unreliable")
func _volta_pong(from_sid: int):
	if not steam_manager.is_host:
		return
	_pings[from_sid] = "<50ms"
	_atualizar_jogadores()

# --- Chat ---

func _on_chat_send_btn():
	_on_chat_send(chat_input.text)

func _on_chat_send(text: String):
	var msg = text.strip_edges()
	if msg.is_empty():
		chat_input.text = ""
		return
	if steam_manager.initialized and steam_manager.lobby_id != 0:
		Steam.sendLobbyChatMsg(steam_manager.lobby_id, msg)
	chat_input.text = ""

func _on_lobby_chat_message(sender: int, message: String):
	var nome = Steam.getFriendPersonaName(sender)
	chat_display.append_text("[b]%s:[/b] %s\n" % [nome, message])

func _on_member_joined(sid: int):
	_atualizar_jogadores()
	var nome = Steam.getFriendPersonaName(sid)
	chat_display.append_text("[color=gray]%s %s[/color]\n" % [nome, tr("CHAT_JOINED")])

func _on_member_left(sid: int):
	_atualizar_jogadores()
	var nome = Steam.getFriendPersonaName(sid)
	chat_display.append_text("[color=gray]%s %s[/color]\n" % [nome, tr("CHAT_LEFT")])

func _on_lobby_data_updated(_member_id: int):
	_atualizar_jogadores()

func _on_kicked(_lobby_id: int):
	logger.warn("LobbyScreen", "Was kicked from lobby")
	status_label.text = tr("LOBBY_KICKED")

func _exit_tree():
	if _ping_timer:
		_ping_timer.stop()
	if _auto_start_timer:
		_auto_start_timer.stop()

func _on_lobby_left():
	logger.info("LobbyScreen", "Left lobby, back to menu")
	scene_manager.goto_scene("res://scenes/ui/main_menu.tscn")
