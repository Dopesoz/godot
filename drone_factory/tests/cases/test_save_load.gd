extends TestCase
## Сохранение и загрузка: полный цикл, атомарность, устойчивость к мусору.

var world: GameWorld = null
var simulation: Simulation = null
var camera: GameCamera = null
var saves: SaveSystem = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	world.simulation = simulation
	simulation.add_system(PowerSystem.new())
	simulation.add_system(BuildingSystem.new())
	simulation.add_system(ResearchSystem.new())
	simulation.add_system(LogisticsSystem.new())

	world.new_game(8080)
	simulation.setup(world)

	camera = GameCamera.new()
	camera.view_size_override = Vector2(720, 1280)
	world.add_child(camera)
	camera.focus_on_cell(world.start_cell)

	saves = SaveSystem.new()
	saves.autosave_enabled = false
	Engine.get_main_loop().root.add_child(saves)
	saves.setup(world, simulation, camera)


func after_each() -> void:
	SaveSystem.delete_save()
	if is_instance_valid(saves):
		saves.free()
	if is_instance_valid(simulation):
		simulation.free()
	if is_instance_valid(world):
		world.free()
	world = null
	simulation = null
	camera = null
	saves = null


## Строит небольшую фабрику, состояние которой должно пережить сохранение.
func build_factory() -> Dictionary:
	var patch: Vector2i = world.start_cell + Vector2i(8, 8)
	for dy: int in 2:
		for dx: int in 2:
			world.grid.set_ore(patch + Vector2i(dx, dy), TileTypes.Ore.IRON, 500)
	var drill: Building = world.buildings.place(BuildingDefs.DRILL, patch)
	var furnace: Furnace = world.buildings.place(BuildingDefs.FURNACE, patch + Vector2i(3, 0)) as Furnace
	furnace.set_recipe(Recipes.SMELT_IRON, 7)
	furnace.input.add(Items.IRON_ORE, 12)
	# Печи и буру нужна энергия, иначе фабрика будет стоять и до, и после загрузки.
	world.buildings.place(BuildingDefs.SOLAR, patch + Vector2i(3, 3))
	world.buildings.place(BuildingDefs.SOLAR, patch + Vector2i(6, 0))
	var port: DronePort = world.buildings.place(BuildingDefs.DRONE_PORT, patch + Vector2i(0, 4)) as DronePort
	port.output.add(Items.DRONE, 2)
	port.on_world_ready(world.grid)
	world.research.complete(Technologies.MINING_1)
	world.grid.extract_ore(patch, 123)
	return {"drill": drill, "furnace": furnace, "port": port, "patch": patch}


func test_round_trip_restores_world() -> void:
	var factory: Dictionary = build_factory()
	var patch: Vector2i = factory["patch"]
	var ore_left: int = world.grid.get_ore_amount(patch)
	simulation.game_time = 123.5
	simulation.tick_count = 1235
	camera.set_zoom_level(3.0, false)

	check(saves.save_game(), "сохранение должно проходить")
	check(SaveSystem.has_save(), "файл сохранения должен появиться")

	# Полностью новая игра, затем загрузка.
	world.new_game(1)
	simulation.setup(world)
	check(saves.load_game(), "загрузка должна проходить")

	check_eq(world.world_seed, 8080, "сид должен восстановиться")
	check_eq(world.grid.get_ore_amount(patch), ore_left, "выработанная руда должна сохраниться")
	check_eq(world.buildings.count(), 5, "все здания должны восстановиться")
	check_almost(simulation.game_time, 123.5, 0.01)
	check_eq(simulation.tick_count, 1235)
	check_almost(camera.get_zoom_level(), 3.0, 0.01)
	check(world.research.is_completed(Technologies.MINING_1), "исследования должны сохраняться")

	var furnace: Furnace = world.buildings.at_cell(patch + Vector2i(3, 0)) as Furnace
	check(furnace != null, "печь должна восстановиться на своём месте")
	check_eq(furnace.current_recipe(), Recipes.SMELT_IRON)
	check_eq(int(furnace.queue[0]["count"]), 7, "очередь производства должна сохраняться")
	check_eq(furnace.input.count(Items.IRON_ORE), 12)

	var port: DronePort = world.buildings.at_cell(patch + Vector2i(0, 4)) as DronePort
	check(port != null and port.drone_count() == 2, "флот дронов должен сохраняться")


func test_simulation_continues_after_load() -> void:
	build_factory()
	saves.save_game()
	world.new_game(1)
	simulation.setup(world)
	saves.load_game()

	# После загрузки мир обязан ожить сам, без вмешательства игрока.
	for i: int in 200:
		simulation.tick()
	var furnace: Furnace = null
	for building: Building in world.buildings.all():
		if building is Furnace:
			furnace = building
	check(furnace != null)
	check(furnace.output.count(Items.IRON_PLATE) > 0, "производство должно продолжиться после загрузки")


func test_save_file_is_reasonably_small() -> void:
	build_factory()
	saves.save_game()
	var file: FileAccess = FileAccess.open(Constants.SAVE_FILE, FileAccess.READ)
	var size: int = file.get_length()
	file.close()
	# Мир 512x512 целиком: на телефоне это должно оставаться сотнями килобайт,
	# а не мегабайтами, иначе автосохранение начнёт подвешивать игру.
	check(size < 700_000, "файл сохранения %d байт — слишком много" % size)


