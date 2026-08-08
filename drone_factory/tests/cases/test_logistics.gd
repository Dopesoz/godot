extends TestCase
## Логистика дронов: доставка по запросу, вывоз продукции, брони.

var world: GameWorld = null
var simulation: Simulation = null
var logistics: LogisticsSystem = null
var port: DronePort = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(9090)
	for i: int in world.grid.size * world.grid.size:
		world.grid.terrain[i] = TileTypes.Terrain.GRASS

	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	simulation.add_system(PowerSystem.new())
	simulation.add_system(BuildingSystem.new())
	logistics = LogisticsSystem.new()
	simulation.add_system(logistics)
	simulation.setup(world)
	simulation.game_time = 0.0

	port = place(BuildingDefs.DRONE_PORT, Vector2i(0, 0)) as DronePort
	port.output.add(Items.DRONE, 2)
	# Панели, чтобы порт и машины работали.
	place(BuildingDefs.SOLAR, Vector2i(4, 0))
	place(BuildingDefs.SOLAR, Vector2i(4, 3))
	place(BuildingDefs.SOLAR, Vector2i(4, 6))
	simulation.tick()


func after_each() -> void:
	if is_instance_valid(simulation):
		simulation.free()
	if is_instance_valid(world):
		world.free()
	simulation = null
	world = null
	logistics = null
	port = null


func place(def_id: StringName, offset: Vector2i) -> Building:
	return world.buildings.place(def_id, world.start_cell + offset)


func run_ticks(count: int) -> void:
	for i: int in count:
		simulation.tick()


func test_drones_deliver_requested_input() -> void:
	var storage: Building = place(BuildingDefs.STORAGE, Vector2i(-4, 0))
	storage.output.add(Items.IRON_ORE, 60)
	var furnace: Furnace = place(BuildingDefs.FURNACE, Vector2i(0, 5)) as Furnace
	furnace.set_recipe(Recipes.SMELT_IRON)

	run_ticks(200)
	check(furnace.input.count(Items.IRON_ORE) > 0 or furnace.output.count(Items.IRON_PLATE) > 0,
		"дроны не привезли руду в печь")
	check(storage.output.count(Items.IRON_ORE) < 60, "руда должна уходить со склада")


func test_full_production_chain_runs_by_itself() -> void:
	# Бур -> печь -> склад без единого действия игрока.
	var patch: Vector2i = world.start_cell + Vector2i(-6, 6)
	for dy: int in 2:
		for dx: int in 2:
			world.grid.set_ore(patch + Vector2i(dx, dy), TileTypes.Ore.IRON, 400)
	var drill: Building = world.buildings.place(BuildingDefs.DRILL, patch)
	# Буру нужна своя энергия: он далеко от базовой сети. Питание — забота
	# игрока, а не логистики, поэтому ставим панель рядом с ним.
	place(BuildingDefs.SOLAR, Vector2i(-6, 3))
	var furnace: Furnace = place(BuildingDefs.FURNACE, Vector2i(0, 6)) as Furnace
	furnace.set_recipe(Recipes.SMELT_IRON)
	var storage: Building = place(BuildingDefs.STORAGE, Vector2i(-4, 0))

	run_ticks(1200)
	check(drill.status != Building.Status.NO_POWER, "бур должен получить питание от своей панели")
	check(storage.output.count(Items.IRON_PLATE) > 0, "готовые пластины должны оказаться на складе")


func test_producer_output_is_hauled_to_storage() -> void:
	var storage: Building = place(BuildingDefs.STORAGE, Vector2i(-4, 0))
	var furnace: Furnace = place(BuildingDefs.FURNACE, Vector2i(0, 5)) as Furnace
	furnace.output.add(Items.IRON_PLATE, 40)

	run_ticks(300)
	check(storage.output.count(Items.IRON_PLATE) > 0, "продукцию должны вывезти на склад")
	check(furnace.output.count(Items.IRON_PLATE) < 40, "выход печи должен разгружаться")


func test_almost_empty_output_is_not_hauled() -> void:
	# Иначе дроны мотаются с одной пластиной вместо полезных рейсов.
	var storage: Building = place(BuildingDefs.STORAGE, Vector2i(-4, 0))
	var furnace: Furnace = place(BuildingDefs.FURNACE, Vector2i(0, 5)) as Furnace
	furnace.output.add(Items.IRON_PLATE, 2)
	run_ticks(120)
	check_eq(storage.output.count(Items.IRON_PLATE), 0, "почти пустой выход вывозить не нужно")


