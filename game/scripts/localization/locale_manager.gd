extends Node

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "pt"

func _ready():
	_load_translations()
	var saved = _load_locale()
	TranslationServer.set_locale(saved)

func _load_translations():
	var paths := [
		"res://translations/translations.en.translation",
		"res://translations/translations.pt.translation"
	]
	for p in paths:
		var res = load(p)
		if res:
			TranslationServer.add_translation(res)

func set_locale(locale: String):
	TranslationServer.set_locale(locale)
	_save_locale(locale)
	locale_changed.emit(locale)

func get_locale() -> String:
	return TranslationServer.get_locale()

func _load_locale() -> String:
	var cfg = ConfigFile.new()
	if cfg.load("user://locale.cfg") == OK:
		return cfg.get_value("locale", "code", DEFAULT_LOCALE)
	return DEFAULT_LOCALE

func _save_locale(locale: String):
	var cfg = ConfigFile.new()
	cfg.set_value("locale", "code", locale)
	cfg.save("user://locale.cfg")
