extends TestCase
## Достижения и статистика партии.

var world: GameWorld = null
var simulation: Simulation = null
var achievements: AchievementSystem = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(9191)
	for i: int in world.grid.size * world.grid.size:
		world.grid.terrain[i] = TileTypes.Terrain.GRASS

	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	achievements = AchievementSystem.new()
	simulation.add_system(achievements)
	simulation.setup(world)


func after_each() -> void:
	for node: Node in [simulation, world]:
		if is_instance_valid(node):
			node.free()
	world = null
	simulation = null
	achievements = null


func run_ticks(count: int) -> void:
	for i: int in count:
		simulation.tick()


func test_catalog_is_well_formed() -> void:
	for id: StringName in Achievements.all_ids():
		check(not Achievements.display_name(id).is_empty(), "нет названия: %s" % id)
		check(not Achievements.description(id).is_empty(), "нет описания: %s" % id)
		var condition: Dictionary = Achievements.condition(id)
		check(not condition.is_empty(), "нет условия: %s" % id)
		match String(condition.get("kind", "")):
			"item":
				check(Items.exists(StringName(condition["item"])), "%s: неизвестный предмет" % id)
			"built":
				check(BuildingDefs.exists(StringName(condition["def"])), "%s: неизвестное здание" % id)
			"tech":
				check(Technologies.exists(StringName(condition["tech"])), "%s: неизвестная технология" % id)
			"techs":
				check(int(condition.get("target", 0)) > 0, "%s: нулевая цель" % id)
			_:
				check(false, "%s: неизвестный вид условия" % id)


func test_production_counts_towards_achievements() -> void:
	Events.items_produced.emit(Items.IRON_PLATE, 1)
	run_ticks(AchievementSystem.CHECK_EVERY_TICKS)
	check(achievements.is_unlocked(&"first_smelt"), "первая пластина должна открыть достижение")
	check(not achievements.is_unlocked(&"hundred_plates"), "сотня ещё не набрана")

	Events.items_produced.emit(Items.IRON_PLATE, 99)
	run_ticks(AchievementSystem.CHECK_EVERY_TICKS)
	check(achievements.is_unlocked(&"hundred_plates"), "сотня пластин должна открыть достижение")


func test_mined_and_produced_are_summed() -> void:
	# Пластины плавят, а воду качают: для игрока это одинаково «получено».
	Events.items_harvested.emit(Items.WATER, 300)
	Events.items_harvested.emit(Items.WATER, 250)
	run_ticks(AchievementSystem.CHECK_EVERY_TICKS)
	check(achievements.is_unlocked(&"waterworks"), "накачанная вода должна засчитываться")


func test_building_placement_counts() -> void:
	var patch: Vector2i = world.start_cell + Vector2i(6, 6)
	for dy: int in 2:
		for dx: int in 2:
			world.grid.set_ore(patch + Vector2i(dx, dy), TileTypes.Ore.IRON, 300)
	world.buildings.place(BuildingDefs.DRILL, patch)
	run_ticks(AchievementSystem.CHECK_EVERY_TICKS)
	check(achievements.is_unlocked(&"first_drill"), "первый бур должен открыть достижение")


func test_research_counts() -> void:
	Events.research_completed.emit(Technologies.MINING_1)
	run_ticks(AchievementSystem.CHECK_EVERY_TICKS)
	check(achievements.is_unlocked(&"first_tech"))
	check(not achievements.is_unlocked(&"five_techs"))
	for i: int in 4:
		Events.research_completed.emit(Technologies.ELECTRONICS)
	run_ticks(AchievementSystem.CHECK_EVERY_TICKS)
	check(achievements.is_unlocked(&"five_techs"))


func test_achievement_unlocks_once() -> void:
	var events: Array[StringName] = []
	var handler := func(id: StringName) -> void: events.append(id)
	Events.achievement_unlocked.connect(handler)
	Events.items_produced.emit(Items.IRON_PLATE, 5)
	run_ticks(AchievementSystem.CHECK_EVERY_TICKS * 4)
	Events.achievement_unlocked.disconnect(handler)
	check_eq(events.count(&"first_smelt"), 1, "достижение не должно открываться повторно")


func test_progress_text() -> void:
	Events.items_produced.emit(Items.IRON_PLATE, 43)
	check_eq(achievements.progress_text(&"hundred_plates"), "43 / 100")
	check_eq(world.stats.total_of(Items.IRON_PLATE), 43)


func test_checks_are_throttled() -> void:
	# Условия не должны пересчитываться на каждый тик: печь выдаёт пластины
	# десятки раз в секунду.
	Events.items_produced.emit(Items.IRON_PLATE, 1)
	simulation.tick_count = 1
	simulation.tick()
	check(not achievements.is_unlocked(&"first_smelt"), "проверка идёт не каждый тик")
	simulation.tick_count = AchievementSystem.CHECK_EVERY_TICKS - 1
	simulation.tick()
	check(achievements.is_unlocked(&"first_smelt"))


func test_state_survives_save() -> void:
	Events.items_produced.emit(Items.IRON_PLATE, 120)
	run_ticks(AchievementSystem.CHECK_EVERY_TICKS)
	var unlocked_data: Array = achievements.serialize()
	var stats_data: Dictionary = world.stats.serialize()

	achievements.reset()
	world.stats.clear()
	check(not achievements.is_unlocked(&"hundred_plates"))

	achievements.deserialize(unlocked_data)
	world.stats.deserialize(stats_data)
	check(achievements.is_unlocked(&"hundred_plates"), "открытые достижения должны сохраняться")
	check_eq(world.stats.total_of(Items.IRON_PLATE), 120, "статистика должна сохраняться")


func test_unknown_achievement_in_save_is_skipped() -> void:
	achievements.deserialize(["first_smelt", "obsolete_achievement"])
	check_eq(achievements.unlocked_count(), 1, "исчезнувшее достижение не должно ломать загрузку")
