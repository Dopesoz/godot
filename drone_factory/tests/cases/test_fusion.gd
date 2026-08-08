extends TestCase
## Термоядерная цепочка: водоём -> вода -> тритий -> энергия.
##
## Проверяется не только «реактор даёт ток», но и то, что цепочка достижима:
## всё, из чего она состоит, открывается одной технологией и делается на
## зданиях, которые эта технология же и открывает.

var world: GameWorld = null
var simulation: Simulation = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(6161)
	for i: int in world.grid.size * world.grid.size:
		world.grid.terrain[i] = TileTypes.Terrain.GRASS
	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	world.simulation = simulation
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


func place(def_id: StringName, offset: Vector2i) -> Building:
	return world.buildings.place(def_id, world.start_cell + offset)


func run_ticks(count: int) -> void:
	for i: int in count:
		simulation.tick()


func test_fusion_comes_after_nuclear() -> void:
	check(
		Technologies.requires(Technologies.FUSION).has(Technologies.NUCLEAR),
		"термояд должен идти после атома"
	)
	check(
		not world.research.is_available(Technologies.FUSION),
		"термояд не должен быть доступен с самого начала"
	)
	for tech_id: StringName in Technologies.requires(Technologies.FUSION):
		world.research.complete(tech_id)
	check(world.research.is_available(Technologies.FUSION), "после атома термояд должен открыться")


func test_fusion_tech_opens_the_whole_chain() -> void:
	world.research.complete(Technologies.FUSION)
	check(world.research.is_building_unlocked(BuildingDefs.TRITIUM_PLANT), "нет завода")
	check(world.research.is_building_unlocked(BuildingDefs.FUSION), "нет реактора")
	check(world.research.is_recipe_unlocked(Recipes.EXTRACT_TRITIUM), "нет рецепта трития")


func test_tritium_is_made_from_water() -> void:
	var inputs: Dictionary = Recipes.inputs(Recipes.EXTRACT_TRITIUM)
	check(inputs.has(Items.WATER), "тритий должен получаться из воды")
	check_eq(Recipes.machine(Recipes.EXTRACT_TRITIUM), Recipes.Machine.TRITIUM_PLANT)

	var plant: TritiumPlant = place(BuildingDefs.TRITIUM_PLANT, Vector2i(0, 0)) as TritiumPlant
	check(plant != null, "завод должен создаваться своим классом")
	plant.set_recipe(Recipes.EXTRACT_TRITIUM)
	plant.input.add(Items.WATER, 200)
	plant.power_satisfaction = 1.0

	for i: int in 200:
		plant.tick(Constants.TICK_DELTA, {})
	check(plant.output.count(Items.TRITIUM) > 0, "завод не выдал тритий")


func test_only_the_plant_accepts_the_tritium_recipe() -> void:
	var assembler: Assembler = place(BuildingDefs.ASSEMBLER, Vector2i(6, 0)) as Assembler
	assembler.set_recipe(Recipes.EXTRACT_TRITIUM)
	check_ne(
		assembler.current_recipe(), Recipes.EXTRACT_TRITIUM,
		"сборщик не должен уметь выделять тритий"
	)


func test_fusion_reactor_burns_tritium_and_gives_power() -> void:
	var reactor: FusionReactor = place(BuildingDefs.FUSION, Vector2i(0, 0)) as FusionReactor
	check(reactor != null, "реактор должен создаваться своим классом")
	check_eq(reactor.fuel_item(), Items.TRITIUM)

	check_eq(reactor.power_supply(1.0), 0.0, "без топлива энергии быть не должно")
	reactor.input.add(Items.TRITIUM, 4)
	reactor.input.add(Items.WATER, 200)
	run_ticks(3)
	check(reactor.power_supply(1.0) > 0.0, "с топливом реактор обязан давать ток")
	check(
		reactor.power_supply(1.0) > BuildingDefs.power_gen(BuildingDefs.REACTOR),
		"термояд должен быть мощнее атома"
	)


func test_fusion_does_not_pollute() -> void:
	check_eq(BuildingDefs.pollution(BuildingDefs.FUSION), 0.0, "термояд не должен коптить")
	check(
		BuildingDefs.pollution(BuildingDefs.BOILER) > 0.0,
		"котёл для сравнения обязан коптить"
	)
