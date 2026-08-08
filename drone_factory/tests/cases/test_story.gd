extends TestCase
## Сюжет, обучение и финал игры.

var world: GameWorld = null
var simulation: Simulation = null
var story: StorySystem = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(1234)
	for i: int in world.grid.size * world.grid.size:
		world.grid.terrain[i] = TileTypes.Terrain.GRASS

	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	simulation.add_system(PowerSystem.new())
	simulation.add_system(BuildingSystem.new())
	simulation.add_system(AchievementSystem.new())
	story = StorySystem.new()
	simulation.add_system(story)
	simulation.setup(world)
	GameSetup.create_starting_base(world)


func after_each() -> void:
	for node: Node in [simulation, world]:
		if is_instance_valid(node):
			node.free()
	world = null
	simulation = null
	story = null


func run_ticks(count: int) -> void:
	for i: int in count:
		simulation.tick()


func test_chapters_are_well_formed() -> void:
	check(Story.chapter_count() >= 5, "история должна вести игрока через всю игру")
	var seen: Array[StringName] = []
	for i: int in Story.chapter_count():
		var chapter: Dictionary = Story.chapter_at(i)
		var id := StringName(chapter["id"])
		check(not seen.has(id), "повтор идентификатора главы: %s" % id)
		seen.append(id)
		check(not String(chapter["title"]).is_empty(), "нет заголовка: %s" % id)
		check(not String(chapter["text"]).is_empty(), "нет текста: %s" % id)
		check(not String(chapter["hint"]).is_empty(), "нет подсказки: %s" % id)
		check(not (chapter["objective"] as Dictionary).is_empty(), "нет задачи: %s" % id)
		for item_id: StringName in chapter.get("reward", {}):
			check(Items.exists(item_id), "%s: награда несуществующим предметом" % id)


func test_objectives_reference_real_content() -> void:
	for i: int in Story.chapter_count():
		var condition: Dictionary = Story.chapter_at(i)["objective"]
		match String(condition.get("kind", "")):
			"item":
				check(Items.exists(StringName(condition["item"])), "глава %d: нет предмета" % i)
			"built":
				check(BuildingDefs.exists(StringName(condition["def"])), "глава %d: нет здания" % i)
			"tech":
				check(Technologies.exists(StringName(condition["tech"])), "глава %d: нет технологии" % i)
			"techs", "won":
				check(true)
			_:
				check(false, "глава %d: неизвестный вид задачи" % i)


func test_first_chapter_is_the_tutorial_step() -> void:
	check_eq(story.current, 0, "игра начинается с первой главы")
	check(story.hint().to_lower().contains("бур"), "первая задача должна учить ставить бур: %s" % story.hint())
	check(not story.is_finished())


func test_chapter_advances_when_objective_is_met() -> void:
	var patch: Vector2i = world.start_cell + Vector2i(8, 8)
	for dy: int in 2:
		for dx: int in 2:
			world.grid.set_ore(patch + Vector2i(dx, dy), TileTypes.Ore.IRON, 500)
	world.buildings.place(BuildingDefs.DRILL, patch)

	run_ticks(StorySystem.CHECK_EVERY_TICKS * 2)
	check_eq(story.current, 1, "после постройки бура должна начаться вторая глава")
	check(story.hint().to_lower().contains("печь"), "вторая задача про печь: %s" % story.hint())


func test_reward_is_granted_to_storage() -> void:
	var pool := ResourcePool.new(world.buildings)
	var before: int = pool.count(Items.STONE)
	var patch: Vector2i = world.start_cell + Vector2i(8, 8)
	for dy: int in 2:
		for dx: int in 2:
			world.grid.set_ore(patch + Vector2i(dx, dy), TileTypes.Ore.IRON, 500)
	world.buildings.place(BuildingDefs.DRILL, patch)
	run_ticks(StorySystem.CHECK_EVERY_TICKS * 2)
	check(pool.count(Items.STONE) > before, "награда за главу должна попасть на склад")


func test_progress_text_shows_counts() -> void:
	story.current = 1
	Events.items_produced.emit(Items.IRON_PLATE, 7)
	run_ticks(1)
	check_eq(story.progress_text(), "7 / 20", "игрок должен видеть, сколько осталось")


