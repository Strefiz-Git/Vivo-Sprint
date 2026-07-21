extends CanvasLayer

const HUD_CONFIG_PATH: String = "user://hud_settings.cfg"

var _speedometer: Control
var _minimap: Control
var _standings: Control
var _speed_label: Label
var _lap_label: Label
var _position_label: Label
var _time_label: Label
var _best_lap_label: Label
var _countdown_label: Label

var _race_start_ms: int = 0
var _total_laps: int = 3
var _current_lap: int = 0
var _local_car: Node3D = null
var _minimap_mode: int = 0

var speedometer_enabled: bool = true
var standings_enabled: bool = true
var minimap_enabled: bool = true


func _ready() -> void:
	add_to_group("race_hud")
	_build_ui()
	_load_config()
	_apply_visibility()
	_connect_signals()
	race_manager.race_countdown_tick.connect(_on_countdown_tick)
	race_manager.race_started.connect(_on_race_started)
	race_manager.lap_completed.connect(_on_lap_completed)
	race_manager.sector_time_recorded.connect(_on_sector_time)
	race_manager.standings_updated.connect(_on_standings_updated)
	race_manager.car_finished_race.connect(_on_car_finished)


func _process(delta: float) -> void:
	_update_speedometer()
	_update_local_car_reference()
	if race_manager.race_active and _race_start_ms > 0:
		var elapsed: int = Time.get_ticks_msec() - _race_start_ms
		if _time_label:
			_time_label.text = units_manager.format_time(elapsed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("hud_toggle_map"):
		_cycle_minimap()
	elif event.is_action_pressed("hud_toggle_speedometer"):
		speedometer_enabled = not speedometer_enabled
		_apply_visibility()
		_save_config()
	elif event.is_action_pressed("hud_toggle_standings"):
		standings_enabled = not standings_enabled
		_apply_visibility()
		_save_config()


func _update_local_car_reference() -> void:
	if _local_car and is_instance_valid(_local_car):
		return
	for car in get_tree().get_nodes_in_group("race_car"):
		if car.has_method("_is_local") and car._is_local():
			_local_car = car
			return
		elif car.get_multiplayer_authority() == multiplayer.get_unique_id():
			_local_car = car
			return


func _update_speedometer() -> void:
	if _speedometer and _speedometer.visible and _local_car and is_instance_valid(_local_car):
		_speedometer.set_speed(_local_car.linear_velocity.length())


func _cycle_minimap() -> void:
	_minimap_mode = (_minimap_mode + 1) % 3
	match _minimap_mode:
		0:
			minimap_enabled = true
			if _minimap:
				_minimap.set_mode(true)
		1:
			minimap_enabled = true
			if _minimap:
				_minimap.set_mode(false)
		2:
			minimap_enabled = false
	_apply_visibility()
	_save_config()


func update_speed(speed_kmh: float) -> void:
	if _speed_label:
		_speed_label.text = "%d %s" % [int(speed_kmh), units_manager.speed_unit()]


func update_speed_mps(mps: float) -> void:
	var display: float = units_manager.speed_to_display(mps)
	if _speed_label:
		_speed_label.text = "%d %s" % [int(display), units_manager.speed_unit()]


func update_lap(current: int, total: int) -> void:
	_current_lap = current
	_total_laps = total
	if _lap_label:
		_lap_label.text = "Volta %d / %d" % [current, total]


func update_position(pos: int, total: int) -> void:
	if _position_label:
		_position_label.text = "Pos: %dº / %d" % [pos, total]


func _on_countdown_tick(seconds_left: int) -> void:
	if _countdown_label:
		if seconds_left > 0:
			_countdown_label.visible = true
			_countdown_label.text = str(seconds_left)
		else:
			_countdown_label.visible = false


func _on_race_started() -> void:
	_race_start_ms = Time.get_ticks_msec()
	_total_laps = race_manager.total_laps
	if _lap_label:
		_lap_label.text = "Volta 0 / %d" % _total_laps


func _on_lap_completed(car_id: int, lap_number: int, lap_time_ms: int, is_best_lap: bool) -> void:
	if car_id != multiplayer.get_unique_id():
		return
	_current_lap = lap_number
	if _lap_label:
		_lap_label.text = "Volta %d / %d" % [lap_number, _total_laps]
	if is_best_lap and _best_lap_label:
		_best_lap_label.text = "Melhor: %s" % units_manager.format_time(lap_time_ms)


func _on_sector_time(car_id: int, sector_index: int, sector_time_ms: int) -> void:
	if car_id != multiplayer.get_unique_id():
		return


func _on_standings_updated(standings: Array) -> void:
	if _standings:
		_standings.update_standings(standings)
	for i in range(standings.size()):
		var entry: Dictionary = standings[i]
		if entry.get("car_id", 0) == multiplayer.get_unique_id():
			update_position(i + 1, standings.size())
			break


func _on_car_finished(car_id: int, position: int) -> void:
	if car_id == multiplayer.get_unique_id() and _countdown_label:
		_countdown_label.visible = true
		_countdown_label.text = "%dº Lugar!" % position


func _build_ui() -> void:
	_build_speed_label()
	_build_lap_label()
	_build_position_label()
	_build_time_label()
	_build_best_lap_label()
	_build_countdown_label()
	_build_speedometer()
	_build_minimap()
	_build_standings()
	_build_info_bar()


func _build_speed_label() -> void:
	_speed_label = Label.new()
	_speed_label.name = "SpeedLabel"
	_speed_label.text = "0 km/h"
	_speed_label.anchor_left = 1.0
	_speed_label.anchor_top = 1.0
	_speed_label.anchor_right = 1.0
	_speed_label.anchor_bottom = 1.0
	_speed_label.offset_left = -160.0
	_speed_label.offset_top = -100.0
	_speed_label.offset_right = -10.0
	_speed_label.offset_bottom = -70.0
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var font := ThemeDB.fallback_font
	_speed_label.add_theme_font_size_override("font_size", 32)
	_speed_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_speed_label)


