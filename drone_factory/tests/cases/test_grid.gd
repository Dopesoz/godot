extends TestCase
## Сетка — фундамент мира: ошибки здесь ломают всё остальное.

var grid: Grid


func before_each() -> void:
	grid = Grid.new(32)


func test_bounds() -> void:
	check(grid.in_bounds(Vector2i(0, 0)))
	check(grid.in_bounds(Vector2i(31, 31)))
	check(not grid.in_bounds(Vector2i(-1, 0)))
	check(not grid.in_bounds(Vector2i(0, 32)))


func test_index_round_trip() -> void:
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(5, 7), Vector2i(31, 31)]:
		check_eq(grid.cell_of(grid.index_of(cell)), cell)


func test_out_of_bounds_access_is_safe() -> void:
	# Вода и пустота вместо ошибок: край мира ведёт себя как непроходимая клетка.
	check_eq(grid.get_terrain(Vector2i(-5, 0)), TileTypes.Terrain.WATER)
	check_eq(grid.get_ore(Vector2i(100, 100)), TileTypes.Ore.NONE)
	check_eq(grid.get_building(Vector2i(-1, -1)), Grid.NO_BUILDING)
	grid.set_terrain(Vector2i(999, 999), TileTypes.Terrain.SAND)


func test_world_coordinate_conversion() -> void:
	check_eq(Grid.cell_to_world(Vector2i(2, 3)), Vector2(32, 48))
	check_eq(Grid.cell_to_world_center(Vector2i(0, 0)), Vector2(8, 8))
	check_eq(Grid.world_to_cell(Vector2(0, 0)), Vector2i(0, 0))
	check_eq(Grid.world_to_cell(Vector2(15.9, 16.1)), Vector2i(0, 1))
	# Отрицательные координаты обязаны округляться вниз, а не к нулю.
	check_eq(Grid.world_to_cell(Vector2(-1, -1)), Vector2i(-1, -1))
	check_eq(Grid.area_center(Rect2i(2, 2, 2, 2)), Vector2(48, 48))


func test_ore_extraction() -> void:
	var cell := Vector2i(4, 4)
	grid.set_ore(cell, TileTypes.Ore.IRON, 10)
	check_eq(grid.get_ore(cell), TileTypes.Ore.IRON)
	check_eq(grid.extract_ore(cell, 4), 4)
	check_eq(grid.get_ore_amount(cell), 6)
	check_eq(grid.extract_ore(cell, 100), 6, "нельзя добыть больше, чем осталось")
	check_eq(grid.get_ore(cell), TileTypes.Ore.NONE, "выработанная клетка теряет тип руды")
	check_eq(grid.extract_ore(cell, 1), 0)


func test_area_buildability() -> void:
	check(grid.is_area_buildable(Rect2i(1, 1, 2, 2)))
	check(not grid.is_area_buildable(Rect2i(31, 31, 2, 2)), "область не должна выходить за край")
	check(not grid.is_area_buildable(Rect2i(1, 1, 0, 2)), "нулевой размер недопустим")

	grid.set_terrain(Vector2i(2, 2), TileTypes.Terrain.WATER)
	check(not grid.is_area_buildable(Rect2i(1, 1, 2, 2)), "на воде строить нельзя")

	grid.set_terrain(Vector2i(2, 2), TileTypes.Terrain.GRASS)
	grid.fill_area_building(Rect2i(2, 2, 1, 1), 7)
	check(not grid.is_area_buildable(Rect2i(1, 1, 2, 2)), "занятая клетка блокирует постройку")
	check_eq(grid.get_building(Vector2i(2, 2)), 7)

	grid.fill_area_building(Rect2i(2, 2, 1, 1), Grid.NO_BUILDING)
	check(grid.is_area_buildable(Rect2i(1, 1, 2, 2)), "после сноса область снова свободна")


func test_ore_queries_in_area() -> void:
	grid.set_ore(Vector2i(5, 5), TileTypes.Ore.IRON, 100)
	grid.set_ore(Vector2i(6, 5), TileTypes.Ore.IRON, 50)
	grid.set_ore(Vector2i(5, 6), TileTypes.Ore.COPPER, 200)

	check_eq(grid.count_ore_in_area(Rect2i(5, 5, 2, 2), TileTypes.Ore.IRON), Vector2i(2, 150))
	# Медь по запасу больше, значит бур на этой площадке добывал бы её.
	check_eq(grid.dominant_ore_in_area(Rect2i(5, 5, 2, 2)), Vector2i(TileTypes.Ore.COPPER, 200))
	check_eq(grid.dominant_ore_in_area(Rect2i(0, 0, 2, 2)), Vector2i(TileTypes.Ore.NONE, 0))


func test_area_queries_clamp_to_world() -> void:
	grid.set_ore(Vector2i(0, 0), TileTypes.Ore.STONE, 5)
	check_eq(grid.dominant_ore_in_area(Rect2i(-2, -2, 4, 4)), Vector2i(TileTypes.Ore.STONE, 5))


func test_serialization_round_trip() -> void:
	grid.set_terrain(Vector2i(3, 3), TileTypes.Terrain.SAND)
	grid.set_terrain(Vector2i(9, 1), TileTypes.Terrain.ROCK)
	grid.set_ore(Vector2i(3, 3), TileTypes.Ore.COPPER, 1234)
	var data: Dictionary = grid.serialize_layers()

	var restored := Grid.new(32)
	check(restored.deserialize_layers(data), "загрузка должна пройти успешно")
	check_eq(restored.get_terrain(Vector2i(3, 3)), TileTypes.Terrain.SAND)
	check_eq(restored.get_terrain(Vector2i(9, 1)), TileTypes.Terrain.ROCK)
	check_eq(restored.get_ore(Vector2i(3, 3)), TileTypes.Ore.COPPER)
	check_eq(restored.get_ore_amount(Vector2i(3, 3)), 1234)


func test_serialization_rejects_size_mismatch() -> void:
	var data: Dictionary = grid.serialize_layers()
	var other := Grid.new(16)
	check(not other.deserialize_layers(data), "несовпадение размера мира должно отклоняться")


func test_serialized_blob_is_compact() -> void:
	# Мир целиком обязан укладываться в разумный размер файла на телефоне.
	var full := Grid.new(Constants.WORLD_SIZE)
	var data: Dictionary = full.serialize_layers()
	var base64_size: int = String(data["blob"]).length()
	check(base64_size < 400_000, "блоб мира слишком большой: %d байт" % base64_size)
