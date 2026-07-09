extends Control

@onready var master_slider: HSlider = $VBoxContainer/AudioSection/master_hbox/master_slider
@onready var master_label: Label = $VBoxContainer/AudioSection/master_hbox/master_value
@onready var sfx_slider: HSlider = $VBoxContainer/AudioSection/sfx_hbox/sfx_slider
@onready var sfx_label: Label = $VBoxContainer/AudioSection/sfx_hbox/sfx_value
@onready var music_slider: HSlider = $VBoxContainer/AudioSection/music_hbox/music_slider
@onready var music_label: Label = $VBoxContainer/AudioSection/music_hbox/music_value

@onready var window_option: OptionButton = $VBoxContainer/VideoSection/window_hbox/window_option
@onready var res_option: OptionButton = $VBoxContainer/VideoSection/res_hbox/res_option
@onready var fps_slider: HSlider = $VBoxContainer/VideoSection/fps_hbox/fps_slider
@onready var fps_label: Label = $VBoxContainer/VideoSection/fps_hbox/fps_value

@onready var lang_option: OptionButton = $VBoxContainer/LangSection/lang_hbox/lang_option

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(3840, 2160),   # 16:9
	Vector2i(3440, 1440),   # 21:9
	Vector2i(2560, 1600),   # 16:10
	Vector2i(2560, 1440),   # 16:9
	Vector2i(2560, 1080),   # 21:9
	Vector2i(1920, 1200),   # 16:10
	Vector2i(1920, 1080),   # 16:9
	Vector2i(1600, 1200),   # 4:3
	Vector2i(1600, 900),    # 16:9
	Vector2i(1280, 1024),   # 5:4
	Vector2i(1280, 960),    # 4:3
	Vector2i(1366, 768),    # 16:9
	Vector2i(1280, 800),    # 16:10
	Vector2i(1280, 768),    # 5:3
	Vector2i(1280, 720),    # 16:9
	Vector2i(1024, 768),    # 4:3
	Vector2i(800, 600),     # 4:3
]

func _ready():
	logger.info("Settings", "Settings scene opened")
	_apply_texts()
	_populate_window_options()
	_populate_resolution_options()
	_populate_lang_options()
	_load_current_values()
	_connect_signals()

func _connect_signals():
	locale_manager.locale_changed.connect(_on_locale_changed)

	master_slider.value_changed.connect(func(v):
		settings.master_volume = v / 100.0
		master_label.text = "%d%%" % v
		settings.apply_audio()
		settings.save_settings()
	)
	sfx_slider.value_changed.connect(func(v):
		settings.sfx_volume = v / 100.0
		sfx_label.text = "%d%%" % v
		settings.apply_audio()
		settings.save_settings()
	)
	music_slider.value_changed.connect(func(v):
		settings.music_volume = v / 100.0
		music_label.text = "%d%%" % v
		settings.apply_audio()
		settings.save_settings()
	)
	window_option.item_selected.connect(_on_window_mode_changed)
	res_option.item_selected.connect(_on_resolution_selected)
	fps_slider.value_changed.connect(_on_fps_changed)
	lang_option.item_selected.connect(_on_lang_selected)

func _apply_texts():
	$VBoxContainer/title.text = tr("SETTINGS_TITLE")

	$VBoxContainer/AudioSection/audio_title.text = tr("SETTINGS_AUDIO")
	$VBoxContainer/AudioSection/master_hbox/master_label.text = tr("SETTINGS_MASTER_VOL")
	$VBoxContainer/AudioSection/sfx_hbox/sfx_label.text = tr("SETTINGS_SFX_VOL")
	$VBoxContainer/AudioSection/music_hbox/music_label.text = tr("SETTINGS_MUSIC_VOL")

	$VBoxContainer/VideoSection/video_title.text = tr("SETTINGS_VIDEO")
	$VBoxContainer/VideoSection/window_hbox/window_label.text = tr("SETTINGS_WINDOW_MODE")
	$VBoxContainer/VideoSection/res_hbox/res_label.text = tr("SETTINGS_RESOLUTION")
	$VBoxContainer/VideoSection/fps_hbox/fps_label.text = tr("SETTINGS_FPS_LIMIT")

	$VBoxContainer/LangSection/lang_title.text = tr("SETTINGS_LANGUAGE")

	$VBoxContainer/back_btn.text = tr("SETTINGS_BACK")

	_update_fps_label()

