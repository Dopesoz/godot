extends Node
## Корневой узел игры: собирает мир, камеру, ввод, системы и интерфейс.

var world: GameWorld = null
var camera: GameCamera = null
var touch: TouchInput = null
var build_controller: BuildController = null
var simulation: Simulation = null
var save_system: SaveSystem = null
var hud: Hud = null
var build_menu: BuildMenu = null
var build_bar: BuildBar = null


func _ready() -> void:
	Log.info("Drone Factory %s, движок %s" % [
		ProjectSettings.get_setting("application/config/version", "?"),
		Engine.get_version_info().string,
	])

	world = GameWorld.new()
	world.name = "World"
	add_child(world)

	camera = GameCamera.new()
	camera.name = "Camera"
	world.add_child(camera)

	touch = TouchInput.new()
	touch.name = "TouchInput"
	touch.camera = camera
	add_child(touch)

	build_controller = BuildController.new()
	build_controller.name = "BuildController"
	add_child(build_controller)

	simulation = Simulation.new()
	simulation.name = "Simulation"
	simulation.add_system(PowerSystem.new())
	simulation.add_system(BuildingSystem.new())
	simulation.add_system(ResearchSystem.new())
	simulation.add_system(LogisticsSystem.new())
	add_child(simulation)

	world.simulation = simulation

	save_system = SaveSystem.new()
	save_system.name = "SaveSystem"
	add_child(save_system)

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)

	build_menu = BuildMenu.new()
	build_menu.name = "BuildMenu"
	add_child(build_menu)

	build_bar = BuildBar.new()
	build_bar.name = "BuildBar"
	add_child(build_bar)

	hud.build_menu_requested.connect(build_menu.open)

	if SaveSystem.has_save():
		start_new_game(int(Time.get_unix_time_from_system()))
		if not save_system.load_game():
			Log.warn("Сохранение не загрузилось, начинаем новую игру")
			start_new_game(int(Time.get_unix_time_from_system()))
	else:
		start_new_game(int(Time.get_unix_time_from_system()))

	touch.tapped.connect(build_controller.on_tap)
	touch.long_pressed.connect(build_controller.on_long_press)
	Events.notify.connect(func(text: String) -> void: Log.debug("Сообщение: " + text))


func start_new_game(seed_value: int) -> void:
	var start: Vector2i = world.new_game(seed_value)
	simulation.setup(world)
	simulation.reset()
	build_controller.setup(world, camera)
	GameSetup.create_starting_base(world)

	save_system.setup(world, simulation, camera)
	hud.setup(world, simulation)
	build_menu.setup(build_controller, world.research)
	build_bar.setup(build_controller)

	camera.focus_on_cell(start)
	world.update_view(camera.visible_world_rect())
	world.terrain_renderer.flush_pending()

	Log.info("Мир готов: старт %s, зданий %d, чанков %d" % [
		start, world.buildings.count(), world.terrain_renderer.loaded_chunk_count(),
	])


func _process(_delta: float) -> void:
	# Стриминг идёт за камерой. Вызов дешёвый: если видимая область не
	# изменилась, мир выходит сразу.
	world.update_view(camera.visible_world_rect())


## Android убивает свёрнутое приложение без предупреждения, поэтому
## сохраняемся при уходе в фон, а не только при выходе.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, \
		NOTIFICATION_WM_CLOSE_REQUEST:
			if save_system != null:
				save_system.save_on_exit()
		_:
			pass
