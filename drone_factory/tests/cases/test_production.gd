extends TestCase
## Производство: рецепты, очередь заданий, запросы к логистике, сохранение.

var world: GameWorld = null
var simulation: Simulation = null
var furnace: Furnace = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(515)
	for i: int in world.grid.size * world.grid.size:
		world.grid.terrain[i] = TileTypes.Terrain.GRASS

	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	simulation.add_system(PowerSystem.new())
	simulation.add_system(BuildingSystem.new())
	simulation.setup(world)

	furnace = world.buildings.place(BuildingDefs.FURNACE, world.start_cell + Vector2i(6, 6)) as Furnace
	# Панели рядом, чтобы печь была под питанием.
	world.buildings.place(BuildingDefs.SOLAR, world.start_cell + Vector2i(9, 6))
	world.buildings.place(BuildingDefs.SOLAR, world.start_cell + Vector2i(9, 9))
	simulation.game_time = 0.0


func after_each() -> void:
	if is_instance_valid(simulation):
		simulation.free()
	if is_instance_valid(world):
		world.free()
	simulation = null
	world = null
	furnace = null


func run_seconds(seconds: float) -> void:
	for i: int in int(seconds * Constants.TICKS_PER_SECOND):
		simulation.tick()


func test_specialised_classes() -> void:
	check(furnace != null, "печь должна создаваться классом Furnace")
	var assembler: Building = world.buildings.place(BuildingDefs.ASSEMBLER, world.start_cell + Vector2i(12, 6))
	check(assembler is Assembler, "сборщик должен создаваться классом Assembler")


func test_recipe_must_match_machine() -> void:
	check(furnace.set_recipe(Recipes.SMELT_IRON), "печь должна принимать плавку")
	check(not furnace.set_recipe(Recipes.CRAFT_GEAR), "печь не должна принимать сборку")
	check_eq(furnace.current_recipe(), Recipes.SMELT_IRON, "неверный рецепт не должен затирать очередь")


func test_smelting_produces_plates() -> void:
	furnace.set_recipe(Recipes.SMELT_IRON)
	furnace.input.add(Items.IRON_ORE, 5)
	run_seconds(Recipes.craft_time(Recipes.SMELT_IRON) * 2.0 + 0.5)
	check(furnace.output.count(Items.IRON_PLATE) >= 2, "печь не выдала пластины")
	check(furnace.input.count(Items.IRON_ORE) <= 3, "руда должна расходоваться")


func test_no_input_stops_production() -> void:
	furnace.set_recipe(Recipes.SMELT_IRON)
	run_seconds(1.0)
	check_eq(furnace.status, Building.Status.NO_INPUT)
	check_eq(furnace.output.total(), 0)


func test_no_power_stops_production() -> void:
	for panel: Building in world.buildings.of_kind(BuildingDefs.Kind.SOLAR):
		world.buildings.remove(panel.id)
	furnace.set_recipe(Recipes.SMELT_IRON)
	furnace.input.add(Items.IRON_ORE, 5)
	run_seconds(3.0)
	check_eq(furnace.status, Building.Status.NO_POWER)
	check_eq(furnace.output.total(), 0, "без энергии плавки быть не должно")


func test_half_power_takes_twice_as_long() -> void:
	furnace.set_recipe(Recipes.SMELT_IRON)
	furnace.input.add(Items.IRON_ORE, 10)
	furnace.power_satisfaction = 0.5
	var context: Dictionary = {"grid": world.grid, "registry": world.buildings, "daylight": 1.0}
	for i: int in int(Recipes.craft_time(Recipes.SMELT_IRON) * Constants.TICKS_PER_SECOND):
		furnace.tick(Constants.TICK_DELTA, context)
	check_eq(furnace.output.count(Items.IRON_PLATE), 0, "при половине питания порция ещё не готова")
	for i: int in int(Recipes.craft_time(Recipes.SMELT_IRON) * Constants.TICKS_PER_SECOND) + 2:
		furnace.tick(Constants.TICK_DELTA, context)
	check_eq(furnace.output.count(Items.IRON_PLATE), 1, "за двойное время должна выйти одна пластина")


func test_output_full_pauses_production() -> void:
	furnace.set_recipe(Recipes.SMELT_IRON)
	furnace.input.add(Items.IRON_ORE, 10)
	furnace.output.add(Items.IRON_PLATE, furnace.output.capacity)
	run_seconds(2.0)
	check_eq(furnace.status, Building.Status.OUTPUT_FULL)
	check_eq(furnace.input.count(Items.IRON_ORE), 10, "сырьё не должно тратиться впустую")


