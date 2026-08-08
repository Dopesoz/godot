extends TestCase
## Исследования: дерево, лаборатории, бонусы, разблокировки, сохранение.

var world: GameWorld = null
var simulation: Simulation = null
var research: ResearchSystem = null
var lab: Lab = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(1717)
	for i: int in world.grid.size * world.grid.size:
		world.grid.terrain[i] = TileTypes.Terrain.GRASS

	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	simulation.add_system(PowerSystem.new())
	simulation.add_system(BuildingSystem.new())
	research = ResearchSystem.new()
	simulation.add_system(research)
	simulation.setup(world)
	simulation.game_time = 0.0

	lab = world.buildings.place(BuildingDefs.LAB, world.start_cell + Vector2i(5, 5)) as Lab
	world.buildings.place(BuildingDefs.SOLAR, world.start_cell + Vector2i(8, 5))


func after_each() -> void:
	if is_instance_valid(simulation):
		simulation.free()
	if is_instance_valid(world):
		world.free()
	world = null
	simulation = null
	research = null
	lab = null


func run_ticks(count: int) -> void:
	for i: int in count:
		simulation.tick()


func test_tech_tree_is_consistent() -> void:
	for tech_id: StringName in Technologies.all_ids():
		check(Technologies.total_cost(tech_id) > 0, "бесплатная технология: %s" % tech_id)
		for item_id: StringName in Technologies.cost(tech_id):
			check(Items.exists(item_id), "%s стоит несуществующий %s" % [tech_id, item_id])
		for requirement: Variant in Technologies.requires(tech_id):
			check(Technologies.exists(requirement), "%s требует несуществующую %s" % [tech_id, requirement])
		for def_id: Variant in Technologies.buildings(tech_id):
			check(BuildingDefs.exists(def_id), "%s открывает несуществующее здание %s" % [tech_id, def_id])
		for recipe_id: Variant in Technologies.recipes(tech_id):
			check(Recipes.exists(recipe_id), "%s открывает несуществующий рецепт %s" % [tech_id, recipe_id])
		check(not Technologies.description(tech_id).is_empty(), "нет описания у %s" % tech_id)


func test_locked_content_matches_tech_tree() -> void:
	# Каждое требование в зданиях и рецептах должно указывать на реальную
	# технологию, которая это и открывает.
	for def_id: StringName in BuildingDefs.all_ids():
		var tech_id: StringName = BuildingDefs.required_tech(def_id)
		if tech_id == &"":
			continue
		check(Technologies.exists(tech_id), "здание %s требует несуществующую %s" % [def_id, tech_id])
		check(Technologies.buildings(tech_id).has(def_id), "%s не открывает %s" % [tech_id, def_id])
	for recipe_id: StringName in Recipes.DEFS:
		var tech_id: StringName = Recipes.required_tech(recipe_id)
		if tech_id == &"":
			continue
		check(Technologies.exists(tech_id), "рецепт %s требует несуществующую %s" % [recipe_id, tech_id])
		check(Technologies.recipes(tech_id).has(recipe_id), "%s не открывает %s" % [tech_id, recipe_id])


func test_tech_tree_is_reachable_from_start() -> void:
	# Ни одна технология не должна быть недостижимой: рано или поздно
	# открывается всё.
	var state := ResearchState.new()
	var guard: int = 0
	while state.completed.size() < Technologies.all_ids().size() and guard < 50:
		guard += 1
		for tech_id: StringName in Technologies.all_ids():
			if state.is_available(tech_id):
				state.complete(tech_id)
	check_eq(state.completed.size(), Technologies.all_ids().size(), "часть технологий недостижима")


## Здание, в котором исполняется рецепт.
func machine_building(machine_kind: int) -> StringName:
	match machine_kind:
		Recipes.Machine.FURNACE:
			return BuildingDefs.FURNACE
		Recipes.Machine.LAB:
			return BuildingDefs.LAB
		_:
			return BuildingDefs.ASSEMBLER


## Можно ли получить предмет при текущем наборе открытого.
func item_producible(state: ResearchState, item_id: StringName, depth: int = 0) -> bool:
	if depth > 8:
		return false
	for ore_type: int in Items.ORE_TO_ITEM:
		if Items.ORE_TO_ITEM[ore_type] == item_id:
			return state.is_building_unlocked(BuildingDefs.DRILL)
	var producer: StringName = Items.source_building(item_id)
	if producer != &"":
		return state.is_building_unlocked(producer)
	for recipe_id: StringName in Recipes.DEFS:
		if not Recipes.outputs(recipe_id).has(item_id):
			continue
		if not state.is_recipe_unlocked(recipe_id):
			continue
		if not state.is_building_unlocked(machine_building(Recipes.machine(recipe_id))):
			continue
		var ok: bool = true
		for input_id: StringName in Recipes.inputs(recipe_id):
			if not item_producible(state, input_id, depth + 1):
				ok = false
				break
		if ok:
			return true
	return false


