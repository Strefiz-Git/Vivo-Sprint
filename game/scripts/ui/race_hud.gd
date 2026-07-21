extends CanvasLayer

const HUD_CONFIG_PATH: String = "user://hud_settings.cfg"

@onready var _top_panel: PanelContainer = $TopPanel
@onready var _lap_label: Label = $TopPanel/VBoxContainer/LapLabel
@onready var _position_label: Label = $TopPanel/VBoxContainer/PositionLabel
@onready var _time_label: Label = $TopPanel/VBoxContainer/TimeLabel
@onready var _best_lap_label: Label = $TopPanel/VBoxContainer/BestLapLabel
@onready var _gear_label: Label = $InfoPanel/HBoxContainer/GearLabel
@onready var _rpm_label: Label = $InfoPanel/HBoxContainer/RpmLabel
@onready var _damage_bar: ProgressBar = $InfoPanel/HBoxContainer/DamageBar
@onready var _fuel_bar: ProgressBar = $InfoPanel/HBoxContainer/FuelBar
@onready var _countdown_label: Label = $CountdownLabel
@onready var _speedometer: Control = $Speedometer
@onready var _minimap: Control = $Minimap
@onready var _standings: Control = $Standings
@onready var _minimap_config_panel: PanelContainer = $MinimapConfig
@onready var _minimap_size_slider: HSlider = $MinimapConfig/MarginContainer/VBoxContainer/SizeRow/SizeSlider
@onready var _minimap_opacity_slider: HSlider = $MinimapConfig/MarginContainer/VBoxContainer/OpacityRow/OpacitySlider
@onready var _minimap_zoom_slider: HSlider = $MinimapConfig/MarginContainer/VBoxContainer/ZoomRow/ZoomSlider

var _countdown_tween: Tween
var _race_start_ms: int = 0
var _total_laps: int = 3
var _current_lap: int = 0
var _local_car: Node3D = null
var _minimap_mode: int = 0

var speedometer_enabled: bool = true
var standings_enabled: bool = true
var minimap_enabled: bool = true
var _minimap_config_open: bool = false


func _ready() -> void:
	add_to_group("race_hud")
	_load_config()
	_apply_visibility()
	_connect_slider_signals()
	_connect_race_signals()


func _process(delta: float) -> void:
	_update_speedometer()
	_update_local_car_reference()
	_update_info_bar()
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
	elif event.is_action_pressed("hud_minimap_config"):
		_toggle_minimap_config()


func _connect_slider_signals() -> void:
	_minimap_size_slider.value_changed.connect(_on_config_size_changed)
	_minimap_opacity_slider.value_changed.connect(_on_config_opacity_changed)
	_minimap_zoom_slider.value_changed.connect(_on_config_zoom_changed)
	var close_btn: Button = $MinimapConfig/MarginContainer/VBoxContainer/CloseBtn
	close_btn.pressed.connect(_on_config_close)


func _connect_race_signals() -> void:
	race_manager.race_countdown_tick.connect(_on_countdown_tick)
	race_manager.race_started.connect(_on_race_started)
	race_manager.lap_completed.connect(_on_lap_completed)
	race_manager.sector_time_recorded.connect(_on_sector_time)
	race_manager.standings_updated.connect(_on_standings_updated)
	race_manager.car_finished_race.connect(_on_car_finished)


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


func _update_info_bar() -> void:
	if not _local_car or not is_instance_valid(_local_car):
		return
	if _gear_label:
		var gear: int = _local_car.get("_current_gear") if _local_car.has_method("get") else 0
		_gear_label.text = "G %d" % gear
	if _rpm_label:
		var vel: float = _local_car.linear_velocity.length()
		var rpm_pct: float = clampf(vel / 30.0, 0.0, 1.0)
		var rpm_val: int = int(lerpf(800.0, 7000.0, rpm_pct))
		_rpm_label.text = "%d RPM" % rpm_val
	if _damage_bar:
		var dmg: float = _local_car.get("_damage_total") if _local_car.has_method("get") else 0.0
		_damage_bar.value = dmg * 100.0
	if _fuel_bar:
		var fuel: float = _local_car.get("_fuel_litres") if _local_car.has_method("get") else 60.0
		_fuel_bar.value = fuel


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


func _on_countdown_tick(seconds_left: int) -> void:
	if not _countdown_label:
		return
	if _countdown_tween and _countdown_tween.is_valid():
		_countdown_tween.kill()
	if seconds_left > 0:
		_countdown_label.visible = true
		_countdown_label.text = str(seconds_left)
		_countdown_label.modulate = Color.WHITE
		_countdown_tween = create_tween()
		_countdown_tween.tween_property(_countdown_label, "modulate", Color(1, 1, 1, 0.3), 0.8)
		_countdown_tween.tween_property(_countdown_label, "modulate", Color.WHITE, 0.1)
	elif seconds_left == 0:
		_countdown_label.visible = true
		_countdown_label.text = "GO!"
		_countdown_label.modulate = Color(0.2, 1.0, 0.3)
		_countdown_tween = create_tween()
		_countdown_tween.tween_interval(1.0)
		_countdown_tween.tween_property(_countdown_label, "modulate:a", 0.0, 0.5)
		_countdown_tween.tween_callback(func() -> void: _countdown_label.visible = false)


