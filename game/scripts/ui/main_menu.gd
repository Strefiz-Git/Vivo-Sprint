extends Control

@onready var status_label: Label = $VBoxContainer/lbl_status

func _ready():
	logger.info("MainMenu", "Menu principal iniciado")
	if steam_manager.initialized:
		status_label.text = "Steam: CONECTADO"
	else:
		status_label.text = "Steam: OFFLINE"

func _on_multiplayer_pressed():
	logger.info("MainMenu", "Multiplayer -> lobby browser")
	scene_manager.goto_scene("res://scenes/ui/lobby_browser.tscn")

func _on_quit_pressed():
	logger.info("MainMenu", "Sair do jogo")
	get_tree().quit()
