extends Node

enum GameMode { PRACTICE, QUALIFYING, RACE, SPRINT, ENDURANCE, TIME_ATTACK }
enum Weather { DRY, DAMP, WET, VERY_WET, FLOODED }
enum TyreCompound { SOFT, MEDIUM, HARD, INTERMEDIATE, FULL_WET }
enum SessionPhase { LOBBY, COUNTDOWN, GREEN_FLAG, FULL_COURSE_YELLOW, RED_FLAG, CHECKERED }
enum LobbyVisibility { PUBLIC, PRIVATE, FRIENDS_ONLY, INVITE_ONLY }

class PlayerInfo:
	var steam_id: int
	var name: String
	var car_index: int = 0
	var colour: Color = Color.WHITE
	var ready: bool = false
	var is_host: bool = false

	func to_dict() -> Dictionary:
		return {
			"steam_id": steam_id,
			"name": name,
			"car_index": car_index,
			"colour": colour.to_html(),
			"ready": ready,
			"is_host": is_host
		}

	static func from_dict(data: Dictionary) -> PlayerInfo:
		var p = PlayerInfo.new()
		p.steam_id = data.get("steam_id", 0)
		p.name = data.get("name", "")
		p.car_index = data.get("car_index", 0)
		p.colour = Color(data.get("colour", "#ffffff"))
		p.ready = data.get("ready", false)
		p.is_host = data.get("is_host", false)
		return p

class SessionConfig:
	var mode: GameMode = GameMode.RACE
	var track: String = ""
	var weather: Weather = Weather.DRY
	var time_of_day: float = 12.0
	var max_players: int = 12
	var laps: int = 10
	var mandatory_pit_stops: int = 0
	var damage_enabled: bool = false
	var lobby_visibility: LobbyVisibility = LobbyVisibility.PUBLIC

	func to_dict() -> Dictionary:
		return {
			"mode": mode,
			"track": track,
			"weather": weather,
			"time_of_day": time_of_day,
			"max_players": max_players,
			"laps": laps,
			"mandatory_pit_stops": mandatory_pit_stops,
			"damage_enabled": damage_enabled,
			"lobby_visibility": lobby_visibility
		}

	static func from_dict(data: Dictionary) -> SessionConfig:
		var s = SessionConfig.new()
		s.mode = data.get("mode", GameMode.RACE) as int
		s.track = data.get("track", "")
		s.weather = data.get("weather", Weather.DRY) as int
		s.time_of_day = data.get("time_of_day", 12.0)
		s.max_players = data.get("max_players", 12)
		s.laps = data.get("laps", 10)
		s.mandatory_pit_stops = data.get("mandatory_pit_stops", 0)
		s.damage_enabled = data.get("damage_enabled", false)
		s.lobby_visibility = data.get("lobby_visibility", LobbyVisibility.PUBLIC) as int
		return s

var session: SessionConfig = SessionConfig.new()
var local_player: PlayerInfo = PlayerInfo.new()
var players: Array[PlayerInfo] = []

signal player_joined(steam_id: int)
signal player_left(steam_id: int)
signal session_started()
signal session_ended()
signal race_phase_changed(phase: SessionPhase)

func reset_session():
	session = SessionConfig.new()
	players.clear()

func add_player(info: PlayerInfo):
	players.append(info)
	player_joined.emit(info.steam_id)

func remove_player(steam_id: int):
	var idx = players.find_custom(func(p): return p.steam_id == steam_id)
	if idx >= 0:
		players.remove_at(idx)
		player_left.emit(steam_id)
