extends Node

enum Level { DEBUG, INFO, WARN, ERROR }

var _enabled: bool = true
var _min_level: int = Level.DEBUG

func debug(tag: String, msg: String):
	if _enabled and _min_level <= Level.DEBUG:
		print("[%s] %s" % [tag, msg])

func info(tag: String, msg: String):
	if _enabled and _min_level <= Level.INFO:
		print("[%s] %s" % [tag, msg])

func warn(tag: String, msg: String):
	if _enabled and _min_level <= Level.WARN:
		print("[%s] WARN: %s" % [tag, msg])

func error(tag: String, msg: String):
	if _enabled and _min_level <= Level.ERROR:
		print("[%s] ERROR: %s" % [tag, msg])