func test_reservations_prevent_double_booking() -> void:
	# На складе ровно одна порция, а дронов двое: второй не должен лететь
	# за тем же ящиком.
	var storage: Building = place(BuildingDefs.STORAGE, Vector2i(-4, 0))
	storage.output.add(Items.IRON_ORE, 5)
	var first: Furnace = place(BuildingDefs.FURNACE, Vector2i(0, 5)) as Furnace
	var second: Furnace = place(BuildingDefs.FURNACE, Vector2i(0, 8)) as Furnace
	first.set_recipe(Recipes.SMELT_IRON)
	second.set_recipe(Recipes.SMELT_IRON)

	run_ticks(3)
	var booked: int = 0
	for drone: Drone in port.drones:
		if drone.cargo_item == Items.IRON_ORE:
			booked += drone.cargo_count
	check(booked <= 5, "забронировано %d при запасе 5" % booked)


func test_port_without_power_grounds_drones() -> void:
	for panel: Building in world.buildings.of_kind(BuildingDefs.Kind.SOLAR):
		world.buildings.remove(panel.id)
	var storage: Building = place(BuildingDefs.STORAGE, Vector2i(-4, 0))
	storage.output.add(Items.IRON_ORE, 60)
	var furnace: Furnace = place(BuildingDefs.FURNACE, Vector2i(0, 5)) as Furnace
	furnace.set_recipe(Recipes.SMELT_IRON)

	run_ticks(100)
	check_eq(furnace.input.total(), 0, "без энергии порт не должен возить")
	for drone: Drone in port.drones:
		check(not drone.is_busy(), "дроны должны стоять на площадке")


func test_out_of_range_buildings_are_ignored() -> void:
	var storage: Building = place(BuildingDefs.STORAGE, Vector2i(-4, 0))
	storage.output.add(Items.IRON_ORE, 60)
	var far: Furnace = place(BuildingDefs.FURNACE, Vector2i(60, 60)) as Furnace
	far.set_recipe(Recipes.SMELT_IRON)

	run_ticks(150)
	check_eq(far.input.total(), 0, "порт не должен обслуживать здания за радиусом")


func test_drone_returns_home_when_target_disappears() -> void:
	var storage: Building = place(BuildingDefs.STORAGE, Vector2i(-4, 0))
	storage.output.add(Items.IRON_ORE, 60)
	var furnace: Furnace = place(BuildingDefs.FURNACE, Vector2i(0, 5)) as Furnace
	furnace.set_recipe(Recipes.SMELT_IRON)
	run_ticks(4)

	world.buildings.remove(furnace.id)
	run_ticks(200)
	for drone: Drone in port.drones:
		check(not drone.is_busy(), "дрон должен вернуться на площадку")
	check(port.output.count(Items.IRON_ORE) > 0 or storage.output.count(Items.IRON_ORE) == 60,
		"груз не должен исчезнуть вместе со зданием")


func test_reservations_are_released_after_delivery() -> void:
	var storage: Building = place(BuildingDefs.STORAGE, Vector2i(-4, 0))
	storage.output.add(Items.IRON_ORE, 60)
	var furnace: Furnace = place(BuildingDefs.FURNACE, Vector2i(0, 5)) as Furnace
	furnace.set_recipe(Recipes.SMELT_IRON)

	run_ticks(400)
	var idle: bool = true
	for drone: Drone in port.drones:
		if drone.is_busy():
			idle = false
	if idle:
		check(logistics._incoming.is_empty(), "после доставки броней остаться не должно")
		check(logistics._outgoing.is_empty(), "после доставки броней остаться не должно")


func test_reservations_rebuild_after_load() -> void:
	var storage: Building = place(BuildingDefs.STORAGE, Vector2i(-4, 0))
	storage.output.add(Items.IRON_ORE, 60)
	var furnace: Furnace = place(BuildingDefs.FURNACE, Vector2i(0, 5)) as Furnace
	furnace.set_recipe(Recipes.SMELT_IRON)
	run_ticks(4)

	logistics.reset()
	check(logistics._incoming.is_empty())
	logistics.rebuild_reservations(world.buildings)
	var busy: bool = false
	for drone: Drone in port.drones:
		if drone.is_busy() and drone.cargo_count > 0:
			busy = true
	if busy:
		check(not logistics._incoming.is_empty(), "брони должны восстанавливаться из заданий дронов")


