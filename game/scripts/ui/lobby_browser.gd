extends Control

@onready var search_input: LineEdit = $VBoxContainer/search_input
@onready var filter_distance: OptionButton = $VBoxContainer/HBoxFilters/filter_distance
@onready var filter_password: CheckBox = $VBoxContainer/HBoxFilters/filter_password
@onready var lobby_list: ItemList = $VBoxContainer/lobby_list
@onready var refresh_btn: Button = $VBoxContainer/HBoxFilters/refresh_btn
@onready var join_btn: Button = $VBoxContainer/HBoxActions/join_btn
@onready var back_btn: Button = $VBoxContainer/HBoxActions/back_btn
@onready var status_label: Label = $VBoxContainer/status_label

var _all_lobbies: Array[Dictionary] = []

func _ready():
	logger.info("LobbyBrowser", "Browser scene opened")
	_apply_texts()
	join_btn.disabled = true
	filter_distance.add_item(tr("FILTER_CLOSE"), Steam.LOBBY_DISTANCE_FILTER_CLOSE)
	filter_distance.add_item(tr("FILTER_DEFAULT"), Steam.LOBBY_DISTANCE_FILTER_DEFAULT)
	filter_distance.add_item(tr("FILTER_FAR"), Steam.LOBBY_DISTANCE_FILTER_FAR)
	filter_distance.add_item(tr("FILTER_WORLDWIDE"), Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	filter_distance.select(3)
	lobby_list.item_selected.connect(_on_lobby_selected)
	lobby_list.empty_clicked.connect(_on_lobby_deselected)
	steam_manager.lobby_list_received.connect(_on_lobby_list)
	steam_manager.lobby_joined.connect(_on_lobby_joined)
	steam_manager.lobby_join_failed.connect(_on_join_failed)
	_on_refresh_pressed()

func _apply_texts():
	$VBoxContainer/title.text = tr("BROWSER_TITLE")
	$VBoxContainer/btn_criar.text = tr("BROWSER_CREATE")
	search_input.placeholder_text = tr("BROWSER_SEARCH_PLACEHOLDER")
	$VBoxContainer/HBoxFilters/dist_label.text = tr("BROWSER_DISTANCE")
	filter_password.text = tr("BROWSER_NO_PASSWORD")
	refresh_btn.text = tr("BROWSER_REFRESH")
	join_btn.text = tr("BROWSER_JOIN")
	back_btn.text = tr("BROWSER_BACK")

func _on_lobby_selected(_index: int):
	join_btn.disabled = false

func _on_lobby_deselected():
	join_btn.disabled = true

func _on_join_failed(reason: String):
	logger.warn("LobbyBrowser", "Failed to join: %s" % reason)
	status_label.text = tr("BROWSER_FAILED") % reason
	join_btn.disabled = false

func _on_criar_pressed():
	logger.info("LobbyBrowser", "Create lobby")
	scene_manager.goto_scene("res://scenes/ui/lobby_create.tscn")

func _on_refresh_pressed():
	logger.info("LobbyBrowser", "Searching for lobbies...")
	join_btn.disabled = true
	status_label.text = tr("BROWSER_SEARCHING")
	_all_lobbies.clear()
	lobby_list.clear()
	var dist = filter_distance.get_selected_id()
	steam_manager.request_lobby_list_filtered(dist, filter_password.button_pressed)

func _on_lobby_list(lobbies: Array):
	_all_lobbies = lobbies
	_filtrar_lista()
	status_label.text = tr("BROWSER_FOUND") % _all_lobbies.size()
	logger.info("LobbyBrowser", "%d lobbies received" % _all_lobbies.size())

func _filtrar_lista():
	lobby_list.clear()
	join_btn.disabled = true
	var query = search_input.text.strip_edges().to_lower()
	var no_password = filter_password.button_pressed
	for l in _all_lobbies:
		if query and not l.name.to_lower().contains(query):
			continue
		if no_password and l.password != "":
			continue
		var icon = "🔓" if l.password == "" else "🔒"
		var nome = l.name if l.name else tr("BROWSER_NO_NAME")
		lobby_list.add_item("%s %s (%d/%d)" % [icon, nome, l.players, l.max_players])
		var idx = lobby_list.item_count - 1
		lobby_list.set_item_metadata(idx, l.id)

func _on_search_input_changed(_new_text: String):
	_filtrar_lista()

func _on_join_pressed():
	var selected = lobby_list.get_selected_items()
	if selected.size() > 0:
		var meta = lobby_list.get_item_metadata(selected[0])
		logger.info("LobbyBrowser", "Joining lobby %s" % meta)
		status_label.text = tr("BROWSER_ENTERING")
		steam_manager.join_lobby(meta)

func _on_back_pressed():
	logger.info("LobbyBrowser", "Back to menu")
	scene_manager.goto_scene("res://scenes/ui/main_menu.tscn")

func _on_lobby_joined(_lobby_id: int):
	logger.info("LobbyBrowser", "Joined lobby, navigating to lobby_screen")
	scene_manager.goto_scene("res://scenes/ui/lobby_screen.tscn")