func test_story_events_are_emitted() -> void:
	var advanced: Array[StringName] = []
	var handler := func(finished: StringName, _next: StringName) -> void: advanced.append(finished)
	Events.story_advanced.connect(handler)
	var patch: Vector2i = world.start_cell + Vector2i(8, 8)
	for dy: int in 2:
		for dx: int in 2:
			world.grid.set_ore(patch + Vector2i(dx, dy), TileTypes.Ore.IRON, 500)
	world.buildings.place(BuildingDefs.DRILL, patch)
	run_ticks(StorySystem.CHECK_EVERY_TICKS * 2)
	Events.story_advanced.disconnect(handler)
	check_eq(advanced, [&"crash"] as Array[StringName])


## --- Маяк и финал ----------------------------------------------------------

func test_beacon_needs_sustained_power() -> void:
	var beacon: Beacon = world.buildings.place(
		BuildingDefs.BEACON, world.start_cell + Vector2i(8, 8)
	) as Beacon
	check(beacon != null, "маяк должен создаваться классом Beacon")

	beacon.power_satisfaction = 0.0
	beacon.tick(1.0, {})
	check_almost(beacon.progress(), 0.0, 0.001, "без энергии заряд не идёт")
	check_eq(beacon.status, Building.Status.NO_POWER)

	beacon.power_satisfaction = 1.0
	for i: int in 30:
		beacon.tick(1.0, {})
	check(beacon.progress() > 0.0, "под током маяк должен заряжаться")

	# Отключение энергии съедает накопленное: финал требует стабильной сети.
	var charged: float = beacon.progress()
	beacon.power_satisfaction = 0.0
	for i: int in 10:
		beacon.tick(1.0, {})
	check(beacon.progress() < charged, "без питания заряд должен утекать")


func test_beacon_finishes_the_game() -> void:
	var beacon: Beacon = world.buildings.place(
		BuildingDefs.BEACON, world.start_cell + Vector2i(8, 8)
	) as Beacon
	var won: Array[int] = [0]
	var handler := func() -> void: won[0] += 1
	Events.game_won.connect(handler)

	beacon.power_satisfaction = 1.0
	for i: int in int(Beacon.CHARGE_SECONDS) + 2:
		beacon.tick(1.0, {})
	Events.game_won.disconnect(handler)

	check_eq(won[0], 1, "полный заряд должен завершать игру ровно один раз")
	check(beacon.transmitted)
	check(story.won, "система сюжета должна узнать о победе")


func test_last_chapter_completes_on_victory() -> void:
	story.current = Story.chapter_count() - 1
	check_eq(String(story.chapter()["id"]), "transmit")
	Events.game_won.emit()
	run_ticks(StorySystem.CHECK_EVERY_TICKS * 2)
	check(story.is_finished(), "после победы история должна завершиться")
	check_eq(story.title(), Story.ENDING_TITLE)


func test_beacon_state_survives_save() -> void:
	var beacon: Beacon = world.buildings.place(
		BuildingDefs.BEACON, world.start_cell + Vector2i(8, 8)
	) as Beacon
	beacon.power_satisfaction = 1.0
	for i: int in 20:
		beacon.tick(1.0, {})
	var data: Array = world.buildings.serialize()

	var registry := BuildingRegistry.new(world.grid)
	world.buildings.clear()
	registry.deserialize(data)
	# В реестре есть и стартовая база, поэтому маяк ищем явно, а не по индексу.
	var restored: Beacon = null
	for building: Building in registry.all():
		if building is Beacon:
			restored = building
	check(restored != null, "маяк должен восстановиться")
	if restored == null:
		return
	check_almost(restored.progress(), beacon.progress(), 0.01, "заряд маяка должен сохраняться")


func test_story_state_survives_save() -> void:
	story.current = 3
	story.won = false
	var data: Dictionary = story.serialize()
	story.reset()
	check_eq(story.current, 0)
	story.deserialize(data)
	check_eq(story.current, 3, "номер главы должен сохраняться")

	story.deserialize({"chapter": 999, "won": true})
	check_eq(story.current, Story.chapter_count(), "битый номер главы не должен ломать игру")
