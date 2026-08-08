extends TestCase
## Вода, уголь, загрязнение и атом: альтернативные источники энергии.

var world: GameWorld = null
var simulation: Simulation = null
var pollution: PollutionSystem = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(7373)
	for i: int in world.grid.size * world.grid.size:
		world.grid.terrain[i] = TileTypes.Terrain.GRASS

	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	pollution = PollutionSystem.new()
	simulation.add_system(pollution)
	simulation.add_system(PowerSystem.new())
	simulation.add_system(BuildingSystem.new())
	simulation.setup(world)
	simulation.game_time = 0.0


func after_each() -> void:
	for node: Node in [simulation, world]:
		if is_instance_valid(node):
			node.free()
	world = null
	simulation = null
	pollution = null


func place(def_id: StringName, offset: Vector2i) -> Building:
	return world.buildings.place(def_id, world.start_cell + offset)


func make_lake(offset: Vector2i) -> void:
	for dy: int in 3:
		for dx: int in 3:
			world.grid.set_terrain(world.start_cell + offset + Vector2i(dx, dy), TileTypes.Terrain.WATER)


func run_seconds(seconds: float) -> void:
	for i: int in int(seconds * Constants.TICKS_PER_SECOND):
		simulation.tick()


## --- Вода ------------------------------------------------------------------

func test_pump_requires_water_nearby() -> void:
	check_eq(
		world.buildings.check_placement(BuildingDefs.WATER_PUMP, world.start_cell + Vector2i(6, 6)),
		BuildingRegistry.PlaceError.NO_WATER,
		"на суше водозабор ставить нельзя"
	)
	make_lake(Vector2i(6, 8))
	check(
		world.buildings.can_place(BuildingDefs.WATER_PUMP, world.start_cell + Vector2i(6, 6)),
		"у воды водозабор должен ставиться"
	)


func test_pump_ignores_diagonal_water() -> void:
	# Насос должен стоять к воде стороной, а не касаться уголком.
	world.grid.set_terrain(world.start_cell + Vector2i(8, 8), TileTypes.Terrain.WATER)
	check_eq(
		world.buildings.check_placement(BuildingDefs.WATER_PUMP, world.start_cell + Vector2i(6, 6)),
		BuildingRegistry.PlaceError.NO_WATER
	)


func test_pump_produces_water_when_powered() -> void:
	make_lake(Vector2i(6, 8))
	var pump: WaterPump = place(BuildingDefs.WATER_PUMP, Vector2i(6, 6)) as WaterPump
	check(pump != null, "водозабор должен создаваться классом WaterPump")
	place(BuildingDefs.SOLAR, Vector2i(9, 6))

	run_seconds(5.0)
	check(pump.output.count(Items.WATER) > 0, "насос должен качать воду")
	check_eq(pump.status, Building.Status.WORKING)


func test_pump_without_power_stops() -> void:
	make_lake(Vector2i(6, 8))
	var pump: WaterPump = place(BuildingDefs.WATER_PUMP, Vector2i(6, 6)) as WaterPump
	run_seconds(3.0)
	check_eq(pump.output.total(), 0, "без энергии воды быть не должно")
	check_eq(pump.status, Building.Status.NO_POWER)


## --- Уголь -----------------------------------------------------------------

func test_boiler_burns_coal_with_water() -> void:
	var boiler: Boiler = place(BuildingDefs.BOILER, Vector2i(6, 6)) as Boiler
	check(boiler != null, "котёл должен создаваться классом Boiler")
	check_almost(boiler.power_supply(1.0), 0.0, 0.001, "без топлива энергии нет")

	boiler.input.add(Items.COAL, 5)
	boiler.input.add(Items.WATER, 20)
	run_seconds(0.5)
	check(boiler.is_burning(), "котёл должен разгореться")
	check(boiler.power_supply(0.0) > 0.0, "котёл даёт энергию и ночью")
	check_eq(boiler.input.count(Items.COAL), 4, "порция угля списывается целиком")
	check_eq(boiler.input.count(Items.WATER), 20 - Boiler.new().water_per_fuel())


func test_boiler_without_water_does_not_burn() -> void:
	var boiler: Boiler = place(BuildingDefs.BOILER, Vector2i(6, 6)) as Boiler
	boiler.input.add(Items.COAL, 5)
	run_seconds(2.0)
	check(not boiler.is_burning(), "без воды котёл работать не должен")
	check_eq(boiler.status, Building.Status.NO_INPUT)
	check_eq(boiler.input.count(Items.COAL), 5, "уголь не должен пропадать впустую")


func test_boiler_powers_consumers_at_night() -> void:
	var boiler: Boiler = place(BuildingDefs.BOILER, Vector2i(6, 6)) as Boiler
	boiler.input.add(Items.COAL, 20)
	boiler.input.add(Items.WATER, 40)
	var lab: Building = place(BuildingDefs.LAB, Vector2i(9, 6))

	simulation.game_time = Simulation.DAY_LENGTH * 0.7
	run_seconds(3.0)
	check_almost(lab.power_satisfaction, 1.0, 0.01, "ночью котёл должен кормить лабораторию")


func test_boiler_requests_fuel_and_water() -> void:
	var boiler: Boiler = place(BuildingDefs.BOILER, Vector2i(6, 6)) as Boiler
	var requests: Dictionary[StringName, int] = boiler.requests()
	check(requests.has(Items.COAL), "котёл должен просить уголь")
	check(requests.has(Items.WATER), "котёл должен просить воду")


