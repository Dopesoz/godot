extends TestCase
## Бюджет производительности.
##
## Цель — 60 кадров в секунду на слабом Android, то есть 16.6 мс на кадр.
## Настольная машина в тестах быстрее телефона примерно в 3-5 раз, поэтому
## здесь бюджеты жёстче реальных: если тик укладывается в 3 мс на десктопе,
## на телефоне он останется в пределах 10-15 мс, а логический тик идёт лишь
## десять раз в секунду, то есть на кадр приходится его малая часть.

## Размер тестовой фабрики: заметно больше того, что игрок построит за сессию.
const BUILDINGS: int = 320
const PORTS: int = 6

var world: GameWorld = null
var simulation: Simulation = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	world.simulation = simulation
	world.new_game(3030)
	for i: int in world.grid.size * world.grid.size:
		world.grid.terrain[i] = TileTypes.Terrain.GRASS
	simulation.add_system(PowerSystem.new())
	simulation.add_system(BuildingSystem.new())
	simulation.add_system(ResearchSystem.new())
	simulation.add_system(LogisticsSystem.new())
	simulation.setup(world)
	simulation.game_time = 0.0


func after_each() -> void:
	for node: Node in [simulation, world]:
		if is_instance_valid(node):
			node.free()
	world = null
	simulation = null


## Строит большую работающую фабрику: буры на руде, печи, склады, панели, порты.
func build_large_factory() -> void:
	var origin: Vector2i = world.start_cell - Vector2i(60, 60)
	var index: int = 0
	for row: int in 16:
		for column: int in 20:
			if index >= BUILDINGS:
				break
			var cell: Vector2i = origin + Vector2i(column * 6, row * 6)
			var def_id: StringName
			match index % 5:
				0:
					def_id = BuildingDefs.SOLAR
				1:
					def_id = BuildingDefs.FURNACE
				2:
					def_id = BuildingDefs.STORAGE
				3:
					def_id = BuildingDefs.DRILL
					for dy: int in 2:
						for dx: int in 2:
							world.grid.set_ore(cell + Vector2i(dx, dy), TileTypes.Ore.IRON, 5000)
				_:
					def_id = BuildingDefs.SOLAR
			var building: Building = world.buildings.place(def_id, cell)
			if building is Furnace:
				(building as Furnace).set_recipe(Recipes.SMELT_IRON)
				building.input.add(Items.IRON_ORE, 40)
			elif building != null and building.output != null and def_id == BuildingDefs.STORAGE:
				building.output.add(Items.IRON_ORE, 200)
			index += 1

	for i: int in PORTS:
		var port: DronePort = world.buildings.place(
			BuildingDefs.DRONE_PORT, origin + Vector2i(i * 18 + 2, 40)
		) as DronePort
		if port != null:
			port.output.add(Items.DRONE, DronePort.MAX_DRONES)
			port.on_world_ready(world.grid)


func measure_tick_ms(ticks: int) -> float:
	var start_usec: int = Time.get_ticks_usec()
	for i: int in ticks:
		simulation.tick()
	return float(Time.get_ticks_usec() - start_usec) / (1000.0 * float(ticks))


func test_large_factory_tick_budget() -> void:
	build_large_factory()
	check(world.buildings.count() > 250, "фабрика не построилась: %d зданий" % world.buildings.count())
	simulation.tick()

	var per_tick: float = measure_tick_ms(40)
	# Тик идёт 10 раз в секунду: 4 мс на тик — это 4% времени на десктопе
	# и порядка 15% на слабом телефоне.
	#
	# Предел поднят с 3 мс осознанно. Раньше лимит попыток раздачи заданий
	# целиком доставался первым базам в списке, и на фабрике из десятков портов
	# дальние стояли без работы — игрок видел ботов, которые никуда не летят.
	# Честная очередь стоит примерно 0.4 мс на этой (нарочно предельной)
	# фабрике из 326 зданий и 48 курьеров: замерено пятью прогонами, медиана
	# 3.35 мс против 2.96 мс. Работающая логистика этого стоит.
	check(per_tick < 4.0, "тик фабрики из %d зданий: %.2f мс" % [world.buildings.count(), per_tick])
	Log.info("PERF тик: %.2f мс на %d зданий" % [per_tick, world.buildings.count()])


