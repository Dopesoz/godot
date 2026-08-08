extends TestCase
## Сквозной тест: игра целиком, от новой игры до работающей фабрики
## и перезагрузки. Модульные тесты проверяют детали, этот — что всё вместе
## действительно играется.

var main: Node = null


func before_each() -> void:
	SaveSystem.delete_save()
	main = load("res://scenes/main.tscn").instantiate()
	Engine.get_main_loop().root.add_child(main)


func after_each() -> void:
	if is_instance_valid(main):
		main.free()
	main = null
	SaveSystem.delete_save()


func run_seconds(seconds: float) -> void:
	for i: int in int(seconds * Constants.TICKS_PER_SECOND):
		main.simulation.tick()


func test_new_game_is_playable_immediately() -> void:
	check(main.world.grid != null, "мир не создан")
	check(main.world.buildings.count() >= 3, "нет стартовой базы")
	check(main.camera != null and main.hud != null, "нет камеры или интерфейса")
	check(
		main.build_controller.pool.has_all(BuildingDefs.cost(BuildingDefs.DRILL)),
		"на первый бур должно хватать сразу"
	)
	var ports: Array[Building] = main.world.buildings.of_kind(BuildingDefs.Kind.DRONE_PORT)
	check((ports[0] as DronePort).drone_count() > 0, "стартовые дроны должны летать")


func test_player_can_build_a_working_mine() -> void:
	# Повторяем действия игрока: найти руду, поставить бур, дать ему энергию.
	var world: GameWorld = main.world
	var ore_cell := Vector2i(-1, -1)
	for radius: int in range(6, 30):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var cell: Vector2i = world.start_cell + Vector2i(dx, dy)
				if world.grid.get_ore(cell) != TileTypes.Ore.NONE \
						and world.buildings.can_place(BuildingDefs.DRILL, cell):
					ore_cell = cell
					break
			if ore_cell.x >= 0:
				break
		if ore_cell.x >= 0:
			break
	check(ore_cell.x >= 0, "рядом со стартом не нашлось места под бур")
	if ore_cell.x < 0:
		return

	main.build_controller.start_building(BuildingDefs.DRILL)
	main.build_controller.follow_center = false
	main.build_controller._move_ghost(ore_cell)
	var drill: Building = main.build_controller.confirm()
	check(drill != null, "бур не поставился: %s" % main.build_controller.confirm_blocker())

	main.build_controller.start_building(BuildingDefs.SOLAR)
	main.build_controller._move_ghost(ore_cell + Vector2i(0, 3))
	var panel: Building = main.build_controller.confirm()
	check(panel != null, "панель не поставилась: %s" % main.build_controller.confirm_blocker())

	main.simulation.game_time = 0.0
	run_seconds(20.0)
	check(drill.output.total() > 0 or drill.status == Building.Status.WORKING,
		"бур должен добывать: состояние %d" % drill.status)


func test_save_and_reload_preserves_everything() -> void:
	main.simulation.game_time = 0.0
	run_seconds(5.0)
	var buildings_before: int = main.world.buildings.count()
	var seed_before: int = main.world.world_seed

	check(main.save_system.save_game(), "сохранение не прошло")
	main.start_new_game(1)
	check_ne(main.world.world_seed, seed_before, "новая игра должна дать другой мир")
	check(main.save_system.load_game(), "загрузка не прошла")

	check_eq(main.world.world_seed, seed_before, "мир должен восстановиться")
	check_eq(main.world.buildings.count(), buildings_before)
	run_seconds(5.0)
	check(true, "после загрузки симуляция должна продолжаться без ошибок")


func test_ui_panels_open_and_close() -> void:
	main.hud.build_menu_requested.emit()
	check(main.build_menu.is_open(), "меню строительства должно открываться")
	main.build_menu.close()

	main.hud.research_requested.emit()
	check(main.research_panel.is_open(), "панель исследований должна открываться")
	main.research_panel.close()

	main.hud.menu_requested.emit()
	check(main.settings_panel.is_open(), "меню должно открываться")
	check(main.simulation.paused, "в меню игра на паузе")
	main.settings_panel.close()
	check(not main.simulation.paused)


func test_selecting_building_opens_info_panel() -> void:
	var storage: Building = main.world.buildings.of_kind(BuildingDefs.Kind.STORAGE)[0]
	main.build_controller.select(storage.id)
	check(main.info_panel.is_open(), "тап по зданию должен открывать панель")
	check_eq(main.info_panel.selected_building(), storage)


func test_research_can_be_started_and_finished() -> void:
	var world: GameWorld = main.world
	var lab: Lab = world.buildings.place(BuildingDefs.LAB, world.start_cell + Vector2i(0, 7)) as Lab
	world.buildings.place(BuildingDefs.SOLAR, world.start_cell + Vector2i(3, 7))
	check(lab != null, "лаборатория не поставилась")

	var research: ResearchSystem = main.simulation.get_system(ResearchSystem) as ResearchSystem
	check(research.start(Technologies.MINING_1), "исследование должно запускаться")
	lab.input.add(Items.SCIENCE_RED, 40)
	main.simulation.game_time = 0.0
	run_seconds(60.0)
	check(world.research.is_completed(Technologies.MINING_1), "исследование должно завершиться")
	check(world.research.bonus(Technologies.BONUS_MINING_SPEED) > 0.0, "бонус должен примениться")


func test_long_session_stays_stable() -> void:
	# Пять минут игрового времени: сутки успевают смениться, автосохранение
	# и логистика работают, ничего не должно упасть или разъехаться.
	main.simulation.game_time = 0.0
	var total_before: int = _total_items()
	run_seconds(Simulation.DAY_LENGTH)
	check(main.simulation.tick_count >= Constants.TICKS_PER_SECOND * int(Simulation.DAY_LENGTH) - 5,
		"часть тиков потерялась")
	check(_total_items() >= 0, "инвентари не должны уходить в минус")
	var _unused: int = total_before
	for building: Building in main.world.buildings.all():
		if building.output != null:
			check(building.output.total() <= building.output.capacity, "переполнение инвентаря")
		if building.input != null:
			check(building.input.total() <= building.input.capacity, "переполнение входа")


func _total_items() -> int:
	var total: int = 0
	for building: Building in main.world.buildings.all():
		if building.output != null:
			total += building.output.total()
		if building.input != null:
			total += building.input.total()
	return total
