extends TestCase
## Бур: добыча, зависимость от энергии, исчерпание залежи, сохранение.

var world: GameWorld = null
var simulation: Simulation = null
var drill: Drill = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(31337)
	for i: int in world.grid.size * world.grid.size:
		world.grid.terrain[i] = TileTypes.Terrain.GRASS

	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	simulation.add_system(PowerSystem.new())
	simulation.add_system(BuildingSystem.new())
	simulation.setup(world)

	# Залежь железа 2x2 и бур ровно на ней.
	var patch: Vector2i = world.start_cell + Vector2i(6, 6)
	for dy: int in 2:
		for dx: int in 2:
			world.grid.set_ore(patch + Vector2i(dx, dy), TileTypes.Ore.IRON, 100)
	drill = world.buildings.place(BuildingDefs.DRILL, patch) as Drill
	world.buildings.place(BuildingDefs.SOLAR, patch + Vector2i(3, 0))
	simulation.game_time = 0.0


func after_each() -> void:
	if is_instance_valid(simulation):
		simulation.free()
	if is_instance_valid(world):
		world.free()
	simulation = null
	world = null
	drill = null


func test_drill_is_specialised_class() -> void:
	check(drill != null, "бур должен создаваться классом Drill")


func test_ore_type_is_resolved_from_ground() -> void:
	simulation.tick()
	check_eq(drill.ore_type, TileTypes.Ore.IRON)
	check_eq(drill.mined_item, Items.IRON_ORE)


func test_mining_fills_output() -> void:
	for i: int in 40:
		simulation.tick()
	check(drill.output.count(Items.IRON_ORE) > 0, "бур ничего не добыл")
	check_eq(drill.status, Building.Status.WORKING)


func test_mining_rate_matches_speed() -> void:
	# Четыре секунды при полном питании: ожидаем BASE_SPEED * 4 единиц.
	for i: int in Constants.TICKS_PER_SECOND * 4:
		simulation.tick()
	var expected: int = int(Drill.BASE_SPEED * 4.0)
	var mined: int = drill.output.count(Items.IRON_ORE)
	check(absi(mined - expected) <= 1, "добыто %d вместо ~%d" % [mined, expected])


func test_no_power_stops_mining() -> void:
	# Убираем панель: без энергии бур обязан остановиться и сказать об этом.
	for building: Building in world.buildings.of_kind(BuildingDefs.Kind.SOLAR):
		world.buildings.remove(building.id)
	for i: int in 20:
		simulation.tick()
	check_eq(drill.output.count(Items.IRON_ORE), 0, "без энергии добычи быть не должно")
	check_eq(drill.status, Building.Status.NO_POWER)


func test_half_power_halves_output() -> void:
	# Вторая лаборатория съедает часть энергии — бур замедляется пропорционально.
	drill.power_satisfaction = 0.5
	drill._progress = 0.0
	for i: int in Constants.TICKS_PER_SECOND * 4:
		drill.tick(Constants.TICK_DELTA, {"grid": world.grid, "registry": world.buildings, "daylight": 1.0})
	var expected: int = int(Drill.BASE_SPEED * 0.5 * 4.0)
	check(absi(drill.output.count(Items.IRON_ORE) - expected) <= 1, "неверная скорость при половине питания")


func test_depleted_patch_stops_drill() -> void:
	# Выкачиваем залежь досуха.
	for dy: int in 2:
		for dx: int in 2:
			var cell: Vector2i = drill.origin + Vector2i(dx, dy)
			world.grid.extract_ore(cell, world.grid.get_ore_amount(cell))
	simulation.tick()
	for i: int in 30:
		simulation.tick()
	check_eq(drill.status, Building.Status.NO_ORE, "исчерпанный бур должен сообщать об этом")


func test_full_output_pauses_drill() -> void:
	drill.output.add(Items.IRON_ORE, drill.output.capacity)
	simulation.tick()
	check_eq(drill.status, Building.Status.OUTPUT_FULL)
	check_eq(drill.output.total(), drill.output.capacity, "переполнения быть не может")


func test_ore_is_consumed_from_ground() -> void:
	var before: int = drill.remaining_ore(world.grid)
	for i: int in Constants.TICKS_PER_SECOND * 5:
		simulation.tick()
	var after: int = drill.remaining_ore(world.grid)
	check(after < before, "запас руды в земле должен убывать")
	check_eq(before - after, drill.output.count(Items.IRON_ORE), "добытое должно сходиться с изъятым")


func test_mining_spreads_across_cells() -> void:
	# Бур берёт из самой богатой клетки, поэтому залежь вырабатывается ровно.
	for i: int in Constants.TICKS_PER_SECOND * 30:
		simulation.tick()
	var amounts: Array[int] = []
	for dy: int in 2:
		for dx: int in 2:
			amounts.append(world.grid.get_ore_amount(drill.origin + Vector2i(dx, dy)))
	amounts.sort()
	check(amounts[3] - amounts[0] <= 2, "залежь выработана неравномерно: %s" % [amounts])


func test_state_survives_save() -> void:
	for i: int in 25:
		simulation.tick()
	var data: Array = world.buildings.serialize()
	var registry := BuildingRegistry.new(world.grid)
	world.buildings.clear()
	registry.deserialize(data)

	var restored: Drill = null
	for building: Building in registry.all():
		if building is Drill:
			restored = building
	check(restored != null, "бур не восстановился")
	check_eq(restored.ore_type, TileTypes.Ore.IRON, "тип руды должен сохраняться")
	check_eq(restored.output.count(Items.IRON_ORE), drill.output.count(Items.IRON_ORE))
