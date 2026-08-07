extends TestCase
## Электричество: сети, выработка по освещённости, аккумуляторы, дефицит.

var world: GameWorld = null
var simulation: Simulation = null
var power: PowerSystem = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(2211)
	# Ровная площадка без руды: тесты про энергию, а не про рельеф.
	for i: int in world.grid.size * world.grid.size:
		world.grid.terrain[i] = TileTypes.Terrain.GRASS

	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	power = PowerSystem.new()
	simulation.add_system(power)
	simulation.add_system(BuildingSystem.new())
	simulation.setup(world)


func after_each() -> void:
	if is_instance_valid(simulation):
		simulation.free()
	if is_instance_valid(world):
		world.free()
	simulation = null
	world = null
	power = null


func place(def_id: StringName, offset: Vector2i) -> Building:
	return world.buildings.place(def_id, world.start_cell + offset)


func test_solar_output_follows_daylight() -> void:
	var panel: SolarPanel = place(BuildingDefs.SOLAR, Vector2i(0, 0)) as SolarPanel
	check(panel != null, "панель должна создаваться классом SolarPanel")
	check_almost(panel.power_supply(1.0), BuildingDefs.power_gen(BuildingDefs.SOLAR))
	check_almost(panel.power_supply(0.5), BuildingDefs.power_gen(BuildingDefs.SOLAR) * 0.5)
	check_almost(panel.power_supply(0.0), 0.0, 0.001, "ночью панель не даёт энергии")


func test_nearby_buildings_form_one_network() -> void:
	place(BuildingDefs.SOLAR, Vector2i(0, 0))
	place(BuildingDefs.LAB, Vector2i(4, 0))
	simulation.tick()
	check_eq(power.networks.size(), 1, "соседние здания должны быть в одной сети")


func test_distant_buildings_form_separate_networks() -> void:
	place(BuildingDefs.SOLAR, Vector2i(0, 0))
	place(BuildingDefs.LAB, Vector2i(40, 0))
	simulation.tick()
	check_eq(power.networks.size(), 2, "дальние здания не должны питаться друг от друга")


func test_pole_links_distant_networks() -> void:
	place(BuildingDefs.SOLAR, Vector2i(0, 0))
	place(BuildingDefs.LAB, Vector2i(14, 0))
	simulation.tick()
	check_eq(power.networks.size(), 2, "без столбов сети раздельные")

	place(BuildingDefs.POLE, Vector2i(8, 0))
	simulation.tick()
	check_eq(power.networks.size(), 1, "столб должен соединять сети")


func test_consumer_without_power_is_unsatisfied() -> void:
	var lab: Building = place(BuildingDefs.LAB, Vector2i(0, 0))
	simulation.tick()
	check_almost(lab.power_satisfaction, 0.0, 0.001, "без источника питания быть не должно")


func test_full_supply_satisfies_consumers() -> void:
	var lab: Building = place(BuildingDefs.LAB, Vector2i(0, 0))
	place(BuildingDefs.SOLAR, Vector2i(3, 0))
	place(BuildingDefs.SOLAR, Vector2i(3, 3))
	simulation.game_time = 0.0
	simulation.tick()
	check_almost(lab.power_satisfaction, 1.0, 0.01, "днём двух панелей хватает лаборатории")
	check(power.total_production > power.total_demand)


func test_deficit_is_shared_between_consumers() -> void:
	# Одна панель на две лаборатории: обе должны работать вполсилы,
	# а не одна на полную, а вторая стоять.
	var first: Building = place(BuildingDefs.LAB, Vector2i(0, 0))
	var second: Building = place(BuildingDefs.LAB, Vector2i(0, 3))
	place(BuildingDefs.SOLAR, Vector2i(3, 0))
	simulation.game_time = 0.0
	simulation.tick()

	check_almost(first.power_satisfaction, second.power_satisfaction, 0.01, "дефицит делится поровну")
	check(first.power_satisfaction < 1.0, "при дефиците питание неполное")
	check(first.power_satisfaction > 0.0, "при дефиците питание не нулевое")


