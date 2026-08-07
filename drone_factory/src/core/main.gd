extends Node
## Корневой узел игры: собирает мир, камеру, ввод, системы и интерфейс.

var world: GameWorld = null
var camera: GameCamera = null
var touch: TouchInput = null
var build_controller: BuildController = null
var simulation: Simulation = null


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
	simulation.add_system(LogisticsSystem.new())
	add_child(simulation)

	world.simulation = simulation

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
