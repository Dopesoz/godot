extends TestCase
## Режим разработчика: доступ ко всем механикам без прохождения игры.
##
## Проверяется не только «выдал», но и то, что выданное действительно
## открывает игру: технологии должны разблокировать здания и рецепты, а
## ресурсы — лежать там же, откуда оплачиваются постройки.

var world: GameWorld = null
var simulation: Simulation = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(7373)
	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	world.simulation = simulation
	simulation.add_system(StorySystem.new())
	simulation.setup(world)
	GameSetup.create_starting_base(world)


func after_each() -> void:
	for node: Node in [simulation, world]:
		if is_instance_valid(node):
			node.free()
	world = null
	simulation = null


func test_grants_every_item_to_storage() -> void:
	var pool := ResourcePool.new(world.buildings)
	var delivered: int = DevMode.grant_all_items(world)
	check(delivered > 0, "ничего не выдалось")
	for item_id: StringName in Items.all_ids():
		check(pool.count(item_id) > 0, "не выдан предмет %s" % item_id)


func test_unlocks_everything_buildable_and_craftable() -> void:
	DevMode.unlock_all_research(world)
	for tech_id: StringName in Technologies.all_ids():
		check(world.research.is_completed(tech_id), "не открыта технология %s" % tech_id)
	for def_id: StringName in BuildingDefs.BUILD_ORDER:
		check(world.research.is_building_unlocked(def_id), "не открыто здание %s" % def_id)
	for recipe_id: StringName in Recipes.DEFS:
		check(world.research.is_recipe_unlocked(recipe_id), "не открыт рецепт %s" % recipe_id)


func test_granted_resources_pay_for_the_most_expensive_building() -> void:
	DevMode.grant_all_items(world)
	var pool := ResourcePool.new(world.buildings)
	for def_id: StringName in BuildingDefs.BUILD_ORDER:
		check(
			pool.has_all(BuildingDefs.cost(def_id)),
			"выданного не хватает даже на %s" % def_id
		)


func test_chapter_can_be_skipped() -> void:
	var story: StorySystem = simulation.get_system(StorySystem) as StorySystem
	var before: int = story.current
	check(DevMode.skip_chapter(story), "глава должна пропускаться")
	check_eq(story.current, before + 1, "сюжет не сдвинулся")


func test_repeated_unlock_is_harmless() -> void:
	DevMode.unlock_all_research(world)
	check_eq(DevMode.unlock_all_research(world), 0, "повторное открытие ничего не меняет")