func test_save_is_atomic() -> void:
	build_factory()
	saves.save_game()
	var first: String = FileAccess.get_file_as_string(Constants.SAVE_FILE)

	# Временный файл не должен оставаться на диске после успешной записи.
	check(not FileAccess.file_exists(Constants.SAVE_FILE + ".tmp"), "временный файл должен исчезать")
	saves.save_game()
	var second: String = FileAccess.get_file_as_string(Constants.SAVE_FILE)
	check(second.length() > 0, "повторное сохранение не должно оставлять пустой файл")
	check(first.length() > 0)


func test_corrupted_save_is_rejected() -> void:
	DirAccess.make_dir_recursive_absolute(Constants.SAVE_DIR)
	var file: FileAccess = FileAccess.open(Constants.SAVE_FILE, FileAccess.WRITE)
	file.store_string("{ это не json")
	file.close()
	check(not saves.load_game(), "повреждённый файл не должен загружаться")


func test_wrong_version_is_rejected() -> void:
	var data: Dictionary = saves.collect()
	data["version"] = Constants.SAVE_FORMAT_VERSION + 99
	check(not saves.apply(data), "сохранение чужой версии должно отклоняться")


func test_missing_save_is_not_an_error() -> void:
	SaveSystem.delete_save()
	check(not SaveSystem.has_save())
	check(not saves.load_game(), "отсутствие сохранения — обычная ситуация")


func test_events_are_emitted() -> void:
	var saved: Array[int] = [0]
	var loaded: Array[int] = [0]
	var on_saved := func() -> void: saved[0] += 1
	var on_loaded := func() -> void: loaded[0] += 1
	Events.game_saved.connect(on_saved)
	Events.game_loaded.connect(on_loaded)

	saves.save_game()
	saves.load_game()

	Events.game_saved.disconnect(on_saved)
	Events.game_loaded.disconnect(on_loaded)
	check_eq(saved[0], 1)
	check_eq(loaded[0], 1)


func test_autosave_fires_on_interval() -> void:
	saves.autosave_enabled = true
	saves._process(SaveSystem.AUTOSAVE_INTERVAL - 1.0)
	check(not SaveSystem.has_save(), "до интервала автосохранения быть не должно")
	saves._process(2.0)
	check(SaveSystem.has_save(), "автосохранение должно сработать по интервалу")


func test_drone_reservations_survive_load() -> void:
	var factory: Dictionary = build_factory()
	var storage: Building = world.buildings.place(BuildingDefs.STORAGE, factory["patch"] + Vector2i(-4, 0))
	storage.output.add(Items.IRON_ORE, 50)
	world.buildings.place(BuildingDefs.SOLAR, factory["patch"] + Vector2i(6, 7))
	for i: int in 20:
		simulation.tick()

	saves.save_game()
	world.new_game(1)
	simulation.setup(world)
	check(saves.load_game())

	var logistics: LogisticsSystem = simulation.get_system(LogisticsSystem) as LogisticsSystem
	var in_flight: int = 0
	for building: Building in world.buildings.all():
		if building is DronePort:
			for drone: Drone in (building as DronePort).drones:
				if drone.is_busy() and drone.cargo_count > 0:
					in_flight += 1
	if in_flight > 0:
		check(
			not logistics._incoming.is_empty(),
			"брони летящих дронов должны восстанавливаться, иначе ресурсы задвоятся"
		)


func test_ui_sees_research_after_restart() -> void:
	# То, на что жаловался игрок: здания на месте, а дерево технологий пустое.
	# Причина была не в записи, а в подмене объектов при загрузке: интерфейс
	# продолжал смотреть на состояние прежней партии. Поэтому проверяем именно
	# то, что видит игрок, а не только содержимое файла.
	SaveSystem.delete_save()
	var first: Node = load("res://scenes/main.tscn").instantiate()
	Engine.get_main_loop().root.add_child(first)
	first.start_new_game(5150)
	first.world.research.complete(Technologies.STEAM_POWER)
	first.world.research.complete(Technologies.ELECTRONICS)
	first.world.stats.add(GameStats.produced_key(Items.IRON_PLATE), 42)
	check(first.save_system.save_game(), "игра должна сохраниться")
	first.free()

	# Второй запуск приложения: сцена собирается заново и подхватывает файл.
	var second: Node = load("res://scenes/main.tscn").instantiate()
	Engine.get_main_loop().root.add_child(second)

	check(
		second.world.research.is_completed(Technologies.STEAM_POWER),
		"изученное должно пережить перезапуск"
	)
	check(
		second.build_menu.research.is_completed(Technologies.STEAM_POWER),
		"меню строительства смотрит на устаревшее состояние исследований"
	)
	check(
		second.research_panel.state.is_completed(Technologies.ELECTRONICS),
		"панель исследований смотрит на устаревшее состояние"
	)
	check_eq(
		second.build_controller.pool.stores().size(),
		ResourcePool.new(second.world.buildings).stores().size(),
		"строительство считает ресурсы по устаревшему реестру зданий"
	)
	check(
		second.world.stats.total_of(Items.IRON_PLATE) >= 42,
		"статистика партии потерялась при загрузке"
	)
	second.free()
	SaveSystem.delete_save()
