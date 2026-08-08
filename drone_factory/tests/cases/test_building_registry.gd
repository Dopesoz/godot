extends TestCase
## Реестр зданий: постановка, снос, поиск по клетке и радиусу, сохранение.

var grid: Grid
var registry: BuildingRegistry


func before_each() -> void:
	grid = Grid.new(64)
	for i: int in grid.size * grid.size:
		grid.terrain[i] = TileTypes.Terrain.GRASS
	registry = BuildingRegistry.new(grid)


func test_defs_are_consistent() -> void:
	for def_id: StringName in BuildingDefs.all_ids():
		var size: Vector2i = BuildingDefs.size_of(def_id)
		check(size.x > 0 and size.y > 0, "нулевой размер у %s" % def_id)
		check(BuildingDefs.power_range(def_id) > 0, "нулевой радиус сети у %s" % def_id)
		for item: StringName in BuildingDefs.cost(def_id):
			check(Items.exists(item), "%s стоит несуществующий %s" % [def_id, item])
		check(not BuildingDefs.description(def_id).is_empty(), "нет описания у %s" % def_id)
	for def_id: StringName in BuildingDefs.BUILD_ORDER:
		check(BuildingDefs.exists(def_id), "меню строительства ссылается на %s" % def_id)
		check(BuildingDefs.is_player_built(def_id), "в меню попало непостроимое здание: %s" % def_id)
	# Каждое здание, которое игрок может построить, обязано быть в меню.
	for def_id: StringName in BuildingDefs.all_ids():
		if BuildingDefs.is_player_built(def_id):
			check(BuildingDefs.BUILD_ORDER.has(def_id), "здание %s не попало в меню" % def_id)


func test_place_and_lookup() -> void:
	var building: Building = registry.place(BuildingDefs.STORAGE, Vector2i(10, 10))
	check(building != null, "здание не поставилось")
	check_eq(registry.count(), 1)
	check_eq(registry.at_cell(Vector2i(10, 10)), building)
	check_eq(registry.at_cell(Vector2i(11, 11)), building, "занята вся площадь здания")
	check_eq(registry.at_cell(Vector2i(12, 12)), null)
	check_eq(grid.get_building(Vector2i(10, 11)), building.id, "сетка должна знать о здании")


func test_cannot_overlap() -> void:
	registry.place(BuildingDefs.STORAGE, Vector2i(10, 10))
	check_eq(registry.check_placement(BuildingDefs.STORAGE, Vector2i(11, 11)), BuildingRegistry.PlaceError.OCCUPIED)
	check_eq(registry.place(BuildingDefs.STORAGE, Vector2i(11, 11)), null)
	check_eq(registry.count(), 1)


func test_placement_errors() -> void:
	check_eq(
		registry.check_placement(&"nonexistent", Vector2i(5, 5)),
		BuildingRegistry.PlaceError.UNKNOWN_DEF
	)
	check_eq(
		registry.check_placement(BuildingDefs.STORAGE, Vector2i(63, 63)),
		BuildingRegistry.PlaceError.OUT_OF_BOUNDS
	)
	grid.set_terrain(Vector2i(5, 5), TileTypes.Terrain.WATER)
	check_eq(
		registry.check_placement(BuildingDefs.STORAGE, Vector2i(4, 4)),
		BuildingRegistry.PlaceError.BAD_TERRAIN
	)
	check_eq(
		registry.check_placement(BuildingDefs.DRILL, Vector2i(20, 20)),
		BuildingRegistry.PlaceError.NO_ORE,
		"бур без руды ставить нельзя"
	)
	for error: int in BuildingRegistry.PLACE_ERROR_TEXT:
		if error != BuildingRegistry.PlaceError.OK:
			check(
				not BuildingRegistry.placement_error_text(error).is_empty(),
				"игроку нужно объяснение отказа"
			)


func test_drill_requires_ore_under_it() -> void:
	grid.set_ore(Vector2i(20, 20), TileTypes.Ore.IRON, 500)
	check(registry.can_place(BuildingDefs.DRILL, Vector2i(20, 20)), "бур на руде должен ставиться")
	var drill: Building = registry.place(BuildingDefs.DRILL, Vector2i(20, 20))
	check(drill != null)


func test_remove_frees_cells() -> void:
	var building: Building = registry.place(BuildingDefs.STORAGE, Vector2i(10, 10))
	check(registry.remove(building.id))
	check_eq(registry.count(), 0)
	check_eq(grid.get_building(Vector2i(10, 10)), Grid.NO_BUILDING)
	check(registry.can_place(BuildingDefs.STORAGE, Vector2i(10, 10)), "место должно освободиться")
	check(not registry.remove(building.id), "повторный снос должен возвращать false")


func test_ids_are_unique_and_not_reused() -> void:
	var first: Building = registry.place(BuildingDefs.STORAGE, Vector2i(4, 4))
	registry.remove(first.id)
	var second: Building = registry.place(BuildingDefs.STORAGE, Vector2i(4, 4))
	check_ne(second.id, first.id, "id снесённого здания не должен переиспользоваться")


