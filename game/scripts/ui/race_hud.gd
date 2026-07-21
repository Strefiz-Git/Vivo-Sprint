extends CanvasLayer

const HUD_CONFIG_PATH: String = "user://hud_settings.cfg"

var _speedometer: Control
var _minimap: Control
var _standings: Control
var _countdown_label: Label
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
var _minimap_config_panel: PanelContainer = null
var _minimap_size_slider: HSlider = null
var _minimap_opacity_slider: HSlider = null
var _minimap_zoom_slider: HSlider = null

var _lap_label: Label
var _position_label: Label
var _time_label: Label
var _best_lap_label: Label
var _gear_label: Label
var _rpm_label: Label
var _damage_bar: ProgressBar
var _fuel_bar: ProgressBar
var _info_panel: PanelContainer
var _top_panel: PanelContainer


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


func _on_sector_time(car_id: int, sector_index: int, sector_time_ms: int) -> void:
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
	if _minimap_config_panel:
		_minimap_config_open = not _minimap_config_open
		_minimap_config_panel.visible = _minimap_config_open
		if _minimap_config_open:
			_sync_config_sliders()
		return
	_build_minimap_config_panel()
	_minimap_config_open = true
	_minimap_config_panel.visible = true
	_sync_config_sliders()


func _build_minimap_config_panel() -> void:
	_minimap_config_panel = PanelContainer.new()
	_minimap_config_panel.name = "MinimapConfig"
	_minimap_config_panel.anchor_left = 0.5
	_minimap_config_panel.anchor_right = 0.5
	_minimap_config_panel.anchor_top = 0.5
	_minimap_config_panel.anchor_bottom = 0.5
	_minimap_config_panel.offset_left = -150.0
	_minimap_config_panel.offset_top = -100.0
	_minimap_config_panel.offset_right = 150.0
	_minimap_config_panel.offset_bottom = 100.0
	_minimap_config_panel.visible = false
	_minimap_config_panel.z_index = 100
	add_child(_minimap_config_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_minimap_config_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Minimap Config"
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var size_row := _create_slider_row("Size", 100.0, 300.0, 180.0)
	_minimap_size_slider = size_row[1]
	vbox.add_child(size_row[0])

	var opacity_row := _create_slider_row("Opacity", 30.0, 100.0, 75.0)
	_minimap_opacity_slider = opacity_row[1]
	vbox.add_child(opacity_row[0])

	var zoom_row := _create_slider_row("Zoom", 20.0, 120.0, 60.0)
	_minimap_zoom_slider = zoom_row[1]
	vbox.add_child(zoom_row[0])

	_minimap_size_slider.value_changed.connect(_on_config_size_changed)
	_minimap_opacity_slider.value_changed.connect(_on_config_opacity_changed)
	_minimap_zoom_slider.value_changed.connect(_on_config_zoom_changed)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_config_close)
	vbox.add_child(close_btn)


func _create_slider_row(label_text: String, min_val: float, max_val: float, default_val: float) -> Array:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label.custom_minimum_size.x = 60.0
	hbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.step = 1.0
	hbox.add_child(slider)

	var value_label := Label.new()
	value_label.text = str(int(default_val))
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.custom_minimum_size.x = 30.0
	hbox.add_child(value_label)

	slider.value_changed.connect(func(val: float) -> void: value_label.text = str(int(val)))

	return [hbox, slider]


func _sync_config_sliders() -> void:
	if _minimap_size_slider and _minimap:
		_minimap_size_slider.value = _minimap.mini_size.x
	if _minimap_opacity_slider and _minimap:
		_minimap_opacity_slider.value = _minimap.minimap_opacity * 100.0
	if _minimap_zoom_slider and _minimap:
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
	if _minimap_config_panel:
		_minimap_config_panel.visible = false


func _build_ui() -> void:
	_build_top_panel()
	_build_countdown_label()
	_build_speedometer()
	_build_minimap()
	_build_standings()
	_build_info_panel()


func _build_top_panel() -> void:
	_top_panel = PanelContainer.new()
	_top_panel.name = "TopPanel"
	_top_panel.anchor_left = 0.5
	_top_panel.anchor_right = 0.5
	_top_panel.anchor_top = 0.0
	_top_panel.offset_left = -120.0
	_top_panel.offset_top = 8.0
	_top_panel.offset_right = 120.0
	_top_panel.offset_bottom = 80.0
	_top_panel.z_index = 10
	add_child(_top_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_top_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_top_panel.add_child(vbox)

	_lap_label = Label.new()
	_lap_label.name = "LapLabel"
	_lap_label.text = "VOLTA 0 / 0"
	_lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lap_label.add_theme_font_size_override("font_size", 16)
	_lap_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	vbox.add_child(_lap_label)

	_position_label = Label.new()
	_position_label.name = "PositionLabel"
	_position_label.text = "POS 1/1"
	_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_position_label.add_theme_font_size_override("font_size", 20)
	_position_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	vbox.add_child(_position_label)

	_time_label = Label.new()
	_time_label.name = "TimeLabel"
	_time_label.text = "00:00.000"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 13)
	_time_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	vbox.add_child(_time_label)

	_best_lap_label = Label.new()
	_best_lap_label.name = "BestLapLabel"
	_best_lap_label.text = "MELHOR --:--.---"
	_best_lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_lap_label.add_theme_font_size_override("font_size", 11)
	_best_lap_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	vbox.add_child(_best_lap_label)


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
	_countdown_label.add_theme_font_size_override("font_size", 96)
	_countdown_label.add_theme_color_override("font_color", Color.WHITE)
	_countdown_label.z_index = 50
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


