extends TestCase
## Ветряки и события мира (метеориты с находками).

var world: GameWorld = null
var simulation: Simulation = null
var events: EventSystem = null
var research: ResearchSystem = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(6060)
	for i: int in world.grid.size * world.grid.size:
		world.grid.terrain[i] = TileTypes.Terrain.GRASS

	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	simulation.add_system(PowerSystem.new())
	simulation.add_system(BuildingSystem.new())
	research = ResearchSystem.new()
	simulation.add_system(research)
	events = EventSystem.new()
	simulation.add_system(events)
	simulation.setup(world)
	GameSetup.create_starting_base(world)


func after_each() -> void:
	for node: Node in [simulation, world]:
		if is_instance_valid(node):
			node.free()
	world = null
	simulation = null
	events = null
	research = null


## --- Ветер -----------------------------------------------------------------

func test_wind_never_dies_completely() -> void:
	var minimum: float = 1.0
	var maximum: float = 0.0
	for i: int in 4000:
		var value: float = Simulation.wind_at(float(i) * 0.7)
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
		check(value >= 0.0 and value <= 1.0, "ветер вне диапазона: %f" % value)
	check(minimum >= Simulation.WIND_MIN - 0.001, "полный штиль недопустим: %f" % minimum)
	check(maximum > 0.8, "ветер должен иногда быть сильным: %f" % maximum)


func test_wind_changes_smoothly() -> void:
	var previous: float = Simulation.wind_at(0.0)
	for i: int in 500:
		var value: float = Simulation.wind_at(float(i))
		check(absf(value - previous) < 0.1, "резкий скачок ветра: %f -> %f" % [previous, value])
		previous = value


func test_turbine_works_at_night() -> void:
	var turbine: WindTurbine = world.buildings.place(
		BuildingDefs.WIND, world.start_cell + Vector2i(6, 6)
	) as WindTurbine
	check(turbine != null, "ветряк должен создаваться классом WindTurbine")

	simulation.game_time = Simulation.DAY_LENGTH * 0.7
	simulation.tick()
	check(turbine.power_supply(0.0) > 0.0, "ночью ветряк должен давать энергию")

	var panel: SolarPanel = world.buildings.place(
		BuildingDefs.SOLAR, world.start_cell + Vector2i(9, 6)
	) as SolarPanel
	check_almost(panel.power_supply(0.0), 0.0, 0.001, "панель ночью молчит")


func test_turbine_is_weaker_than_solar_at_noon() -> void:
	# Ветряк — про надёжность, а не про мощность.
	check(
		BuildingDefs.power_gen(BuildingDefs.WIND) < BuildingDefs.power_gen(BuildingDefs.SOLAR),
		"ветряк не должен быть выгоднее панели днём"
	)


## --- Метеориты -------------------------------------------------------------

func test_meteor_falls_and_carries_loot() -> void:
	simulation.tick_count = int(EventSystem.MEAN_INTERVAL * 3.0 * Constants.TICKS_PER_SECOND)
	simulation.tick()
	var wrecks: Array[Building] = world.buildings.of_kind(BuildingDefs.Kind.WRECK)
	check_eq(wrecks.size(), 1, "метеорит должен упасть")
	if wrecks.is_empty():
		return
	check(wrecks[0].output.count(Items.GOLD) > 0, "в обломке должно быть золото")
	check(wrecks[0].output.count(Items.DIAMOND) > 0, "в обломке должны быть алмазы")


func test_meteor_lands_near_but_not_on_the_base() -> void:
	simulation.tick_count = int(EventSystem.MEAN_INTERVAL * 3.0 * Constants.TICKS_PER_SECOND)
	simulation.tick()
	var wrecks: Array[Building] = world.buildings.of_kind(BuildingDefs.Kind.WRECK)
	if wrecks.is_empty():
		return
	var distance: float = Vector2(wrecks[0].center_cell()).distance_to(Vector2(world.home_cell()))
	check(distance >= float(EventSystem.MIN_DISTANCE) - 2.0, "метеорит упал слишком близко: %.0f" % distance)
	check(distance <= float(EventSystem.MAX_DISTANCE) + 3.0, "метеорит упал слишком далеко: %.0f" % distance)


func test_no_meteors_in_the_first_minutes() -> void:
	for i: int in int(EventSystem.GRACE_PERIOD * Constants.TICKS_PER_SECOND * 0.5):
		simulation.tick()
	check_eq(
		world.buildings.of_kind(BuildingDefs.Kind.WRECK).size(), 0,
		"в начале игры метеоритов быть не должно"
	)


func test_wreck_is_not_buildable_by_player() -> void:
	check(not BuildingDefs.is_player_built(BuildingDefs.WRECK), "обломок нельзя строить")
	check(not world.research.unlocked_buildings().has(BuildingDefs.WRECK),
		"обломок не должен появляться в меню строительства")


func test_loot_can_be_traded_for_research() -> void:
	research.start(Technologies.MINING_1)
	var pool := ResourcePool.new(world.buildings)
	pool.give(Items.GOLD, research.trade_cost(Items.GOLD))

	check(research.can_trade(Items.GOLD), "обмен должен быть доступен")
	var before: float = research.progress()
	check(research.trade(Items.GOLD), "обмен должен пройти")
	check(research.progress() > before, "обмен должен двигать исследование")
	check_eq(pool.count(Items.GOLD), 0, "золото должно списаться")
	check(not research.can_trade(Items.GOLD), "без золота обмен недоступен")


func test_trade_requires_active_research() -> void:
	var pool := ResourcePool.new(world.buildings)
	pool.give(Items.DIAMOND, 10)
	check(not research.can_trade(Items.DIAMOND), "без активного исследования менять некуда")
	check(not research.trade(Items.DIAMOND))


func test_trade_can_finish_research() -> void:
	research.start(Technologies.MINING_1)
	var pool := ResourcePool.new(world.buildings)
	pool.give(Items.DIAMOND, 200)
	for i: int in 30:
		if not research.can_trade(Items.DIAMOND):
			break
		research.trade(Items.DIAMOND)
	check(world.research.is_completed(Technologies.MINING_1), "обменом можно закрыть исследование")


func test_event_state_survives_save() -> void:
	events.next_event_time = 1234.0
	events.meteors_fallen = 3
	var data: Dictionary = events.serialize()
	events.reset()
	events.deserialize(data)
	check_almost(events.next_event_time, 1234.0, 0.01)
	check_eq(events.meteors_fallen, 3)