func test_every_tech_is_researchable_with_what_is_already_open() -> void:
	# Настоящая проверка проходимости игры: технологию можно изучить, только
	# если её колбы производятся тем, что открыто ДО неё. Именно на этом
	# попался тупик, когда сборщик был заперт за технологией, которая сама
	# требовала красные колбы из сборщика.
	var state := ResearchState.new()
	var researched: int = 0
	var guard: int = 0
	while guard < 60:
		guard += 1
		var progressed: bool = false
		for tech_id: StringName in Technologies.all_ids():
			if state.is_completed(tech_id) or not state.is_available(tech_id):
				continue
			var affordable: bool = true
			for item_id: StringName in Technologies.cost(tech_id):
				if not item_producible(state, item_id):
					affordable = false
					break
			if affordable:
				state.complete(tech_id)
				researched += 1
				progressed = true
		if not progressed:
			break

	var blocked: PackedStringArray = PackedStringArray()
	for tech_id: StringName in Technologies.all_ids():
		if not state.is_completed(tech_id):
			blocked.append(String(tech_id))
	check(
		blocked.is_empty(),
		"эти технологии невозможно изучить — игра запирается: %s" % ", ".join(blocked)
	)


func test_first_research_is_possible_from_scratch() -> void:
	# На старте игрок должен иметь всё, чтобы сделать первые красные колбы.
	var state := ResearchState.new()
	check(state.is_building_unlocked(BuildingDefs.ASSEMBLER), "сборщик нужен для колб")
	check(state.is_building_unlocked(BuildingDefs.LAB), "лаборатория нужна для исследований")
	check(item_producible(state, Items.SCIENCE_RED), "красные колбы недоступны на старте")


func test_prerequisites_block_research() -> void:
	check(research.can_start(Technologies.MINING_1), "стартовая технология должна быть доступна")
	check(not research.can_start(Technologies.MINING_2), "буры III требуют предшественников")
	world.research.complete(Technologies.MINING_1)
	world.research.complete(Technologies.ELECTRONICS)
	check(research.can_start(Technologies.MINING_2))


func test_lab_consumes_science_and_completes_research() -> void:
	research.start(Technologies.MINING_1)
	lab.input.add(Items.SCIENCE_RED, 60)
	var completed: Array[StringName] = []
	var handler := func(tech_id: StringName) -> void: completed.append(tech_id)
	Events.research_completed.connect(handler)

	run_ticks(Constants.TICKS_PER_SECOND * 60)
	Events.research_completed.disconnect(handler)

	check(world.research.is_completed(Technologies.MINING_1), "исследование должно завершиться")
	check_eq(completed, [Technologies.MINING_1] as Array[StringName])
	check(lab.input.count(Items.SCIENCE_RED) < 60, "колбы должны тратиться")
	check_eq(research.current, &"", "после завершения активного исследования нет")


func test_research_without_science_does_not_progress() -> void:
	research.start(Technologies.MINING_1)
	run_ticks(100)
	check_almost(research.progress(), 0.0, 0.001, "без колб прогресса быть не должно")
	check_eq(lab.status, Building.Status.NO_INPUT)


func test_lab_without_power_does_not_work() -> void:
	for panel: Building in world.buildings.of_kind(BuildingDefs.Kind.SOLAR):
		world.buildings.remove(panel.id)
	research.start(Technologies.MINING_1)
	lab.input.add(Items.SCIENCE_RED, 20)
	run_ticks(50)
	check_eq(lab.status, Building.Status.NO_POWER)
	check_almost(research.progress(), 0.0, 0.001)


func test_lab_requests_only_needed_science() -> void:
	research.start(Technologies.MINING_1)
	simulation.tick()
	var requests: Dictionary[StringName, int] = lab.requests()
	check(requests.has(Items.SCIENCE_RED), "лаборатория должна просить красные колбы")
	check(not requests.has(Items.SCIENCE_GREEN), "зелёные колбы для этой технологии не нужны")


