class_name SettingsPanel
extends UiPanel

## Меню паузы: сохранение, загрузка, новая игра, настройки.
##
## Пока панель открыта, симуляция стоит: игрок ушёл из игрового процесса, и
## продолжать считать фабрику — значит зря греть телефон и рисковать тем, что
## за время в меню что-то сломается незамеченным.

signal new_game_requested()
signal achievements_requested()

var settings: GameSettings = null
var save_system: SaveSystem = null
var simulation: Simulation = null
var hud: Hud = null

var _load_button: Button = null
## Описания переключателей: имя узла -> подпись и ключ настройки.
var _toggles: Dictionary[String, Dictionary] = {}
var _confirm_new_game: bool = false
var _new_game_button: Button = null


func setup(
	game_settings: GameSettings,
	game_save_system: SaveSystem,
	game_simulation: Simulation,
	game_hud: Hud
) -> void:
	settings = game_settings
	save_system = game_save_system
	simulation = game_simulation
	hud = game_hud
	_refresh_toggles()


func _build_content(container: VBoxContainer) -> void:
	set_title("Меню")

	var save_button: Button = UiWidgets.text_button("Сохранить игру", UiTheme.TOUCH_MIN * 4)
	save_button.name = "SaveButton"
	save_button.pressed.connect(_on_save)
	container.add_child(save_button)

	_load_button = UiWidgets.text_button("Загрузить сохранение", UiTheme.TOUCH_MIN * 4)
	_load_button.name = "LoadButton"
	_load_button.pressed.connect(_on_load)
	container.add_child(_load_button)

	_new_game_button = UiWidgets.text_button("Новая игра", UiTheme.TOUCH_MIN * 4)
	_new_game_button.name = "NewGameButton"
	_new_game_button.pressed.connect(_on_new_game)
	container.add_child(_new_game_button)

	var achievements: Button = UiWidgets.text_button("Достижения", UiTheme.TOUCH_MIN * 4)
	achievements.name = "AchievementsButton"
	achievements.pressed.connect(func() -> void: achievements_requested.emit())
	container.add_child(achievements)

	container.add_child(UiWidgets.separator())

	container.add_child(_toggle("FpsToggle", "Счётчик FPS", &"show_fps"))
	container.add_child(_toggle("AutosaveToggle", "Автосохранение", &"autosave"))
	container.add_child(_toggle("ScreenToggle", "Не гасить экран", &"keep_screen_on"))

	container.add_child(UiWidgets.separator())
	container.add_child(UiWidgets.label(
		"Управление: тап — выбрать, перетаскивание — карта, двойной тап и "
		+ "протяжка — приближение, долгое нажатие — отмена.",
		UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM
	))


## Переключатель «подпись + состояние» одной широкой кнопкой: попасть пальцем
## в маленький флажок трудно, а в строку целиком — легко.
func _toggle(node_name: String, caption: String, key: StringName) -> Button:
	var button: Button = UiWidgets.text_button("%s: —" % caption, UiTheme.TOUCH_MIN * 4)
	button.name = node_name
	_toggles[node_name] = {"caption": caption, "key": key}
	button.pressed.connect(func() -> void:
		if settings == null:
			return
		settings.set_flag(key, not settings.get_flag(key))
		_refresh_toggles()
		_apply_settings()
	)
	return button


## Панель строится в _ready(), а настройки приходят позже в setup(): подписи
## переключателей обновляем отдельно.
func _refresh_toggles() -> void:
	if settings == null:
		return
	for node_name: String in _toggles:
		var button: Button = find_child(node_name, true, false) as Button
		if button == null:
			continue
		var entry: Dictionary = _toggles[node_name]
		button.text = "%s: %s" % [
			entry["caption"], "вкл" if settings.get_flag(entry["key"]) else "выкл",
		]


func _on_open() -> void:
	if simulation != null:
		simulation.paused = true
	_load_button.disabled = not SaveSystem.has_save()
	_refresh_toggles()
	_reset_new_game_confirmation()


func close() -> void:
	super()
	if simulation != null:
		simulation.paused = false
	_reset_new_game_confirmation()


func _apply_settings() -> void:
	if settings == null:
		return
	settings.apply(hud, save_system)
	settings.save_settings()


func _on_save() -> void:
	if save_system != null:
		save_system.save_game()
	_load_button.disabled = not SaveSystem.has_save()


func _on_load() -> void:
	if save_system != null and save_system.load_game():
		close()


## Новая игра стирает прогресс, поэтому первое нажатие только предупреждает.
func _on_new_game() -> void:
	if not _confirm_new_game:
		_confirm_new_game = true
		_new_game_button.text = "Точно? Прогресс будет потерян"
		return
	_reset_new_game_confirmation()
	new_game_requested.emit()
	close()


func _reset_new_game_confirmation() -> void:
	_confirm_new_game = false
	if _new_game_button != null:
		_new_game_button.text = "Новая игра"
