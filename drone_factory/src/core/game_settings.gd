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
## Режим разработчика: открывает в меню кнопки выдачи ресурсов и технологий.
## Хранится в настройках, а не в сохранении: это свойство пульта, а не партии.
var dev_mode: bool = false

## Громкость 0..1 с шагом в четверть: ползунок пальцем на телефоне неудобен,
## а четырёх ступеней хватает.
var music_volume: float = 0.6
var sfx_volume: float = 0.8
## Масштаб интерфейса и мира. Меньше — больше влезает на экран и меньше
## пикселей рисуется, что заметно на слабых устройствах.
var ui_scale: float = 1.0
## Ограничение кадров: 30 заметно экономит батарею.
var max_fps: int = 60


## Доступ по ключу: панель настроек работает с флагами единообразно и не
## обрастает веткой на каждую настройку.
const FLAGS: Array[StringName] = [&"show_fps", &"autosave", &"keep_screen_on", &"dev_mode"]


func get_flag(key: StringName) -> bool:
	match key:
		&"show_fps":
			return show_fps
		&"autosave":
			return autosave
		&"keep_screen_on":
			return keep_screen_on
		&"dev_mode":
			return dev_mode
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
		&"dev_mode":
			dev_mode = value
		_:
			pass


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	show_fps = bool(config.get_value(SECTION, "show_fps", show_fps))
	autosave = bool(config.get_value(SECTION, "autosave", autosave))
	keep_screen_on = bool(config.get_value(SECTION, "keep_screen_on", keep_screen_on))
	dev_mode = bool(config.get_value(SECTION, "dev_mode", dev_mode))
	music_volume = clampf(float(config.get_value(SECTION, "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value(SECTION, "sfx_volume", sfx_volume)), 0.0, 1.0)
	ui_scale = clampf(float(config.get_value(SECTION, "ui_scale", ui_scale)), 0.75, 1.25)
	max_fps = 30 if int(config.get_value(SECTION, "max_fps", max_fps)) == 30 else 60


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "show_fps", show_fps)
	config.set_value(SECTION, "autosave", autosave)
	config.set_value(SECTION, "keep_screen_on", keep_screen_on)
	config.set_value(SECTION, "dev_mode", dev_mode)
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.set_value(SECTION, "ui_scale", ui_scale)
	config.set_value(SECTION, "max_fps", max_fps)
	config.save(PATH)


## Следующее значение громкости по кругу: 0 -> 25% -> 50% -> 75% -> 100% -> 0.
static func next_volume(value: float) -> float:
	return 0.0 if value >= 0.99 else clampf(snappedf(value + 0.25, 0.25), 0.0, 1.0)


## Следующий масштаб интерфейса по кругу.
static func next_scale(value: float) -> float:
	if value < 0.9:
		return 1.0
	if value < 1.1:
		return 1.25
	return 0.75


## Применяет настройки к системам игры.
func apply(hud: Hud, save_system: SaveSystem, audio: AudioDirector = null) -> void:
	if hud != null:
		hud.show_fps = show_fps
	if save_system != null:
		save_system.autosave_enabled = autosave
	if audio != null:
		audio.music_volume = music_volume
		audio.sfx_volume = sfx_volume
		audio.apply_volumes()
	DisplayServer.screen_set_keep_on(keep_screen_on)
	Engine.max_fps = max_fps
	# Масштаб содержимого меняет и интерфейс, и мир: на слабом устройстве
	# уменьшение заметно снижает число рисуемых пикселей.
	var window: Window = Engine.get_main_loop().root as Window if Engine.get_main_loop() != null else null
	if window != null:
		window.content_scale_factor = ui_scale
