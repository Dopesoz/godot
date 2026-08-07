class_name GameSettings
extends RefCounted

## Пользовательские настройки, хранятся отдельно от сохранения игры.
##
## Отдельный файл нужен, чтобы настройки переживали «новую игру» и не терялись
## вместе с испорченным сохранением.

const PATH: String = "user://settings.cfg"
const SECTION: String = "game"

var show_fps: bool = false
var autosave: bool = true
## Не гасить экран во время игры: партия идёт долго, а касаний может не быть.
var keep_screen_on: bool = true


## Доступ по ключу: панель настроек работает с флагами единообразно и не
## обрастает веткой на каждую настройку.
const FLAGS: Array[StringName] = [&"show_fps", &"autosave", &"keep_screen_on"]


func get_flag(key: StringName) -> bool:
	match key:
		&"show_fps":
			return show_fps
		&"autosave":
			return autosave
		&"keep_screen_on":
			return keep_screen_on
		_:
			return false


func set_flag(key: StringName, value: bool) -> void:
	match key:
		&"show_fps":
			show_fps = value
		&"autosave":
			autosave = value
		&"keep_screen_on":
			keep_screen_on = value
		_:
			pass


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	show_fps = bool(config.get_value(SECTION, "show_fps", show_fps))
	autosave = bool(config.get_value(SECTION, "autosave", autosave))
	keep_screen_on = bool(config.get_value(SECTION, "keep_screen_on", keep_screen_on))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "show_fps", show_fps)
	config.set_value(SECTION, "autosave", autosave)
	config.set_value(SECTION, "keep_screen_on", keep_screen_on)
	config.save(PATH)


## Применяет настройки к системам игры.
func apply(hud: Hud, save_system: SaveSystem) -> void:
	if hud != null:
		hud.show_fps = show_fps
	if save_system != null:
		save_system.autosave_enabled = autosave
	DisplayServer.screen_set_keep_on(keep_screen_on)
