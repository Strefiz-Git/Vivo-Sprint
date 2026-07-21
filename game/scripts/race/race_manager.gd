extends Node

const SECTORS_PER_LAP: int = 3

signal race_countdown_tick(seconds_left: int)
signal race_started
signal race_finished(finishing_order: Array)
signal sector_time_recorded(car_id: int, sector_index: int, sector_time_ms: int)
signal lap_completed(car_id: int, lap_number: int, lap_time_ms: int, is_best_lap: bool)
signal car_finished_race(car_id: int, position: int)
signal standings_updated(standings: Array)

var total_laps: int = 3
var race_active: bool = false

var _progress: Dictionary = {}
var _finish_order: Array = []


func register_car(car_id: int) -> void:
	if _progress.has(car_id):
		return
	_progress[car_id] = _new_progress_entry()


func unregister_car(car_id: int) -> void:
	_progress.erase(car_id)
	_finish_order.erase(car_id)


func _new_progress_entry() -> Dictionary:
	return {
		"current_lap": 0,
		"next_sector": 0,
		"sector_times": [0, 0, 0],
		"best_lap_ms": 0,
		"last_lap_ms": 0,
		"lap_start_ms": 0,
		"sector_start_ms": 0,
		"finished": false,
	}


func start_race(laps: int = 3) -> void:
	if not multiplayer.is_server():
		return
	total_laps = laps
	race_active = false
	_finish_order.clear()
	for car_id in _progress.keys():
		_progress[car_id] = _new_progress_entry()
	_run_countdown()


func _run_countdown() -> void:
	for seconds_left in [3, 2, 1]:
		_broadcast_countdown.rpc(seconds_left)
		await get_tree().create_timer(1.0).timeout
	_broadcast_countdown.rpc(0)
	_begin_timing.rpc()


@rpc("authority", "call_local", "reliable")
func _broadcast_countdown(seconds_left: int) -> void:
	race_countdown_tick.emit(seconds_left)


@rpc("authority", "call_local", "reliable")
func _begin_timing() -> void:
	race_active = true
	var now: int = Time.get_ticks_msec()
	for car_id in _progress.keys():
		_progress[car_id]["lap_start_ms"] = now
		_progress[car_id]["sector_start_ms"] = now
	race_started.emit()


func report_checkpoint_crossed(car_id: int, sector_index: int) -> void:
	if not multiplayer.is_server():
		return
	if not race_active:
		return
	if not _progress.has(car_id):
		register_car(car_id)

	var p: Dictionary = _progress[car_id]
	if p["finished"]:
		return

	if sector_index != p["next_sector"]:
		return

	var now: int = Time.get_ticks_msec()
	var sector_time: int = now - p["sector_start_ms"]
	p["sector_times"][sector_index] = sector_time
	p["sector_start_ms"] = now

	_notify_sector.rpc(car_id, sector_index, sector_time)

	if sector_index == SECTORS_PER_LAP - 1:
		_complete_lap(car_id, p, now)
	else:
		p["next_sector"] += 1

	_broadcast_standings()


func _complete_lap(car_id: int, p: Dictionary, now: int) -> void:
	var lap_time: int = now - p["lap_start_ms"]
	var is_best: bool = p["best_lap_ms"] == 0 or lap_time < p["best_lap_ms"]

	p["last_lap_ms"] = lap_time
	if is_best:
		p["best_lap_ms"] = lap_time
	p["current_lap"] += 1
	p["next_sector"] = 0
	p["lap_start_ms"] = now

	_notify_lap.rpc(car_id, p["current_lap"], lap_time, is_best)

	if p["current_lap"] >= total_laps:
		p["finished"] = true
		_finish_order.append(car_id)
		_notify_finish.rpc(car_id, _finish_order.size())

		if _finish_order.size() == _progress.size():
			_notify_race_finished.rpc(_finish_order)


@rpc("authority", "call_local", "reliable")
func _notify_sector(car_id: int, sector_index: int, sector_time_ms: int) -> void:
	sector_time_recorded.emit(car_id, sector_index, sector_time_ms)


@rpc("authority", "call_local", "reliable")
func _notify_lap(car_id: int, lap_number: int, lap_time_ms: int, is_best_lap: bool) -> void:
	lap_completed.emit(car_id, lap_number, lap_time_ms, is_best_lap)


@rpc("authority", "call_local", "reliable")
func _notify_finish(car_id: int, position: int) -> void:
	car_finished_race.emit(car_id, position)


@rpc("authority", "call_local", "reliable")
func _notify_race_finished(finishing_order: Array) -> void:
	race_active = false
	race_finished.emit(finishing_order)


func _broadcast_standings() -> void:
	_sync_standings.rpc(get_standings())


@rpc("authority", "call_local", "reliable")
func _sync_standings(standings: Array) -> void:
	standings_updated.emit(standings)


func get_standings() -> Array:
	var entries: Array = []
	for car_id in _progress.keys():
		var p: Dictionary = _progress[car_id]
		entries.append({
			"car_id": car_id,
			"lap": p["current_lap"],
			"sector": p["next_sector"],
			"best_lap_ms": p["best_lap_ms"],
			"last_lap_ms": p["last_lap_ms"],
			"finished": p["finished"],
		})
	entries.sort_custom(func(a, b):
		if a["lap"] != b["lap"]:
			return a["lap"] > b["lap"]
		return a["sector"] > b["sector"]
	)
	return entries


func get_car_progress(car_id: int) -> Dictionary:
	return _progress.get(car_id, {})
