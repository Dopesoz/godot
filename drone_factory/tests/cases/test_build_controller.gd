extends TestCase
## Строительство: оплата из общего склада, призрак, подтверждение, снос.

var world: GameWorld = null
var camera: GameCamera = null
var controller: BuildController = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(4242)

	camera = GameCamera.new()
	camera.view_size_override = Vector2(720, 1280)
	world.add_child(camera)
	camera.set_zoom_level(2.0, false)
	camera.focus_on_cell(world.start_cell)

	controller = BuildController.new()
	Engine.get_main_loop().root.add_child(controller)
	controller.setup(world, camera)
	GameSetup.create_starting_base(world)


func after_each() -> void:
	if is_instance_valid(controller):
		controller.free()
	if is_instance_valid(world):
		world.free()
	world = null
	camera = null
	controller = null


## Свободная клетка на стартовой площадке: сама площадка уже занята
## стартовой базой, поэтому строить в тестах нужно рядом.
func aim(offset: Vector2i) -> void:
	controller.follow_center = false
	controller._move_ghost(world.start_cell + offset)


func test_starting_base_is_usable() -> void:
	check(world.buildings.count() >= 2, "стартовых зданий должно быть минимум два")
	check(controller.pool.count(Items.IRON_PLATE) > 0, "нет стартового железа")
	check(
		controller.pool.has_all(BuildingDefs.cost(BuildingDefs.DRILL)),
		"стартового запаса должно хватать на первый бур"
	)


func test_build_mode_places_ghost_at_screen_center() -> void:
	controller.start_building(BuildingDefs.SOLAR)
	check(controller.is_building())
	check_eq(world.building_renderer.ghost_def_id, BuildingDefs.SOLAR)
	var center_cell: Vector2i = camera.screen_to_cell(camera.view_size() * 0.5)
	check(
		Vector2(controller.pending_origin).distance_to(Vector2(center_cell)) <= 2.0,
		"призрак должен появляться под прицелом в центре экрана"
	)


func test_first_tap_moves_ghost_second_places() -> void:
	controller.start_building(BuildingDefs.SOLAR)
	var before: int = world.buildings.count()
	var point := Vector2(300, 500)

	controller.on_tap(point)
	check_eq(world.buildings.count(), before, "первый тап только переносит призрак")
	check_eq(controller.pending_origin, camera.screen_to_cell(point) - Vector2i(1, 1))

	controller.on_tap(point)
	check_eq(world.buildings.count(), before + 1, "повторный тап должен строить")


func test_cost_is_charged_and_refunded() -> void:
	var before: int = controller.pool.count(Items.IRON_PLATE)
	controller.start_building(BuildingDefs.SOLAR)
	aim(Vector2i(0, 6))
	var cost: int = int(BuildingDefs.cost(BuildingDefs.SOLAR)[Items.IRON_PLATE])
	var building: Building = controller.confirm()
	check(building != null, "постройка не удалась")
	check_eq(controller.pool.count(Items.IRON_PLATE), before - cost, "стоимость не списана")

	# Снос возвращает стоимость целиком: переставить здание должно быть
	# бесплатно, иначе игрок боится трогать уже построенное.
	controller.demolish(building.id)
	check_eq(
		controller.pool.count(Items.IRON_PLATE), before,
		"после сноса ресурсов должно стать столько же, сколько было до постройки"
	)


func test_cannot_build_without_resources() -> void:
	# Опустошаем склады и пробуем строить.
	for building: Building in controller.pool.stores():
		building.output.clear()
	controller.start_building(BuildingDefs.SOLAR)
	aim(Vector2i(0, 6))
	check(not controller.can_confirm(), "без ресурсов строить нельзя")
	# Отказ обязан называть предмет: «не хватает ресурсов» ничего не подсказывает.
	var blocker: String = controller.confirm_blocker()
	check(
		blocker.contains(Items.display_name(Items.IRON_PLATE)),
		"в отказе должен быть назван недостающий предмет, получено: %s" % blocker
	)
	check_eq(controller.confirm(), null)


func test_blocked_place_reports_reason() -> void:
	controller.start_building(BuildingDefs.SOLAR)
	aim(Vector2i(0, 6))
	var first: Building = controller.confirm()
	check(first != null, "первая панель должна поставиться")
	if first == null:
		return
	# Ставим второе здание ровно туда же.
	aim(Vector2i(0, 6))
	check(not controller.can_confirm())
	check_eq(controller.confirm_blocker(), "Место занято")


