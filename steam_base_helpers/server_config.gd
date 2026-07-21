## server_config.gd
## -----------------------------------------------------------------------
## Classe utilitária (não é Node — usa como "class_name" estático) para
## ler a configuração do servidor dedicado a partir de:
##   1. server.cfg (ficheiro de texto ao lado do executável, editável
##      pelo utilizador que hospeda o servidor)
##   2. Argumentos de linha de comandos (têm prioridade sobre o .cfg)
##
## Regista este ficheiro como Autoload com o nome "ServerConfig" (mesmo
## sendo maioritariamente funções estáticas, fica acessível globalmente).
## -----------------------------------------------------------------------
extends Node

const CONFIG_FILENAME: String = "server.cfg"

const DEFAULTS: Dictionary = {
	"name": "Servidor sem nome",
	"port": 27015,
	"max_players": 8,
	"password": "",
	"map": "res://maps/default.tscn",
	"public": false,
}


static func load_config() -> Dictionary:
	var result: Dictionary = DEFAULTS.duplicate()

	var exe_dir: String = OS.get_executable_path().get_base_dir()
	var cfg := ConfigFile.new()
	var err: int = cfg.load(exe_dir.path_join(CONFIG_FILENAME))

	if err == OK:
		result["name"] = cfg.get_value("server", "name", result["name"])
		result["port"] = int(cfg.get_value("server", "port", result["port"]))
		result["max_players"] = int(cfg.get_value("server", "max_players", result["max_players"]))
		result["password"] = cfg.get_value("server", "password", result["password"])
		result["map"] = cfg.get_value("server", "map", result["map"])
		result["public"] = bool(cfg.get_value("server", "public", result["public"]))
	else:
		print("[ServerConfig] %s não encontrado, a usar valores por omissão." % CONFIG_FILENAME)

	# Argumentos de linha de comandos têm sempre prioridade, ex:
	#   ./servidor.x86_64 --headless -- --port=27016 --max_players=32
	for key in result.keys():
		var override = _get_cli_arg(key)
		if override != null:
			result[key] = _cast_like(override, result[key])

	return result


static func _get_cli_arg(arg_name: String):
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % arg_name):
			return arg.trim_prefix("--%s=" % arg_name)
	return null


## Converte a string vinda da linha de comandos para o mesmo tipo do
## valor por omissão (int, bool ou String).
static func _cast_like(raw_value: String, reference_value):
	if reference_value is int:
		return int(raw_value)
	if reference_value is bool:
		return raw_value.to_lower() in ["true", "1", "yes"]
	return raw_value


## Gera um server.cfg de exemplo, útil para incluíres no pacote de
## distribuição do servidor para os utilizadores editarem.
static func write_example_config(path: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("server", "name", "Servidor do Fulano")
	cfg.set_value("server", "port", 27015)
	cfg.set_value("server", "max_players", 16)
	cfg.set_value("server", "password", "")
	cfg.set_value("server", "map", "res://maps/floresta.tscn")
	cfg.set_value("server", "public", true)
	cfg.save(path)