func _build_lap_label() -> void:
	_lap_label = Label.new()
	_lap_label.name = "LapLabel"
	_lap_label.text = "Volta 0 / 0"
	_lap_label.anchor_left = 0.5
	_lap_label.anchor_right = 0.5
	_lap_label.anchor_top = 0.0
	_lap_label.offset_left = -60.0
	_lap_label.offset_top = 10.0
	_lap_label.offset_right = 60.0
	_lap_label.offset_bottom = 35.0
	_lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lap_label.add_theme_font_size_override("font_size", 16)
	_lap_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	add_child(_lap_label)


func _build_position_label() -> void:
	_position_label = Label.new()
	_position_label.name = "PositionLabel"
	_position_label.text = "Pos: 1º"
	_position_label.anchor_left = 0.5
	_position_label.anchor_right = 0.5
	_position_label.anchor_top = 0.0
	_position_label.offset_left = -60.0
	_position_label.offset_top = 30.0
	_position_label.offset_right = 60.0
	_position_label.offset_bottom = 55.0
	_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_position_label.add_theme_font_size_override("font_size", 18)
	_position_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	add_child(_position_label)


func _build_time_label() -> void:
	_time_label = Label.new()
	_time_label.name = "TimeLabel"
	_time_label.text = "00:00.000"
	_time_label.anchor_left = 0.5
	_time_label.anchor_right = 0.5
	_time_label.anchor_top = 0.0
	_time_label.offset_left = -60.0
	_time_label.offset_top = 52.0
	_time_label.offset_right = 60.0
	_time_label.offset_bottom = 72.0
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 14)
	_time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(_time_label)


func _build_best_lap_label() -> void:
	_best_lap_label = Label.new()
	_best_lap_label.name = "BestLapLabel"
	_best_lap_label.text = "Melhor: --:--.---"
	_best_lap_label.anchor_left = 0.5
	_best_lap_label.anchor_right = 0.5
	_best_lap_label.anchor_top = 0.0
	_best_lap_label.offset_left = -80.0
	_best_lap_label.offset_top = 70.0
	_best_lap_label.offset_right = 80.0
	_best_lap_label.offset_bottom = 90.0
	_best_lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_lap_label.add_theme_font_size_override("font_size", 12)
	_best_lap_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	add_child(_best_lap_label)


func _build_countdown_label() -> void:
	_countdown_label = Label.new()
	_countdown_label.name = "CountdownLabel"
	_countdown_label.text = ""
	_countdown_label.visible = false
	_countdown_label.anchor_left = 0.0
	_countdown_label.anchor_top = 0.0
	_countdown_label.anchor_right = 1.0
	_countdown_label.anchor_bottom = 1.0
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 72)
	_countdown_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_countdown_label)


func _build_speedometer() -> void:
	var scene: PackedScene = load("res://scenes/ui/widgets/speedometer_widget.tscn")
	if scene:
		_speedometer = scene.instantiate()
	else:
		_speedometer = Control.new()
		_speedometer.set_script(load("res://scripts/ui/widgets/speedometer_widget.gd"))
	add_child(_speedometer)


func _build_minimap() -> void:
	var scene: PackedScene = load("res://scenes/ui/widgets/minimap_widget.tscn")
	if scene:
		_minimap = scene.instantiate()
	else:
		_minimap = Control.new()
		_minimap.set_script(load("res://scripts/ui/widgets/minimap_widget.gd"))
	add_child(_minimap)


func _build_standings() -> void:
	var scene: PackedScene = load("res://scenes/ui/widgets/standings_widget.tscn")
	if scene:
		_standings = scene.instantiate()
	else:
		_standings = PanelContainer.new()
		_standings.set_script(load("res://scripts/ui/widgets/standings_widget.gd"))
	add_child(_standings)


func _build_info_bar() -> void:
	pass


func _apply_visibility() -> void:
	if _speedometer:
		_speedometer.visible = speedometer_enabled
	if _minimap:
		_minimap.visible = minimap_enabled
	if _standings:
		_standings.visible = standings_enabled


func _connect_signals() -> void:
	pass


func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(HUD_CONFIG_PATH) != OK:
		return
	speedometer_enabled = cfg.get_value("hud", "speedometer", true)
	standings_enabled = cfg.get_value("hud", "standings", true)
	minimap_enabled = cfg.get_value("hud", "minimap", true)
	_minimap_mode = cfg.get_value("hud", "minimap_mode", 0)
	units_manager.current_system = cfg.get_value("hud", "unit_system", 0)


func _save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("hud", "speedometer", speedometer_enabled)
	cfg.set_value("hud", "standings", standings_enabled)
	cfg.set_value("hud", "minimap", minimap_enabled)
	cfg.set_value("hud", "minimap_mode", _minimap_mode)
	cfg.set_value("hud", "unit_system", units_manager.current_system)
	cfg.save(HUD_CONFIG_PATH)