func test_drill_needs_ore() -> void:
	controller.start_building(BuildingDefs.DRILL)
	# Пятачок вокруг базы генератор чистит от руды, значит бур сюда не встанет.
	aim(Vector2i(-2, 2))
	check_eq(world.grid.get_ore(world.start_cell + Vector2i(-2, 2)), TileTypes.Ore.NONE)
	check_eq(controller.confirm_blocker(), "Здесь нет руды")


func test_build_mode_stays_active_after_placing() -> void:
	controller.start_building(BuildingDefs.SOLAR)
	aim(Vector2i(0, 6))
	controller.confirm()
	check(controller.is_building(), "после постройки режим должен оставаться включённым")
	check(controller.follow_center, "призрак снова следует за центром экрана")


func test_long_press_cancels_build_mode() -> void:
	controller.start_building(BuildingDefs.SOLAR)
	controller.on_long_press(Vector2(300, 500))
	check(not controller.is_building(), "долгое нажатие должно отменять строительство")
	check_eq(world.building_renderer.ghost_def_id, &"", "призрак должен исчезнуть")


func test_tap_selects_building() -> void:
	var port: Building = world.buildings.of_kind(BuildingDefs.Kind.DRONE_PORT)[0]
	var screen: Vector2 = camera.world_to_screen(port.center())
	controller.on_tap(screen)
	check_eq(controller.selected_id, port.id, "тап по зданию должен его выбирать")

	# Тап по пустому месту снимает выделение.
	controller.on_tap(camera.world_to_screen(Grid.cell_to_world_center(world.start_cell + Vector2i(9, 9))))
	check_eq(controller.selected_id, 0)


func test_demolish_returns_contents() -> void:
	var storage: Building = world.buildings.of_kind(BuildingDefs.Kind.STORAGE)[0]
	controller.start_building(BuildingDefs.STORAGE)
	aim(Vector2i(0, 6))
	var second: Building = controller.confirm()
	check(second != null, "второй склад должен поставиться")
	if second == null:
		return
	second.output.add(Items.GEAR, 15)
	var before: int = controller.pool.count(Items.GEAR)

	controller.demolish(second.id)
	check(
		controller.pool.count(Items.GEAR) >= before,
		"содержимое снесённого склада должно вернуться игроку"
	)
	check_eq(storage.output.count(Items.GEAR) > 0, true, "вещи должны осесть на другом складе")


func test_pool_take_all_is_atomic() -> void:
	var pool: ResourcePool = controller.pool
	var iron: int = pool.count(Items.IRON_PLATE)
	check(not pool.take_all({Items.IRON_PLATE: iron + 1, Items.GEAR: 1}), "неполный набор не списывается")
	check_eq(pool.count(Items.IRON_PLATE), iron, "ресурсы не должны пропадать при отказе")


func test_walls_and_poles_go_up_with_a_single_tap() -> void:
	# Забор вокруг базы — это десятки клеток. По два тапа на каждую делали бы
	# оборону утомительной вознёй, а промах стеной из двух кирпичей ничего
	# не стоит.
	world.research.complete(Technologies.DEFENCE)
	controller.pool.give(Items.BRICK, 40)
	controller.start_building(BuildingDefs.WALL)
	var before: int = world.buildings.count()
	for i: int in 4:
		controller.on_tap(camera.world_to_screen(Grid.cell_to_world_center(world.start_cell + Vector2i(i + 4, 8))))
	check_eq(
		world.buildings.count(), before + 4,
		"каждый тап должен ставить секцию забора"
	)
	check_eq(controller.pending_def_id, BuildingDefs.WALL, "режим стройки не должен сбрасываться")


func test_machines_still_need_confirmation() -> void:
	# У больших зданий двойное подтверждение остаётся: палец закрывает цель,
	# а промах стоит ресурсов и сноса.
	controller.start_building(BuildingDefs.STORAGE)
	var before: int = world.buildings.count()
	var screen: Vector2 = camera.world_to_screen(Grid.cell_to_world_center(world.start_cell + Vector2i(8, 8)))
	controller.on_tap(screen)
	check_eq(world.buildings.count(), before, "первый тап только наводит призрак")
	controller.on_tap(screen)
	check_eq(world.buildings.count(), before + 1, "второй тап по тому же месту ставит здание")
