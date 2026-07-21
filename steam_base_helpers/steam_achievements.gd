## steam_achievements.gd
## -----------------------------------------------------------------------
## Autoload responsável por conquistas, estatísticas e contagem de tempo
## de jogo. Os "API Names" das conquistas/stats têm de ser criados
## primeiro no painel do Steamworks (App Admin > Stats & Achievements).
##
## COMO USAR: adiciona como Autoload com o nome "SteamAchievements".
## -----------------------------------------------------------------------
extends Node

const STAT_PLAYTIME_SECONDS: String = "total_playtime_seconds"

var _session_start_time: float = 0.0
var _pending_store: bool = false


func _ready() -> void:
	_session_start_time = Time.get_unix_time_from_system()
	get_tree().root.close_requested.connect(_on_game_closing)


## ---------------------------------------------------------------------
## Conquistas
## ---------------------------------------------------------------------

## Desbloqueia uma conquista pelo "API Name" definido no Steamworks.
## immediate_store: se true, chama storeStats() já (usa com moderação —
## a Valve recomenda espaçar estas chamadas por minutos, não segundos).
func unlock_achievement(achievement_id: String, immediate_store: bool = true) -> bool:
	var current: Dictionary = Steam.getAchievement(achievement_id)
	if current.get("achieved", false):
		return true  # já estava desbloqueada, nada a fazer

	if not Steam.setAchievement(achievement_id):
		printerr("[Achievements] Falha ao definir: %s" % achievement_id)
		return false

	if immediate_store:
		store_stats()
	else:
		_pending_store = true
	return true


func is_achievement_unlocked(achievement_id: String) -> bool:
	return Steam.getAchievement(achievement_id).get("achieved", false)


## Mostra um popup de progresso SEM desbloquear a conquista. Continua a
## teres de chamar unlock_achievement() quando o progresso chegar ao máximo.
func show_achievement_progress(achievement_id: String, current: int, target: int) -> void:
	if current >= target:
		unlock_achievement(achievement_id)
	else:
		Steam.indicateAchievementProgress(achievement_id, current, target)


## Só para testes — nunca chamar isto em builds de produção.
func debug_reset_achievement(achievement_id: String) -> void:
	Steam.clearAchievement(achievement_id)
	store_stats()


## ---------------------------------------------------------------------
## Estatísticas
## ---------------------------------------------------------------------

func set_stat_int(stat_name: String, value: int, immediate_store: bool = false) -> void:
	Steam.setStatInt(stat_name, value)
	if immediate_store:
		store_stats()
	else:
		_pending_store = true


func get_stat_int(stat_name: String) -> int:
	return Steam.getStatInt(stat_name)


func set_stat_float(stat_name: String, value: float, immediate_store: bool = false) -> void:
	Steam.setStatFloat(stat_name, value)
	if immediate_store:
		store_stats()
	else:
		_pending_store = true


func get_stat_float(stat_name: String) -> float:
	return Steam.getStatFloat(stat_name)


## Compara um valor guardado localmente com o do Steam e mantém o maior
## dos dois — útil para não perderes progresso feito offline.
func sync_stat_int(stat_name: String, local_value: int) -> int:
	var steam_value: int = get_stat_int(stat_name)
	if local_value > steam_value:
		set_stat_int(stat_name, local_value)
		return local_value
	return steam_value


## Chama isto em momentos pouco frequentes: fim de ronda, mudança de mapa,
## saída do servidor. Não chames a cada pequena alteração de stat.
func store_stats() -> void:
	if Steam.storeStats():
		_pending_store = false
	else:
		printerr("[Achievements] Falha ao guardar stats no Steam (fica pendente)")


## ---------------------------------------------------------------------
## Horas de jogo (contagem própria, além da automática do Steam)
## ---------------------------------------------------------------------

func get_current_session_seconds() -> int:
	return int(Time.get_unix_time_from_system() - _session_start_time)


func get_total_playtime_seconds() -> int:
	return get_stat_int(STAT_PLAYTIME_SECONDS) + get_current_session_seconds()


func _on_game_closing() -> void:
	var total: int = get_stat_int(STAT_PLAYTIME_SECONDS) + get_current_session_seconds()
	set_stat_int(STAT_PLAYTIME_SECONDS, total, true)
