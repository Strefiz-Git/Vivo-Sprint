extends Node

const STAT_PLAYTIME_SECONDS: String = "total_playtime_seconds"

var _session_start_time: float = 0.0
var _pending_store: bool = false

func _ready() -> void:
	_session_start_time = Time.get_unix_time_from_system()
	get_tree().root.close_requested.connect(_on_game_closing)

# --- Achievements ---

func unlock_achievement(achievement_id: String, immediate_store: bool = true) -> bool:
	if not steam_manager.initialized:
		return false
	var current: Dictionary = Steam.getAchievement(achievement_id)
	if current.get("achieved", false):
		return true
	if not Steam.setAchievement(achievement_id):
		logger.error("SteamAchievements", "Failed to set: %s" % achievement_id)
		return false
	if immediate_store:
		store_stats()
	else:
		_pending_store = true
	return true

func is_achievement_unlocked(achievement_id: String) -> bool:
	if not steam_manager.initialized:
		return false
	return Steam.getAchievement(achievement_id).get("achieved", false)

func show_achievement_progress(achievement_id: String, current: int, target: int) -> void:
	if not steam_manager.initialized:
		return
	if current >= target:
		unlock_achievement(achievement_id)
	else:
		Steam.indicateAchievementProgress(achievement_id, current, target)

func debug_reset_achievement(achievement_id: String) -> void:
	if not steam_manager.initialized:
		return
	Steam.clearAchievement(achievement_id)
	store_stats()

# --- Stats ---

func set_stat_int(stat_name: String, value: int, immediate_store: bool = false) -> void:
	if not steam_manager.initialized:
		return
	Steam.setStatInt(stat_name, value)
	if immediate_store:
		store_stats()
	else:
		_pending_store = true

func get_stat_int(stat_name: String) -> int:
	if not steam_manager.initialized:
		return 0
	return Steam.getStatInt(stat_name)

func set_stat_float(stat_name: String, value: float, immediate_store: bool = false) -> void:
	if not steam_manager.initialized:
		return
	Steam.setStatFloat(stat_name, value)
	if immediate_store:
		store_stats()
	else:
		_pending_store = true

func get_stat_float(stat_name: String) -> float:
	if not steam_manager.initialized:
		return 0.0
	return Steam.getStatFloat(stat_name)

func sync_stat_int(stat_name: String, local_value: int) -> int:
	var steam_value: int = get_stat_int(stat_name)
	if local_value > steam_value:
		set_stat_int(stat_name, local_value)
		return local_value
	return steam_value

func store_stats() -> void:
	if not steam_manager.initialized:
		return
	if Steam.storeStats():
		_pending_store = false
	else:
		logger.error("SteamAchievements", "Failed to store stats")

# --- Playtime ---

func get_current_session_seconds() -> int:
	return int(Time.get_unix_time_from_system() - _session_start_time)

func get_total_playtime_seconds() -> int:
	return get_stat_int(STAT_PLAYTIME_SECONDS) + get_current_session_seconds()

func _on_game_closing() -> void:
	var total: int = get_stat_int(STAT_PLAYTIME_SECONDS) + get_current_session_seconds()
	set_stat_int(STAT_PLAYTIME_SECONDS, total, true)
