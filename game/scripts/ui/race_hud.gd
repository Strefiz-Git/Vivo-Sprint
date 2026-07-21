extends CanvasLayer

@onready var speed_label: Label = $SpeedLabel
@onready var lap_label: Label = $LapLabel
@onready var position_label: Label = $PositionLabel
@onready var time_label: Label = $TimeLabel
@onready var best_lap_label: Label = $BestLapLabel
@onready var sector_label: Label = $SectorLabel
@onready var delta_label: Label = $DeltaLabel
@onready var countdown_label: Label = $CountdownLabel
@onready var standings_container: VBoxContainer = $StandingsContainer

var _race_start_ms: int = 0
var _last_lap_ms: int = 0
var _best_lap_ms: int = 0


func _ready() -> void:
	add_to_group("race_hud")
	race_manager.race_countdown_tick.connect(_on_countdown_tick)
	race_manager.race_started.connect(_on_race_started)
	race_manager.lap_completed.connect(_on_lap_completed)
	race_manager.sector_time_recorded.connect(_on_sector_time)
	race_manager.standings_updated.connect(_on_standings_updated)
	race_manager.car_finished_race.connect(_on_car_finished)
	visible = true


func _process(_delta: float) -> void:
	if race_manager.race_active and _race_start_ms > 0:
		var elapsed: int = Time.get_ticks_msec() - _race_start_ms
		time_label.text = "Tempo: %s" % _format_time(elapsed)


func update_speed(speed_kmh: float) -> void:
	speed_label.text = "%d km/h" % int(speed_kmh)


func update_position(pos: int, total: int) -> void:
	position_label.text = "Pos: %dº / %d" % [pos, total]


func _on_countdown_tick(seconds_left: int) -> void:
	if seconds_left > 0:
		countdown_label.visible = true
		countdown_label.text = str(seconds_left)
	else:
		countdown_label.visible = false


func _on_race_started() -> void:
	_race_start_ms = Time.get_ticks_msec()
	lap_label.text = "Volta 0 / %d" % race_manager.total_laps


func _on_lap_completed(car_id: int, lap_number: int, lap_time_ms: int, is_best_lap: bool) -> void:
	if car_id != multiplayer.get_unique_id():
		return
	_last_lap_ms = lap_time_ms
	lap_label.text = "Volta %d / %d" % [lap_number, race_manager.total_laps]
	if is_best_lap:
		_best_lap_ms = lap_time_ms
		best_lap_label.text = "Melhor: %s" % _format_time(lap_time_ms)


func _on_sector_time(car_id: int, sector_index: int, sector_time_ms: int) -> void:
	if car_id != multiplayer.get_unique_id():
		return
	sector_label.text = "Sector %d: %s" % [sector_index + 1, _format_time(sector_time_ms)]


func _on_standings_updated(standings: Array) -> void:
	for child in standings_container.get_children():
		child.queue_free()
	for i in range(standings.size()):
		var entry: Dictionary = standings[i]
		var label := Label.new()
		var prefix: String = "P%d " % (i + 1)
		var suffix: String = ""
		if entry.get("finished", false):
			suffix = " [FIN]"
		elif entry.get("best_lap_ms", 0) > 0:
			suffix = " [%s]" % _format_time(entry["best_lap_ms"])
		label.text = "%sL%d S%d%s" % [prefix, entry["lap"], entry["sector"], suffix]
		standings_container.add_child(label)


func _on_car_finished(car_id: int, position: int) -> void:
	if car_id == multiplayer.get_unique_id():
		countdown_label.visible = true
		countdown_label.text = "%dº Lugar!" % position


func _format_time(ms: int) -> String:
	var total_seconds: float = ms / 1000.0
	var minutes: int = int(total_seconds) / 60
	var seconds: float = fmod(total_seconds, 60.0)
	return "%02d:%06.3f" % [minutes, seconds]
