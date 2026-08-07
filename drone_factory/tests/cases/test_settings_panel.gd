extends TestCase
## Меню паузы и настройки.

var world: GameWorld = null
var simulation: Simulation = null
var camera: GameCamera = null
var saves: SaveSystem = null
var hud: Hud = null
var settings: GameSettings = null
var panel: SettingsPanel = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	world.simulation = simulation
	simulation.add_system(BuildingSystem.new())
	world.new_game(2929)
	simulation.setup(world)

	camera = GameCamera.new()
	camera.view_size_override = Vector2(720, 1280)
	world.add_child(camera)

	saves = SaveSystem.new()
	saves.autosave_enabled = false
	Engine.get_main_loop().root.add_child(saves)
	saves.setup(world, simulation, camera)

	hud = Hud.new()
	Engine.get_main_loop().root.add_child(hud)
	hud.setup(world, simulation)

	settings = GameSettings.new()
	panel = SettingsPanel.new()
	Engine.get_main_loop().root.add_child(panel)
	panel.setup(settings, saves, simulation, hud)


func after_each() -> void:
	SaveSystem.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.PATH))
	for node: Node in [panel, hud, saves, simulation, world]:
		if is_instance_valid(node):
			node.free()
	world = null
	simulation = null
	camera = null
	saves = null
	hud = null
	settings = null
	panel = null


func button(name: String) -> Button:
	return panel.find_child(name, true, false) as Button


func test_opening_menu_pauses_simulation() -> void:
	check(not simulation.paused)
	panel.open()
	check(simulation.paused, "в меню симуляция должна стоять")
	panel.close()
	check(not simulation.paused, "после закрытия симуляция продолжается")


func test_load_button_disabled_without_save() -> void:
	panel.open()
	check(button("LoadButton").disabled, "без сохранения загружать нечего")
	button("SaveButton").pressed.emit()
	check(not button("LoadButton").disabled, "после сохранения загрузка доступна")


func test_save_and_load_from_menu() -> void:
	world.buildings.place(BuildingDefs.STORAGE, world.start_cell + Vector2i(6, 6))
	panel.open()
	button("SaveButton").pressed.emit()
	check(SaveSystem.has_save())

	world.new_game(1)
	simulation.setup(world)
	panel.open()
	button("LoadButton").pressed.emit()
	check_eq(world.world_seed, 2929, "загрузка из меню должна восстанавливать мир")
	check(not panel.is_open(), "после загрузки меню закрывается")


func test_new_game_asks_for_confirmation() -> void:
	var requested: Array[int] = [0]
	panel.new_game_requested.connect(func() -> void: requested[0] += 1)
	panel.open()

	button("NewGameButton").pressed.emit()
	check_eq(requested[0], 0, "первое нажатие только предупреждает")
	check(button("NewGameButton").text.contains("Точно"), "нужен явный вопрос")

	button("NewGameButton").pressed.emit()
	check_eq(requested[0], 1, "второе нажатие запускает новую игру")


func test_new_game_confirmation_resets_on_reopen() -> void:
	panel.open()
	button("NewGameButton").pressed.emit()
	panel.close()
	panel.open()
	check_eq(button("NewGameButton").text, "Новая игра", "подтверждение не должно оставаться взведённым")


func test_toggles_change_and_persist_settings() -> void:
	panel.open()
	var before: bool = settings.show_fps
	button("FpsToggle").pressed.emit()
	check_ne(settings.show_fps, before, "переключатель должен менять настройку")
	check_eq(hud.show_fps, settings.show_fps, "настройка должна применяться к HUD")

	button("AutosaveToggle").pressed.emit()
	check_eq(saves.autosave_enabled, settings.autosave, "автосохранение должно применяться")

	var restored := GameSettings.new()
	restored.load_settings()
	check_eq(restored.show_fps, settings.show_fps, "настройки должны сохраняться на диск")


func test_toggle_labels_show_state() -> void:
	panel.open()
	settings.show_fps = false
	button("FpsToggle").pressed.emit()
	check(button("FpsToggle").text.contains("вкл"), "состояние должно быть подписано")
	button("FpsToggle").pressed.emit()
	check(button("FpsToggle").text.contains("выкл"))


func test_touch_targets() -> void:
	panel.open()
	for name: String in ["SaveButton", "LoadButton", "NewGameButton", "FpsToggle"]:
		check(button(name).custom_minimum_size.y >= UiTheme.TOUCH_MIN, "кнопка %s мелковата" % name)
