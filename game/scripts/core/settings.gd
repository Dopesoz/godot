extends Node

## Player preferences: volumes, and anything else that is a matter of taste
## rather than a matter of the world.
##
## Kept apart from the save file on purpose. A saved game is a city; these are
## the settings of the person playing it, and they should survive starting a new
## city, deleting the old one, or losing it. So they live in their own small
## file and are written the moment they change — nobody expects to press "save"
## after turning the music down.

const PATH := "user://settings.cfg"
const SECTION := "audio"

## Emitted whenever anything changes, so the menu and the mixer can both react
## without knowing about each other.
signal changed()

var music_volume: float = 0.55
var sfx_volume: float = 0.5
var muted: bool = false
## Empty means "whatever the device is set to". Stored rather than guessed every
## start, because a player who picked English on a Russian phone meant it.
var locale: String = ""


func _ready() -> void:
	load_settings()
	apply_locale()


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	music_volume = clampf(float(file.get_value(SECTION, "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(file.get_value(SECTION, "sfx", sfx_volume)), 0.0, 1.0)
	muted = bool(file.get_value(SECTION, "muted", muted))
	locale = String(file.get_value("game", "locale", locale))
	apply_locale()
	changed.emit()


func save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, "music", music_volume)
	file.set_value(SECTION, "sfx", sfx_volume)
	file.set_value(SECTION, "muted", muted)
	file.set_value("game", "locale", locale)
	file.save(PATH)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply()


func set_muted(value: bool) -> void:
	muted = value
	_apply()


## Which language the interface speaks. "" follows the device, which for a
## Russian phone means Russian without anybody choosing anything.
func set_locale(value: String) -> void:
	locale = value
	apply_locale()
	_apply()


func apply_locale() -> void:
	# `--lang ru` overrides everything, so a screenshot or a test can ask for a
	# language without touching the player's saved preference.
	var args := OS.get_cmdline_user_args()
	var flag := args.find("--lang")
	if flag != -1 and flag + 1 < args.size():
		TranslationServer.set_locale(args[flag + 1])
		return
	if locale == "":
		TranslationServer.set_locale(OS.get_locale())
	else:
		TranslationServer.set_locale(locale)


func language_name() -> String:
	match current_language():
		"ru":
			return "Русский"
		_:
			return "English"


## The language actually in force, resolved from the device when none is set.
func current_language() -> String:
	var active := locale if locale != "" else OS.get_locale()
	return "ru" if active.begins_with("ru") else "en"


func _apply() -> void:
	changed.emit()
	save_settings()