func test_finite_job_is_consumed() -> void:
	furnace.set_recipe(Recipes.SMELT_IRON, 2)
	furnace.input.add(Items.IRON_ORE, 10)
	run_seconds(Recipes.craft_time(Recipes.SMELT_IRON) * 3.0)
	check_eq(furnace.output.count(Items.IRON_PLATE), 2, "должно выплавиться ровно заказанное количество")
	check_eq(furnace.queue_size(), 0, "выполненное задание должно уходить из очереди")
	check_eq(furnace.status, Building.Status.IDLE)


func test_repeat_job_runs_forever() -> void:
	furnace.set_recipe(Recipes.SMELT_IRON, ProductionBuilding.REPEAT)
	furnace.input.add(Items.IRON_ORE, 20)
	run_seconds(Recipes.craft_time(Recipes.SMELT_IRON) * 5.0)
	check(furnace.output.count(Items.IRON_PLATE) >= 4, "повторяющееся задание должно работать непрерывно")
	check_eq(furnace.queue_size(), 1, "повтор не должен исчезать из очереди")


func test_queue_runs_jobs_in_order() -> void:
	furnace.set_recipe(Recipes.SMELT_IRON, 1)
	furnace.enqueue(Recipes.SMELT_COPPER, 1)
	furnace.input.add(Items.IRON_ORE, 5)
	furnace.input.add(Items.COPPER_ORE, 5)
	run_seconds(Recipes.craft_time(Recipes.SMELT_IRON) * 4.0)
	check_eq(furnace.output.count(Items.IRON_PLATE), 1)
	check_eq(furnace.output.count(Items.COPPER_PLATE), 1)
	check_eq(furnace.queue_size(), 0, "очередь должна опустеть")


func test_same_recipe_merges_into_one_job() -> void:
	furnace.set_recipe(Recipes.SMELT_IRON, 3)
	furnace.enqueue(Recipes.SMELT_IRON, 2)
	check_eq(furnace.queue_size(), 1, "одинаковые задания подряд должны сливаться")
	check_eq(int(furnace.queue[0]["count"]), 5)


func test_remove_job() -> void:
	furnace.set_recipe(Recipes.SMELT_IRON, 3)
	furnace.enqueue(Recipes.SMELT_COPPER, 3)
	furnace.remove_job(0)
	check_eq(furnace.current_recipe(), Recipes.SMELT_COPPER)
	furnace.clear_queue()
	check_eq(furnace.queue_size(), 0)


func test_requests_describe_missing_input() -> void:
	furnace.set_recipe(Recipes.SMELT_IRON)
	var requests: Dictionary[StringName, int] = furnace.requests()
	check(requests.has(Items.IRON_ORE), "печь должна просить руду")
	check(requests[Items.IRON_ORE] > 0)

	furnace.input.add(Items.IRON_ORE, 100)
	check(furnace.requests().is_empty(), "полный буфер не должен ничего просить")


func test_input_filter_blocks_foreign_items() -> void:
	furnace.set_recipe(Recipes.SMELT_IRON)
	check_eq(furnace.input.add(Items.COPPER_ORE, 5), 0, "чужое сырьё не должно попадать в печь")
	check_eq(furnace.input.add(Items.IRON_ORE, 5), 5)


func test_queue_events_are_emitted() -> void:
	var events: Array[int] = []
	var handler := func(building_id: int) -> void: events.append(building_id)
	Events.production_queue_changed.connect(handler)
	furnace.set_recipe(Recipes.SMELT_IRON, 1)
	Events.production_queue_changed.disconnect(handler)
	check(events.has(furnace.id), "смена очереди должна сообщаться интерфейсу")


func test_state_survives_save() -> void:
	furnace.set_recipe(Recipes.SMELT_IRON, 4)
	furnace.input.add(Items.IRON_ORE, 6)
	run_seconds(1.0)
	var data: Array = world.buildings.serialize()

	var registry := BuildingRegistry.new(world.grid)
	world.buildings.clear()
	registry.deserialize(data)
	var restored: Furnace = null
	for building: Building in registry.all():
		if building is Furnace:
			restored = building
	check(restored != null, "печь не восстановилась")
	check_eq(restored.current_recipe(), Recipes.SMELT_IRON)
	check_eq(int(restored.queue[0]["count"]), 4, "количество в задании должно сохраняться")
	check_eq(restored.input.count(Items.IRON_ORE), furnace.input.count(Items.IRON_ORE))
	check(restored.input.filter.has(Items.IRON_ORE), "фильтр входа должен восстанавливаться")


func test_save_drops_unknown_recipes() -> void:
	var registry := BuildingRegistry.new(world.grid)
	registry.deserialize([{
		"id": 1, "def": String(BuildingDefs.FURNACE), "x": 5, "y": 5,
		"extra": {"queue": [{"r": "obsolete_recipe", "c": 3}], "progress": 0.0},
	}])
	var restored: Furnace = registry.all()[0] as Furnace
	check_eq(restored.queue_size(), 0, "исчезнувший рецепт не должен ломать загрузку")
