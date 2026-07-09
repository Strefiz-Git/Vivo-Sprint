extends Node

const SETTINGS_FILE := "user://settings.cfg"

enum WindowMode { WINDOWED, FULLSCREEN, BORDERLESS }

var master_volume: float = 1.0:
	set(v): master_volume = clampf(v, 0.0, 1.0)
var sfx_volume: float = 1.0:
	set(v): sfx_volume = clampf(v, 0.0, 1.0)
var music_volume: float = 0.7:
	set(v): music_volume = clampf(v, 0.0, 1.0)
var resolution: Vector2i = Vector2i(1920, 1080)
var window_mode: WindowMode = WindowMode.WINDOWED
var vsync: bool = true
var max_fps: int = 0:
	set(v): max_fps = maxi(v, 0)
var quality_preset: int = 2

var input_bindings: Dictionary = {}

func _ready():
	load_settings()

func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()
		get_tree().quit()

func save_settings():
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("video", "resolution_x", resolution.x)
	cfg.set_value("video", "resolution_y", resolution.y)
	cfg.set_value("video", "window_mode", window_mode)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "max_fps", max_fps)
	cfg.set_value("video", "quality_preset", quality_preset)
	cfg.save(SETTINGS_FILE)

func load_settings():
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_FILE) != OK:
		apply_all()
		return
	master_volume = cfg.get_value("audio", "master_volume", 1.0)
	sfx_volume = cfg.get_value("audio", "sfx_volume", 1.0)
	music_volume = cfg.get_value("audio", "music_volume", 0.7)
	resolution = Vector2i(
		cfg.get_value("video", "resolution_x", 1920),
		cfg.get_value("video", "resolution_y", 1080)
	)
	window_mode = cfg.get_value("video", "window_mode", WindowMode.WINDOWED)
	vsync = cfg.get_value("video", "vsync", true)
	max_fps = cfg.get_value("video", "max_fps", 0)
	quality_preset = cfg.get_value("video", "quality_preset", 2)
	apply_all()

func apply_all():
	apply_audio()
	apply_video()

func apply_audio():
	var bus_idx_master := AudioServer.get_bus_index("Master")
	var bus_idx_sfx := AudioServer.get_bus_index("SFX")
	var bus_idx_music := AudioServer.get_bus_index("Music")
	if bus_idx_master >= 0:
		AudioServer.set_bus_volume_db(bus_idx_master, linear_to_db(master_volume))
	if bus_idx_sfx >= 0:
		AudioServer.set_bus_volume_db(bus_idx_sfx, linear_to_db(sfx_volume))
	if bus_idx_music >= 0:
		AudioServer.set_bus_volume_db(bus_idx_music, linear_to_db(music_volume))

func apply_video():
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	match window_mode:
		WindowMode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		WindowMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(resolution)
	Engine.max_fps = 0 if max_fps == 0 else max_fps

func rebind_action(action: String, event: InputEvent):
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	input_bindings[action] = event

func get_binding(action: String) -> InputEvent:
	if input_bindings.has(action):
		return input_bindings[action]
	var events = InputMap.action_get_events(action)
	return events[0] if events.size() > 0 else null

func reset_to_defaults():
	master_volume = 1.0
	sfx_volume = 1.0
	music_volume = 0.7
	resolution = Vector2i(1920, 1080)
	window_mode = WindowMode.WINDOWED
	vsync = true
	max_fps = 0
	quality_preset = 2
	apply_all()

func get_max_fps_for_display() -> int:
	return max_fps

func set_max_fps_from_slider(val: int):
	max_fps = 0 if val >= 360 else val
	Engine.max_fps = 0 if max_fps == 0 else max_fps

func get_fps_slider_value() -> int:
	return 360 if max_fps == 0 else max_fps