func test_drone_counter_event() -> void:
	var counts: Array[int] = [0, 0]
	var handler := func(active: int, total: int) -> void:
		counts[0] = active
		counts[1] = total
	Events.drone_count_changed.connect(handler)
	var storage: Building = place(BuildingDefs.STORAGE, Vector2i(-4, 0))
	storage.output.add(Items.IRON_ORE, 60)
	var furnace: Furnace = place(BuildingDefs.FURNACE, Vector2i(0, 5)) as Furnace
	furnace.set_recipe(Recipes.SMELT_IRON)
	run_ticks(10)
	Events.drone_count_changed.disconnect(handler)
	check_eq(counts[1], 2, "всего дронов должно быть двое")
	check(counts[0] > 0, "хотя бы один дрон должен быть в рейсе")


func test_logistics_tick_cost() -> void:
	for i: int in 40:
		var storage: Building = place(BuildingDefs.STORAGE, Vector2i((i % 8) * 3 - 12, (i / 8) * 3 + 10))
		if storage != null:
			storage.output.add(Items.IRON_ORE, 100)
	var start_usec: int = Time.get_ticks_usec()
	run_ticks(20)
	var per_tick_ms: float = float(Time.get_ticks_usec() - start_usec) / 20000.0
	check(per_tick_ms < 5.0, "тик логистики занял %.2f мс" % per_tick_ms)


func test_every_port_gets_work_not_just_the_first() -> void:
	# Попыток раздачи на тик немного. Если каждый тик начинать с начала списка,
	# работа достаётся одним и тем же курьерам, а остальные стоят без дела —
	# игрок видит это как «боты затупили».
	var ports: Array[DronePort] = [port]
	for i: int in 3:
		var extra: DronePort = place(BuildingDefs.DRONE_PORT, Vector2i(-14, i * 10 - 10)) as DronePort
		extra.output.add(Items.DRONE, 2)
		ports.append(extra)
		place(BuildingDefs.SOLAR, Vector2i(-11, i * 10 - 10))
		var storage: Building = place(BuildingDefs.STORAGE, Vector2i(-18, i * 10 - 10))
		storage.output.add(Items.IRON_ORE, 100)
		var machine: Furnace = place(BuildingDefs.FURNACE, Vector2i(-14, i * 10 - 6)) as Furnace
		machine.set_recipe(Recipes.SMELT_IRON)

	var near_storage: Building = place(BuildingDefs.STORAGE, Vector2i(-4, 0))
	near_storage.output.add(Items.IRON_ORE, 100)
	var near_furnace: Furnace = place(BuildingDefs.FURNACE, Vector2i(0, 5)) as Furnace
	near_furnace.set_recipe(Recipes.SMELT_IRON)

	run_ticks(120)

	for index: int in ports.size():
		var served: bool = false
		for drone: Drone in ports[index].drones:
			if drone.is_busy() or drone.has_cargo():
				served = true
		check(served, "порт %d не получил ни одного задания" % index)


func test_delivery_resumes_after_supplier_is_demolished() -> void:
	# Если поставщика снесли в полёте, бронь на приём утекала, и получатель
	# навсегда оставался «тем, кому уже везут». Машина вставала насовсем.
	var storage: Building = place(BuildingDefs.STORAGE, Vector2i(-4, 0))
	storage.output.add(Items.IRON_ORE, 100)
	var furnace: Furnace = place(BuildingDefs.FURNACE, Vector2i(0, 5)) as Furnace
	furnace.set_recipe(Recipes.SMELT_IRON)

	var flying: bool = false
	for i: int in 40:
		simulation.tick()
		for drone: Drone in port.drones:
			if drone.state == Drone.State.TO_SOURCE and drone.source_id == storage.id:
				flying = true
		if flying:
			break
	check(flying, "дрон должен был вылететь за рудой")

	world.buildings.remove(storage.id)
	run_ticks(60)

	var replacement: Building = place(BuildingDefs.STORAGE, Vector2i(-4, 0))
	replacement.output.add(Items.IRON_ORE, 100)
	run_ticks(400)
	check(
		furnace.input.count(Items.IRON_ORE) > 0 or furnace.output.count(Items.IRON_PLATE) > 0,
		"после сноса поставщика доставка обязана возобновиться"
	)