func _on_race_started() -> void:
	_race_start_ms = Time.get_ticks_msec()
	_total_laps = race_manager.total_laps


func _on_lap_completed(car_id: int, lap_number: int, lap_time_ms: int, is_best_lap: bool) -> void:
	if car_id != multiplayer.get_unique_id():
		return
	_current_lap = lap_number
	if _lap_label:
		_lap_label.text = "VOLTA %d / %d" % [lap_number, _total_laps]
	if is_best_lap and _best_lap_label:
		_best_lap_label.text = "MELHOR %s" % units_manager.format_time(lap_time_ms)
		_best_lap_label.modulate = Color(1.0, 0.85, 0.2)


func _on_sector_time(_car_id: int, _sector_index: int, _sector_time_ms: int) -> void:
	pass


func _on_standings_updated(standings: Array) -> void:
	if _standings:
		_standings.update_standings(standings)
	for i in range(standings.size()):
		var entry: Dictionary = standings[i]
		if entry.get("car_id", 0) == multiplayer.get_unique_id():
			if _position_label:
				_position_label.text = "POS %d/%d" % [i + 1, standings.size()]
			break


func _on_car_finished(car_id: int, position: int) -> void:
	if car_id == multiplayer.get_unique_id() and _countdown_label:
		_countdown_label.visible = true
		_countdown_label.text = "%dº" % position
		_countdown_label.modulate = Color(1.0, 0.85, 0.2)


func _toggle_minimap_config() -> void:
	_minimap_config_open = not _minimap_config_open
	_minimap_config_panel.visible = _minimap_config_open
	if _minimap_config_open:
		_sync_config_sliders()


func _sync_config_sliders() -> void:
	if _minimap and _minimap_size_slider:
		_minimap_size_slider.value = _minimap.mini_size.x
	if _minimap and _minimap_opacity_slider:
		_minimap_opacity_slider.value = _minimap.minimap_opacity * 100.0
	if _minimap and _minimap_zoom_slider:
		_minimap_zoom_slider.value = _minimap.get_zoom_value()


func _on_config_size_changed(value: float) -> void:
	if _minimap:
		_minimap.set_minimap_size(value)
	_save_config()


func _on_config_opacity_changed(value: float) -> void:
	if _minimap:
		_minimap.set_opacity(value / 100.0)
	_save_config()


func _on_config_zoom_changed(value: float) -> void:
	if _minimap:
		_minimap.set_zoom_value(value)
	_save_config()


func _on_config_close() -> void:
	_minimap_config_open = false
	_minimap_config_panel.visible = false


func _apply_visibility() -> void:
	if _speedometer:
		_speedometer.visible = speedometer_enabled
	if _minimap:
		_minimap.visible = minimap_enabled
	if _standings:
		_standings.visible = standings_enabled


func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(HUD_CONFIG_PATH) != OK:
		return
	speedometer_enabled = cfg.get_value("hud", "speedometer", true)
	standings_enabled = cfg.get_value("hud", "standings", true)
	minimap_enabled = cfg.get_value("hud", "minimap", true)
	_minimap_mode = cfg.get_value("hud", "minimap_mode", 0)
	units_manager.current_system = cfg.get_value("hud", "unit_system", 0)
	var minimap_size_val: float = cfg.get_value("hud", "minimap_size", 180.0)
	var minimap_opacity_val: float = cfg.get_value("hud", "minimap_opacity", 0.75)
	var minimap_zoom_val: float = cfg.get_value("hud", "minimap_zoom", 60.0)
	if _minimap:
		_minimap.set_minimap_size(minimap_size_val)
		_minimap.set_opacity(minimap_opacity_val)
		_minimap.set_zoom_value(minimap_zoom_val)


func _save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("hud", "speedometer", speedometer_enabled)
	cfg.set_value("hud", "standings", standings_enabled)
	cfg.set_value("hud", "minimap", minimap_enabled)
	cfg.set_value("hud", "minimap_mode", _minimap_mode)
	cfg.set_value("hud", "unit_system", units_manager.current_system)
	if _minimap:
		cfg.set_value("hud", "minimap_size", _minimap.mini_size.x)
		cfg.set_value("hud", "minimap_opacity", _minimap.minimap_opacity)
		cfg.set_value("hud", "minimap_zoom", _minimap.get_zoom_value())
	cfg.save(HUD_CONFIG_PATH)