func test_radius_query_uses_chunk_index() -> void:
	var center: Building = registry.place(BuildingDefs.STORAGE, Vector2i(30, 30))
	registry.place(BuildingDefs.STORAGE, Vector2i(34, 30))
	registry.place(BuildingDefs.STORAGE, Vector2i(2, 2))

	var near: Array[Building] = registry.in_radius(center.center_cell(), 8.0)
	check_eq(near.size(), 2, "в радиусе должны быть два склада")
	var far: Array[Building] = registry.in_radius(center.center_cell(), 60.0)
	check_eq(far.size(), 3, "большой радиус должен захватить все")
	# Здание на границе чанков не должно теряться.
	var edge: Building = registry.place(BuildingDefs.STORAGE, Vector2i(15, 15))
	check(registry.in_radius(edge.center_cell(), 2.0).has(edge), "здание на стыке чанков потерялось")


func test_of_kind_filters() -> void:
	registry.place(BuildingDefs.STORAGE, Vector2i(10, 10))
	registry.place(BuildingDefs.SOLAR, Vector2i(20, 10))
	check_eq(registry.of_kind(BuildingDefs.Kind.SOLAR).size(), 1)
	check_eq(registry.of_kind(BuildingDefs.Kind.STORAGE).size(), 1)
	check_eq(registry.of_kind(BuildingDefs.Kind.LAB).size(), 0)


func test_events_are_emitted() -> void:
	var placed: Array[int] = []
	var removed: Array[int] = []
	var on_placed := func(building_id: int) -> void: placed.append(building_id)
	var on_removed := func(building_id: int) -> void: removed.append(building_id)
	Events.building_placed.connect(on_placed)
	Events.building_removed.connect(on_removed)

	var building: Building = registry.place(BuildingDefs.STORAGE, Vector2i(10, 10))
	registry.remove(building.id)

	Events.building_placed.disconnect(on_placed)
	Events.building_removed.disconnect(on_removed)
	check_eq(placed, [building.id] as Array[int])
	check_eq(removed, [building.id] as Array[int])


func test_serialization_round_trip() -> void:
	var storage: Building = registry.place(BuildingDefs.STORAGE, Vector2i(10, 10))
	storage.output.add(Items.IRON_PLATE, 25)
	registry.place(BuildingDefs.SOLAR, Vector2i(20, 20))
	var data: Array = registry.serialize()

	var other_grid := Grid.new(64)
	for i: int in other_grid.size * other_grid.size:
		other_grid.terrain[i] = TileTypes.Terrain.GRASS
	var other := BuildingRegistry.new(other_grid)
	other.deserialize(data)

	check_eq(other.count(), 2)
	var restored: Building = other.at_cell(Vector2i(10, 10))
	check(restored != null, "склад не восстановился")
	check_eq(restored.def_id, BuildingDefs.STORAGE)
	check_eq(restored.output.count(Items.IRON_PLATE), 25, "содержимое склада потерялось")
	check_eq(other_grid.get_building(Vector2i(21, 21)), other.at_cell(Vector2i(20, 20)).id)


func test_deserialize_skips_unknown_buildings() -> void:
	registry.deserialize([{"id": 1, "def": "obsolete", "x": 3, "y": 3}])
	check_eq(registry.count(), 0, "неизвестное здание из старого сохранения должно пропускаться")


func test_radius_query_performance() -> void:
	# Логистика опрашивает окрестности постоянно: запрос обязан быть дешёвым
	# даже когда фабрика разрослась.
	for i: int in 200:
		registry.place(BuildingDefs.STORAGE, Vector2i((i % 20) * 3, (i / 20) * 3))
	var start_usec: int = Time.get_ticks_usec()
	for i: int in 200:
		registry.in_radius(Vector2i(30, 30), 10.0)
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	check(elapsed_ms < 60.0, "200 запросов по радиусу заняли %.1f мс" % elapsed_ms)


func test_kind_cache_is_not_corrupted_by_callers() -> void:
	# of_kind() отдаёт кеш по ссылке ради скорости. Значит, любой, кто собирает
	# из него свой список, обязан начинать с пустого массива — иначе кеш
	# складов пополняется чужими зданиями, а ресурсы начинают двоиться.
	registry.place(BuildingDefs.STORAGE, Vector2i(10, 10))
	registry.place(BuildingDefs.DRONE_PORT, Vector2i(20, 20))
	var pool := ResourcePool.new(registry)

	var before: int = registry.of_kind(BuildingDefs.Kind.STORAGE).size()
	for i: int in 5:
		pool.stores()
	check_eq(
		registry.of_kind(BuildingDefs.Kind.STORAGE).size(), before,
		"кеш складов испортился после обращений к общему хранилищу"
	)
	check_eq(pool.stores().size(), 2, "склад и порт — два хранилища, сколько ни спрашивай")


func test_pool_counts_each_store_once() -> void:
	var storage: Building = registry.place(BuildingDefs.STORAGE, Vector2i(10, 10))
	storage.output.add(Items.IRON_PLATE, 10)
	var pool := ResourcePool.new(registry)
	for i: int in 4:
		check_eq(pool.count(Items.IRON_PLATE), 10, "количество не должно расти от повторных запросов")