func test_registry_queries_are_cached() -> void:
	build_large_factory()
	# Системы спрашивают выборки каждый тик: без кеша это тысячи аллокаций.
	var start_usec: int = Time.get_ticks_usec()
	for i: int in 1000:
		world.buildings.all()
		world.buildings.of_kind(BuildingDefs.Kind.DRONE_PORT)
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	check(elapsed_ms < 10.0, "1000 выборок заняли %.2f мс — кеш не работает" % elapsed_ms)


func test_cache_invalidates_on_change() -> void:
	build_large_factory()
	var before: int = world.buildings.all().size()
	var storage: Building = world.buildings.place(BuildingDefs.STORAGE, world.start_cell + Vector2i(80, 80))
	check_eq(world.buildings.all().size(), before + 1, "кеш должен обновиться после постройки")
	world.buildings.remove(storage.id)
	check_eq(world.buildings.all().size(), before, "кеш должен обновиться после сноса")


func test_removal_during_iteration_is_safe() -> void:
	# Обычный приём в игровом коде: пройтись по зданиям вида и снести часть.
	build_large_factory()
	var visited: int = 0
	for panel: Building in world.buildings.of_kind(BuildingDefs.Kind.SOLAR):
		visited += 1
		world.buildings.remove(panel.id)
	check(visited > 0, "панели должны найтись")
	check_eq(world.buildings.of_kind(BuildingDefs.Kind.SOLAR).size(), 0, "снос должен пройти по всем")


func test_frame_rendering_budget() -> void:
	build_large_factory()
	simulation.tick()
	var camera := GameCamera.new()
	camera.view_size_override = Vector2(720, 1280)
	world.add_child(camera)
	camera.focus_on_cell(world.start_cell - Vector2i(30, 30))
	world.update_view(camera.visible_world_rect())
	world.terrain_renderer.flush_pending()

	# Кадр без изменений: обновление вида, рисование зданий и дронов.
	var start_usec: int = Time.get_ticks_usec()
	for i: int in 60:
		world.update_view(camera.visible_world_rect())
		world.building_renderer._process(0.016)
		world.drone_renderer._process(0.016)
	var per_frame: float = float(Time.get_ticks_usec() - start_usec) / 60000.0
	check(per_frame < 2.0, "кадровая часть игры: %.2f мс" % per_frame)
	Log.info("PERF кадр: %.2f мс" % per_frame)


func test_chunk_streaming_stays_bounded() -> void:
	build_large_factory()
	var camera := GameCamera.new()
	camera.view_size_override = Vector2(720, 1280)
	world.add_child(camera)
	camera.set_zoom_level(Constants.CAMERA_ZOOM_MIN, false)

	# Пролетаем камерой через полмира: число загруженных чанков не должно расти.
	for step: int in 30:
		camera.focus_on_cell(Vector2i(60 + step * 8, 60 + step * 8))
		world.update_view(camera.visible_world_rect())
		world.terrain_renderer.flush_pending()
	check(
		world.terrain_renderer.loaded_chunk_count() < 60,
		"после пролёта загружено %d чанков" % world.terrain_renderer.loaded_chunk_count()
	)


func test_memory_stays_reasonable() -> void:
	build_large_factory()
	simulation.tick()
	var used_mb: float = float(OS.get_static_memory_usage()) / (1024.0 * 1024.0)
	# Слабые Android-устройства дают приложению порядка 100-200 МБ.
	check(used_mb < 120.0, "занято %.1f МБ памяти" % used_mb)
	Log.info("PERF память: %.1f МБ" % used_mb)


func test_save_time_budget() -> void:
	build_large_factory()
	var camera := GameCamera.new()
	camera.view_size_override = Vector2(720, 1280)
	world.add_child(camera)
	var saves := SaveSystem.new()
	saves.autosave_enabled = false
	Engine.get_main_loop().root.add_child(saves)
	saves.setup(world, simulation, camera)

	var start_usec: int = Time.get_ticks_usec()
	saves.save_game()
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	SaveSystem.delete_save()
	saves.free()
	# Автосохранение делается в кадре: заметная пауза раздражает сильнее,
	# чем редкая потеря пары минут прогресса.
	check(elapsed_ms < 250.0, "сохранение заняло %.0f мс" % elapsed_ms)
	Log.info("PERF сохранение: %.0f мс" % elapsed_ms)