func _populate_window_options():
	window_option.clear()
	window_option.add_item(tr("SETTINGS_WINDOW_WINDOWED"))
	window_option.add_item(tr("SETTINGS_WINDOW_FULLSCREEN"))
	window_option.add_item(tr("SETTINGS_WINDOW_BORDERLESS"))

func _populate_resolution_options():
	res_option.clear()
	for res in RESOLUTIONS:
		var label = "%dx%d (%s)" % [res.x, res.y, _aspect_ratio_string(res)]
		res_option.add_item(label)
		var idx = res_option.item_count - 1
		res_option.set_item_metadata(idx, res)

static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t = b
		b = a % b
		a = t
	return a

static func _aspect_ratio_string(res: Vector2i) -> String:
	var g = _gcd(res.x, res.y)
	return "%d:%d" % [res.x / g, res.y / g]

func _update_resolution_enabled():
	var disabled = settings.window_mode == settings.WindowMode.BORDERLESS
	res_option.disabled = disabled

func _on_window_mode_changed(idx: int):
	settings.window_mode = idx
	settings.apply_video()
	settings.save_settings()
	_update_resolution_enabled()

func _on_resolution_selected(idx: int):
	var res: Vector2i = res_option.get_item_metadata(idx)
	settings.resolution = res
	settings.apply_video()
	settings.save_settings()

func _populate_lang_options():
	lang_option.clear()
	lang_option.add_item(tr("SETTINGS_LANG_PT"))
	lang_option.add_item(tr("SETTINGS_LANG_EN"))

func _load_current_values():
	master_slider.value = settings.master_volume * 100.0
	master_label.text = "%d%%" % master_slider.value
	sfx_slider.value = settings.sfx_volume * 100.0
	sfx_label.text = "%d%%" % sfx_slider.value
	music_slider.value = settings.music_volume * 100.0
	music_label.text = "%d%%" % music_slider.value

	var fps_val = settings.get_fps_slider_value()
	fps_slider.value = fps_val
	_update_fps_label()

	var current_locale = locale_manager.get_locale()
	lang_option.select(0 if current_locale == "pt" else 1)

	window_option.select(settings.window_mode)
	_update_resolution_enabled()
	_select_current_resolution()

func _select_current_resolution():
	for i in res_option.item_count:
		if res_option.get_item_metadata(i) == settings.resolution:
			res_option.select(i)
			return
	res_option.select(3)

func _update_fps_label():
	var val = int(fps_slider.value)
	if val >= 360:
		fps_label.text = tr("SETTINGS_FPS_UNLIMITED")
	else:
		fps_label.text = "%d FPS" % val

func _on_fps_changed(val: float):
	var int_val = int(val)
	settings.set_max_fps_from_slider(int_val)
	_update_fps_label()
	settings.save_settings()

func _on_lang_selected(idx: int):
	var code = "pt" if idx == 0 else "en"
	locale_manager.set_locale(code)
	settings.save_settings()

func _on_locale_changed(_locale: String):
	_apply_texts()
	_populate_window_options()
	_populate_resolution_options()
	_populate_lang_options()
	var current_locale = locale_manager.get_locale()
	lang_option.select(0 if current_locale == "pt" else 1)
	_select_current_resolution()
	_update_resolution_enabled()

func _on_back_pressed():
	logger.info("Settings", "Back to main menu")
	settings.save_settings()
	scene_manager.goto_scene("res://scenes/ui/main_menu.tscn")