func test_unlocks_open_buildings_and_recipes() -> void:
	check(not world.research.is_building_unlocked(BuildingDefs.ACCUMULATOR), "аккумулятор закрыт на старте")
	check(world.research.is_building_unlocked(BuildingDefs.FURNACE), "печь доступна сразу")
	check(world.research.is_building_unlocked(BuildingDefs.ASSEMBLER), "сборщик доступен сразу")
	check(not world.research.is_recipe_unlocked(Recipes.SMELT_STEEL), "сталь закрыта на старте")

	world.research.complete(Technologies.POWER_STORAGE)
	check(world.research.is_building_unlocked(BuildingDefs.ACCUMULATOR))
	check(world.research.unlocked_buildings().has(BuildingDefs.ACCUMULATOR))

	world.research.complete(Technologies.STEEL)
	check(world.research.unlocked_recipes(Recipes.Machine.FURNACE).has(Recipes.SMELT_STEEL))


func test_bonuses_accumulate() -> void:
	check_almost(world.research.multiplier(Technologies.BONUS_MINING_SPEED), 1.0)
	world.research.complete(Technologies.MINING_1)
	check_almost(world.research.multiplier(Technologies.BONUS_MINING_SPEED), 1.25)
	world.research.complete(Technologies.MINING_2)
	check_almost(world.research.multiplier(Technologies.BONUS_MINING_SPEED), 1.75, 0.001,
		"бонусы одного вида должны складываться")


func test_mining_bonus_speeds_up_drill() -> void:
	var patch: Vector2i = world.start_cell + Vector2i(-6, -6)
	for dy: int in 2:
		for dx: int in 2:
			world.grid.set_ore(patch + Vector2i(dx, dy), TileTypes.Ore.IRON, 900)
	var drill: Drill = world.buildings.place(BuildingDefs.DRILL, patch) as Drill
	world.buildings.place(BuildingDefs.SOLAR, patch + Vector2i(0, 3))

	world.research.complete(Technologies.MINING_1)
	run_ticks(Constants.TICKS_PER_SECOND * 10)
	check_almost(drill.speed_multiplier, 1.25, 0.001, "бонус должен доходить до бура")
	var expected: int = int(Drill.BASE_SPEED * 1.25 * 10.0)
	check(absi(drill.output.count(Items.IRON_ORE) - expected) <= 2,
		"добыто %d вместо ~%d" % [drill.output.count(Items.IRON_ORE), expected])


func test_solar_bonus_increases_output() -> void:
	var panel: SolarPanel = world.buildings.of_kind(BuildingDefs.Kind.SOLAR)[0] as SolarPanel
	world.research.complete(Technologies.SOLAR_EFFICIENCY)
	simulation.tick()
	check_almost(panel.output_multiplier, 1.3, 0.001)
	check_almost(panel.power_supply(1.0), BuildingDefs.power_gen(BuildingDefs.SOLAR) * 1.3, 0.01)


func test_locked_building_cannot_be_built() -> void:
	var camera := GameCamera.new()
	camera.view_size_override = Vector2(720, 1280)
	world.add_child(camera)
	camera.focus_on_cell(world.start_cell)
	var controller := BuildController.new()
	Engine.get_main_loop().root.add_child(controller)
	controller.setup(world, camera)

	controller.start_building(BuildingDefs.ACCUMULATOR)
	check(not controller.is_building(), "закрытое здание не должно входить в режим стройки")
	world.research.complete(Technologies.POWER_STORAGE)
	controller.start_building(BuildingDefs.ACCUMULATOR)
	check(controller.is_building(), "после исследования здание должно стать доступным")
	controller.free()


func test_cancel_keeps_completed_but_drops_progress() -> void:
	research.start(Technologies.MINING_1)
	lab.input.add(Items.SCIENCE_RED, 5)
	run_ticks(60)
	check(research.progress() > 0.0)
	research.cancel()
	check_eq(research.current, &"")
	check_almost(research.progress(), 0.0, 0.001)


func test_research_state_survives_save() -> void:
	world.research.complete(Technologies.MINING_1)
	research.start(Technologies.ELECTRONICS)
	lab.input.add(Items.SCIENCE_RED, 10)
	run_ticks(60)

	var state_data: Array = world.research.serialize()
	var system_data: Dictionary = research.serialize()

	var restored := ResearchState.new()
	restored.deserialize(state_data)
	check(restored.is_completed(Technologies.MINING_1))
	check_almost(restored.multiplier(Technologies.BONUS_MINING_SPEED), 1.25)

	research.deserialize(system_data)
	check_eq(research.current, Technologies.ELECTRONICS, "активное исследование должно сохраняться")
	check(research.progress() > 0.0, "вложенные колбы должны сохраняться")


func test_save_drops_unknown_technologies() -> void:
	var restored := ResearchState.new()
	restored.deserialize(["mining_1", "obsolete_tech"])
	check_eq(restored.completed.size(), 1, "исчезнувшая технология не должна ломать загрузку")