func _build_info_panel() -> void:
	_info_panel = PanelContainer.new()
	_info_panel.name = "InfoPanel"
	_info_panel.anchor_left = 0.5
	_info_panel.anchor_right = 0.5
	_info_panel.anchor_bottom = 1.0
	_info_panel.offset_left = -140.0
	_info_panel.offset_top = -44.0
	_info_panel.offset_right = 140.0
	_info_panel.offset_bottom = -8.0
	_info_panel.z_index = 10
	add_child(_info_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_info_panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_info_panel.add_child(hbox)

	_gear_label = Label.new()
	_gear_label.name = "GearLabel"
	_gear_label.text = "G 0"
	_gear_label.add_theme_font_size_override("font_size", 18)
	_gear_label.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(_gear_label)

	_rpm_label = Label.new()
	_rpm_label.name = "RpmLabel"
	_rpm_label.text = "0 RPM"
	_rpm_label.add_theme_font_size_override("font_size", 12)
	_rpm_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	hbox.add_child(_rpm_label)

	var sep1 := VSeparator.new()
	sep1.custom_minimum_size.x = 1.0
	hbox.add_child(sep1)

	var dmg_label := Label.new()
	dmg_label.text = "DMG"
	dmg_label.add_theme_font_size_override("font_size", 10)
	dmg_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	hbox.add_child(dmg_label)

	_damage_bar = ProgressBar.new()
	_damage_bar.name = "DamageBar"
	_damage_bar.custom_minimum_size = Vector2(50, 8)
	_damage_bar.max_value = 100.0
	_damage_bar.value = 0.0
	_damage_bar.show_percentage = false
	var dmg_style := StyleBoxFlat.new()
	dmg_style.bg_color = Color(0.2, 0.2, 0.25)
	dmg_style.corner_radius_top_left = 2
	dmg_style.corner_radius_top_right = 2
	dmg_style.corner_radius_bottom_left = 2
	dmg_style.corner_radius_bottom_right = 2
	_damage_bar.add_theme_stylebox_override("background", dmg_style)
	var dmg_fill := StyleBoxFlat.new()
	dmg_fill.bg_color = Color(0.9, 0.3, 0.15)
	dmg_fill.corner_radius_top_left = 2
	dmg_fill.corner_radius_top_right = 2
	dmg_fill.corner_radius_bottom_left = 2
	dmg_fill.corner_radius_bottom_right = 2
	_damage_bar.add_theme_stylebox_override("fill", dmg_fill)
	hbox.add_child(_damage_bar)

	var sep2 := VSeparator.new()
	sep2.custom_minimum_size.x = 1.0
	hbox.add_child(sep2)

	var fuel_label := Label.new()
	fuel_label.text = "FUEL"
	fuel_label.add_theme_font_size_override("font_size", 10)
	fuel_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	hbox.add_child(fuel_label)

	_fuel_bar = ProgressBar.new()
	_fuel_bar.name = "FuelBar"
	_fuel_bar.custom_minimum_size = Vector2(50, 8)
	_fuel_bar.max_value = 60.0
	_fuel_bar.value = 60.0
	_fuel_bar.show_percentage = false
	var fuel_style := StyleBoxFlat.new()
	fuel_style.bg_color = Color(0.2, 0.2, 0.25)
	fuel_style.corner_radius_top_left = 2
	fuel_style.corner_radius_top_right = 2
	fuel_style.corner_radius_bottom_left = 2
	fuel_style.corner_radius_bottom_right = 2
	_fuel_bar.add_theme_stylebox_override("background", fuel_style)
	var fuel_fill := StyleBoxFlat.new()
	fuel_fill.bg_color = Color(0.2, 0.7, 0.9)
	fuel_fill.corner_radius_top_left = 2
	fuel_fill.corner_radius_top_right = 2
	fuel_fill.corner_radius_bottom_left = 2
	fuel_fill.corner_radius_bottom_right = 2
	_fuel_bar.add_theme_stylebox_override("fill", fuel_fill)
	hbox.add_child(_fuel_bar)


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
