extends Control

@onready var name_input: LineEdit = $VBoxContainer/name_input
@onready var player_slider: HSlider = $VBoxContainer/player_slider
@onready var player_label: Label = $VBoxContainer/player_label
@onready var password_input: LineEdit = $VBoxContainer/password_input
@onready var visibility_option: OptionButton = $VBoxContainer/visibility_option
@onready var create_btn: Button = $VBoxContainer/HBoxContainer/create_btn
@onready var back_btn: Button = $VBoxContainer/HBoxContainer/back_btn
@onready var status_label: Label = $VBoxContainer/status_label

func _ready():
	logger.info("LobbyCreate", "Create lobby scene opened")
	_apply_texts()
	name_input.text = "%s's Lobby" % steam_manager.steam_name
	player_slider.value_changed.connect(func(v):
		player_label.text = tr("CREATE_PLAYERS") % v
	)
	player_slider.value = 8
	player_label.text = tr("CREATE_PLAYERS") % 8
	visibility_option.add_item(tr("VISIBILITY_PUBLIC"), Steam.LOBBY_TYPE_PUBLIC)
	visibility_option.add_item(tr("VISIBILITY_FRIENDS"), Steam.LOBBY_TYPE_FRIENDS_ONLY)
	visibility_option.add_item(tr("VISIBILITY_PRIVATE"), Steam.LOBBY_TYPE_PRIVATE)
	visibility_option.add_item(tr("VISIBILITY_INVISIBLE"), Steam.LOBBY_TYPE_INVISIBLE)
	visibility_option.select(0)
	steam_manager.lobby_created.connect(_on_lobby_created)
	steam_manager.lobby_joined.connect(_on_lobby_joined)
	steam_manager.lobby_join_failed.connect(_on_join_failed)

func _apply_texts():
	$VBoxContainer/title.text = tr("CREATE_TITLE")
	$VBoxContainer/name_label.text = tr("CREATE_NAME_LABEL")
	name_input.placeholder_text = tr("CREATE_NAME_PLACEHOLDER")
	$VBoxContainer/password_label.text = tr("CREATE_PASSWORD_LABEL")
	$VBoxContainer/vis_label.text = tr("CREATE_VIS_LABEL")
	create_btn.text = tr("CREATE_CREATE")
	back_btn.text = tr("CREATE_BACK")

func _on_create_pressed():
	if not steam_manager.initialized:
		status_label.text = tr("CREATE_OFFLINE")
		return
	var name_val = name_input.text.strip_edges()
	if name_val.is_empty():
		name_val = "%s's Lobby" % steam_manager.steam_name
	var max_p = int(player_slider.value)
	var pass_val = password_input.text.strip_edges()
	var vis = visibility_option.get_selected_id()
	logger.info("LobbyCreate", "Creating lobby: name='%s' max=%d pass='%s' vis=%d" % [name_val, max_p, pass_val, vis])
	status_label.text = tr("CREATE_CREATING")
	create_btn.disabled = true
	steam_manager.pending_lobby_name = name_val
	steam_manager.pending_lobby_password = pass_val
	steam_manager.create_lobby(vis, max_p)

func _on_lobby_created(lobby_id: int):
	logger.info("LobbyCreate", "Lobby created: %s" % lobby_id)
	if steam_manager.pending_lobby_name:
		steam_manager.set_lobby_name(steam_manager.pending_lobby_name)
	if steam_manager.pending_lobby_password:
		steam_manager.set_lobby_password(steam_manager.pending_lobby_password)
	steam_manager.pending_lobby_name = ""
	steam_manager.pending_lobby_password = ""
	status_label.text = tr("CREATE_CREATED") % lobby_id
	create_btn.disabled = false

func _on_join_failed(reason: String):
	logger.warn("LobbyCreate", "Failed to join: %s" % reason)
	status_label.text = tr("CREATE_FAILED") % reason
	create_btn.disabled = false

func _on_lobby_joined(_lobby_id: int):
	logger.info("LobbyCreate", "Joined lobby, navigating to lobby_screen")
	scene_manager.goto_scene("res://scenes/ui/lobby_screen.tscn")

func _on_back_pressed():
	logger.info("LobbyCreate", "Back to menu")
	scene_manager.goto_scene("res://scenes/ui/main_menu.tscn")
