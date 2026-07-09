extends Control

@onready var status_label: Label = $VBoxContainer/lbl_status
func _ready():
	logger.info("MainMenu", "Main menu started")
	_apply_texts()
	if steam_manager.initialized:
		status_label.text = tr("MENU_STATUS_ONLINE")
	else:
		status_label.text = tr("MENU_STATUS_OFFLINE")

func _apply_texts():
	$VBoxContainer/title.text = tr("MENU_TITLE")
	$VBoxContainer/btn_singleplayer.text = tr("MENU_SINGLEPLAYER")
	$VBoxContainer/btn_multiplayer.text = tr("MENU_MULTIPLAYER")
	$VBoxContainer/btn_settings.text = tr("MENU_SETTINGS")
	$VBoxContainer/btn_quit.text = tr("MENU_QUIT")

func _on_multiplayer_pressed():
	logger.info("MainMenu", "Multiplayer -> lobby browser")
	scene_manager.goto_scene("res://scenes/ui/lobby_browser.tscn")

func _on_settings_pressed():
	logger.info("MainMenu", "Settings")
	scene_manager.goto_scene("res://scenes/ui/settings.tscn")

func _on_quit_pressed():
	logger.info("MainMenu", "Quit game")
	get_tree().quit()
