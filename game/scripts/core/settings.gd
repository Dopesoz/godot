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


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	music_volume = clampf(float(file.get_value(SECTION, "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(file.get_value(SECTION, "sfx", sfx_volume)), 0.0, 1.0)
	muted = bool(file.get_value(SECTION, "muted", muted))
	changed.emit()


func save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, "music", music_volume)
	file.set_value(SECTION, "sfx", sfx_volume)
	file.set_value(SECTION, "muted", muted)
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


func _apply() -> void:
	changed.emit()
	save_settings()