func test_accumulator_charges_by_day_and_discharges_at_night() -> void:
	place(BuildingDefs.SOLAR, Vector2i(0, 0))
	var accumulator: Accumulator = place(BuildingDefs.ACCUMULATOR, Vector2i(3, 0)) as Accumulator
	check(accumulator != null, "аккумулятор должен создаваться классом Accumulator")

	simulation.game_time = 0.0
	for i: int in 100:
		simulation.tick()
	check(accumulator.charge > 0.0, "днём излишки должны копиться")
	var charged: float = accumulator.charge

	# Ночь: панель молчит, потребитель тянет из аккумулятора.
	var lab: Building = place(BuildingDefs.LAB, Vector2i(0, 3))
	simulation.game_time = Simulation.DAY_LENGTH * 0.70
	for i: int in 20:
		simulation.tick()
	check(accumulator.charge < charged, "ночью заряд должен расходоваться")
	check(lab.power_satisfaction > 0.0, "аккумулятор должен питать лабораторию ночью")


func test_accumulator_capacity_is_respected() -> void:
	place(BuildingDefs.SOLAR, Vector2i(0, 0))
	var accumulator: Accumulator = place(BuildingDefs.ACCUMULATOR, Vector2i(3, 0)) as Accumulator
	simulation.game_time = 0.0
	for i: int in 2000:
		simulation.tick()
	check(accumulator.charge <= accumulator.capacity() + 0.001, "заряд превысил ёмкость")
	check_almost(accumulator.charge_ratio(), 1.0, 0.01, "за долгий день аккумулятор должен заполниться")


func test_accumulator_state_survives_save() -> void:
	var accumulator: Accumulator = place(BuildingDefs.ACCUMULATOR, Vector2i(0, 0)) as Accumulator
	accumulator.store(400.0)
	var data: Array = world.buildings.serialize()

	var registry := BuildingRegistry.new(world.grid)
	world.buildings.clear()
	registry.deserialize(data)
	var restored: Accumulator = registry.all()[0] as Accumulator
	check_almost(restored.charge, 400.0, 0.01, "заряд должен сохраняться")


func test_topology_rebuilds_only_on_change() -> void:
	place(BuildingDefs.SOLAR, Vector2i(0, 0))
	simulation.tick()
	check(not power._dirty, "после пересборки флаг снимается")
	simulation.tick()
	check(not power._dirty, "без построек пересборка не нужна")
	place(BuildingDefs.SOLAR, Vector2i(4, 0))
	check(power._dirty, "постройка должна помечать топологию устаревшей")


func test_stats_event_is_throttled() -> void:
	# Счётчик в массиве: лямбда GDScript захватывает переменные по значению.
	var events: Array[int] = [0]
	var handler := func(_p: float, _c: float, _s: float) -> void: events[0] += 1
	Events.power_stats_changed.connect(handler)
	place(BuildingDefs.SOLAR, Vector2i(0, 0))
	place(BuildingDefs.LAB, Vector2i(3, 0))
	simulation.game_time = 0.0
	for i: int in 20:
		simulation.tick()
	Events.power_stats_changed.disconnect(handler)
	check(events[0] < 20, "события должны идти только при изменениях, а не каждый тик: %d" % events[0])
	check(events[0] > 0, "хотя бы одно событие должно прийти")


func test_power_tick_cost() -> void:
	for i: int in 120:
		place(BuildingDefs.SOLAR, Vector2i((i % 12) * 3 - 18, (i / 12) * 3 + 10))
	simulation.tick()
	var start_usec: int = Time.get_ticks_usec()
	for i: int in 20:
		simulation.tick()
	var per_tick_ms: float = float(Time.get_ticks_usec() - start_usec) / 20000.0
	check(per_tick_ms < 4.0, "тик энергосети со 120 зданиями занял %.2f мс" % per_tick_ms)
