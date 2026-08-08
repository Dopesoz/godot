extends TestCase
## Носильщики: наземная логистика ранней игры.
##
## Проверяем три вещи, ради которых они и добавлены: работают без энергии,
## реально возят груз тем же механизмом, что и дроны, и не ходят по воде.

var grid: Grid
var registry: BuildingRegistry
var logistics: LogisticsSystem
var hut: PorterHut


func before_each() -> void:
	grid = Grid.new(64)
	for i: int in grid.size * grid.size:
		grid.terrain[i] = TileTypes.Terrain.GRASS
	registry = BuildingRegistry.new(grid)
	logistics = LogisticsSystem.new()
	hut = registry.place(BuildingDefs.PORTER_HUT, Vector2i(20, 20)) as PorterHut
	hut.on_world_ready(grid)
	# Бригада работает на дереве: без запаса она никуда не пойдёт.
	hut.input.add(Items.WOOD, 40)


func context() -> Dictionary:
	return {"registry": registry, "grid": grid}


func run_ticks(count: int) -> void:
	for i: int in count:
		logistics.tick(Constants.TICK_DELTA, context())


func test_hut_runs_on_wood() -> void:
	check(hut.has_fuel(), "с запасом дерева бригада должна быть готова к работе")
	check(hut.accepts_task(Items.IRON_ORE, 999), "с деревом берётся любое задание")

	hut.input.clear()
	check(not hut.has_fuel(), "без дерева топлива нет")
	check(
		not hut.accepts_task(Items.IRON_ORE, 999),
		"без дерева бригада не должна браться за посторонние грузы"
	)
	check(
		hut.accepts_task(Items.WOOD, hut.id),
		"подвоз дерева себе — единственное, за что бригада берётся без топлива"
	)
	check(
		hut.requests().has(Items.WOOD),
		"хижина обязана просить дерево, иначе его некому привезти"
	)


func test_wood_burns_per_trip() -> void:
	var before: int = hut.input.count(Items.WOOD)
	hut.on_courier_returned(hut.drones[0])
	check_eq(
		hut.input.count(Items.WOOD), before - PorterHut.WOOD_PER_TRIP,
		"за ходку должно списываться дерево"
	)


func test_hut_is_a_courier_base_with_a_crew() -> void:
	check(hut != null, "хижина не поставилась")
	check_eq(hut.drone_count(), PorterHut.CREW, "бригада должна быть полной сразу")
	check(hut.drones[0] is Porter, "в хижине должны жить носильщики, а не дроны")
	check(hut.is_operational(), "хижина обязана работать без электричества")
	check(
		LogisticsSystem.courier_bases(registry).has(hut),
		"логистика должна видеть хижину как базу курьеров"
	)


func test_porter_walks_slower_than_a_drone() -> void:
	check(
		Porter.WALK_SPEED < Drone.SPEED,
		"пеший курьер не должен обгонять дрон"
	)
	check_eq((hut.drones[0] as Drone).base_speed(), Porter.WALK_SPEED)


func test_porter_delivers_ore_to_a_furnace() -> void:
	var storage: Building = registry.place(BuildingDefs.STORAGE, Vector2i(24, 20))
	storage.output.add(Items.IRON_ORE, 40)
	var furnace: ProductionBuilding = registry.place(
		BuildingDefs.FURNACE, Vector2i(16, 20)
	) as ProductionBuilding
	furnace.set_recipe(Recipes.SMELT_IRON)

	run_ticks(200)
	check(
		furnace.input.count(Items.IRON_ORE) > 0,
		"носильщик должен был донести руду до печи"
	)


func test_porter_refuses_a_route_across_water() -> void:
	# Между хижиной и складом — сплошная водная полоса.
	for y: int in range(14, 27):
		grid.set_terrain(Vector2i(28, y), TileTypes.Terrain.WATER)
		grid.set_terrain(Vector2i(29, y), TileTypes.Terrain.WATER)

	var far_storage: Building = registry.place(BuildingDefs.STORAGE, Vector2i(31, 20))
	far_storage.output.add(Items.IRON_ORE, 40)
	var furnace: ProductionBuilding = registry.place(
		BuildingDefs.FURNACE, Vector2i(16, 20)
	) as ProductionBuilding
	furnace.set_recipe(Recipes.SMELT_IRON)

	run_ticks(200)
	check_eq(
		furnace.input.count(Items.IRON_ORE), 0,
		"носильщик не умеет плавать и не должен был взять этот рейс"
	)

	# Тот же маршрут дрону по силам — значит дело именно в воде, а не в
	# недосягаемости склада.
	var porter := Porter.new()
	var drone := Drone.new()
	var from: Vector2 = hut.center()
	var to: Vector2 = far_storage.center()
	check(not porter.can_travel(grid, from, to), "вода должна останавливать носильщика")
	check(drone.can_travel(grid, from, to), "дрон летит над водой")


func test_crew_survives_save_and_load() -> void:
	hut.drones[0].cargo_item = Items.STONE
	hut.drones[0].cargo_count = 4
	var data: Array = registry.serialize()

	var other_grid := Grid.new(64)
	for i: int in other_grid.size * other_grid.size:
		other_grid.terrain[i] = TileTypes.Terrain.GRASS
	var other := BuildingRegistry.new(other_grid)
	other.deserialize(data)

	var restored: PorterHut = other.at_cell(Vector2i(20, 20)) as PorterHut
	check(restored != null, "хижина не восстановилась")
	check_eq(restored.drone_count(), PorterHut.CREW)
	check(restored.drones[0] is Porter, "после загрузки бригада должна остаться пешей")
	check_eq(restored.drones[0].cargo_count, 4, "груз в руках потерялся")


func test_hut_stores_goods_like_a_storage() -> void:
	var pool := ResourcePool.new(registry)
	hut.output.add(Items.IRON_PLATE, 7)
	check_eq(pool.count(Items.IRON_PLATE), 7, "хижина должна считаться складом для оплаты построек")