func test_generator_requests_fit_into_shared_buffer() -> void:
	# Вход у генераторов общий на топливо и воду. Если сумма запросов не влезает
	# в буфер, дроны забьют его одним топливом, и генератор встанет навсегда.
	for def_id: StringName in [BuildingDefs.BOILER, BuildingDefs.REACTOR]:
		var generator: FuelGenerator = place(def_id, Vector2i(20, 20)) as FuelGenerator
		var total: int = generator.request_fuel() + generator.request_water()
		check(
			total <= BuildingDefs.input_capacity(def_id),
			"%s: запросы (%d) не влезают в буфер (%d)" % [
				def_id, total, BuildingDefs.input_capacity(def_id),
			]
		)
		world.buildings.remove(generator.id)


## --- Загрязнение -----------------------------------------------------------

func test_burning_coal_raises_pollution_and_hurts_solar() -> void:
	var boiler: Boiler = place(BuildingDefs.BOILER, Vector2i(6, 6)) as Boiler
	# Буфер котла общий: заливать уголь «под завязку» нельзя, иначе воде
	# не останется места и котёл встанет.
	boiler.input.add(Items.COAL, 30)
	boiler.input.add(Items.WATER, 60)
	var panel: SolarPanel = place(BuildingDefs.SOLAR, Vector2i(10, 6)) as SolarPanel
	var clean_output: float = panel.power_supply(1.0)

	run_seconds(120.0)
	check(pollution.level > 0.0, "уголь должен давать загрязнение")
	check(pollution.solar_factor() < 1.0, "копоть должна резать выработку панелей")
	check(panel.power_supply(1.0) < clean_output, "панель под смогом даёт меньше")
	check(pollution.level_percent() > 0)


func test_pollution_decays_after_boilers_stop() -> void:
	var boiler: Boiler = place(BuildingDefs.BOILER, Vector2i(6, 6)) as Boiler
	boiler.input.add(Items.COAL, 25)
	boiler.input.add(Items.WATER, 50)
	run_seconds(60.0)
	var peak: float = pollution.level
	check(peak > 0.0)

	world.buildings.remove(boiler.id)
	run_seconds(120.0)
	check(pollution.level < peak, "без котлов загрязнение должно рассеиваться")


func test_pollution_penalty_is_capped() -> void:
	pollution.level = PollutionSystem.HEAVY_LEVEL * 10.0
	check_almost(
		pollution.solar_factor(), 1.0 - PollutionSystem.MAX_PENALTY, 0.001,
		"штраф не должен обнулять солнце полностью"
	)


func test_reactor_is_clean() -> void:
	var reactor: NuclearReactor = place(BuildingDefs.REACTOR, Vector2i(6, 6)) as NuclearReactor
	check(reactor != null, "реактор должен создаваться классом NuclearReactor")
	reactor.input.add(Items.FUEL_ROD, 2)
	reactor.input.add(Items.WATER, 60)
	run_seconds(2.0)
	check(reactor.is_burning(), "реактор должен запуститься")
	check_almost(reactor.pollution_rate(), 0.0, 0.001, "атом не коптит")
	check(reactor.power_supply(0.0) > BuildingDefs.power_gen(BuildingDefs.BOILER),
		"реактор должен быть мощнее котла")
	run_seconds(20.0)
	check_eq(reactor.input.count(Items.FUEL_ROD), 1, "один стержень горит долго")


## --- Сохранение ------------------------------------------------------------

func test_burn_state_survives_save() -> void:
	var boiler: Boiler = place(BuildingDefs.BOILER, Vector2i(6, 6)) as Boiler
	boiler.input.add(Items.COAL, 3)
	boiler.input.add(Items.WATER, 10)
	run_seconds(0.5)
	var data: Array = world.buildings.serialize()

	var registry := BuildingRegistry.new(world.grid)
	world.buildings.clear()
	registry.deserialize(data)
	var restored: Boiler = registry.all()[0] as Boiler
	check(restored.is_burning(), "горение должно продолжиться после загрузки")
	check_almost(restored.burn_left, boiler.burn_left, 0.01)


## --- Мир -------------------------------------------------------------------

func test_world_contains_coal_and_uranium() -> void:
	var grid := Grid.new(256)
	MapGenerator.generate(grid, 555)
	var counts: Dictionary[int, int] = {}
	for i: int in grid.size * grid.size:
		var ore: int = grid.ore[i]
		if ore != TileTypes.Ore.NONE:
			counts[ore] = counts.get(ore, 0) + 1
	check(counts.get(TileTypes.Ore.COAL, 0) > 0, "на карте должен быть уголь")
	check(counts.get(TileTypes.Ore.URANIUM, 0) > 0, "на карте должен быть уран")
	# Уран — редкость поздней игры, его должно быть заметно меньше угля.
	check(
		counts.get(TileTypes.Ore.URANIUM, 0) < counts.get(TileTypes.Ore.COAL, 1),
		"урана не должно быть больше угля"
	)


func test_coal_is_available_near_start() -> void:
	var grid := Grid.new(256)
	var start: Vector2i = MapGenerator.generate(grid, 4321)
	var radius: int = MapGenerator.START_PATCH_SEARCH + MapGenerator.START_PATCH_RADIUS
	var area := Rect2i(start - Vector2i(radius, radius), Vector2i(radius * 2, radius * 2))
	check(
		grid.count_ore_in_area(area, TileTypes.Ore.COAL).x > 0,
		"уголь должен быть в шаговой доступности: без него паровая энергия недоступна"
	)
