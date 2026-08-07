extends TestCase
## Потоковая подгрузка чанков: главный механизм, удерживающий кадр независимым
## от размера мира.

var world: GameWorld = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(2024)


func after_each() -> void:
	if is_instance_valid(world):
		world.free()
	world = null


func test_tileset_covers_all_tiles() -> void:
	var tileset: TileSet = world.terrain_renderer.ground_layer.tile_set
	var source: TileSetAtlasSource = tileset.get_source(TilesetFactory.TERRAIN_SOURCE_ID)
	var expected: Vector2i = TerrainArt.atlas_size_in_tiles()
	check_eq(source.get_tiles_count(), expected.x * expected.y, "в TileSet не все тайлы атласа")


func test_only_visible_chunks_are_loaded() -> void:
	var center: Vector2 = Grid.cell_to_world_center(world.start_cell)
	world.update_view(Rect2(center - Vector2(360, 640), Vector2(720, 1280)))
	world.terrain_renderer.flush_pending()

	var loaded: int = world.terrain_renderer.loaded_chunk_count()
	check(loaded > 0, "не загружено ни одного чанка")
	# Экран 720x1280 при масштабе 1 — это 45x80 клеток, около 3x5 чанков плюс запас.
	check(loaded < 60, "загружено слишком много чанков: %d" % loaded)
	check(
		loaded < Constants.WORLD_CHUNKS * Constants.WORLD_CHUNKS / 4,
		"потоковая подгрузка не работает"
	)


func test_chunks_unload_when_camera_moves_away() -> void:
	var near_start: Vector2 = Grid.cell_to_world_center(world.start_cell)
	world.update_view(Rect2(near_start, Vector2(720, 1280)))
	world.terrain_renderer.flush_pending()
	var first_count: int = world.terrain_renderer.loaded_chunk_count()

	var far: Vector2 = Grid.cell_to_world_center(Vector2i(20, 20))
	world.update_view(Rect2(far, Vector2(720, 1280)))
	world.terrain_renderer.flush_pending()

	check(
		world.terrain_renderer.loaded_chunk_count() <= first_count + 4,
		"старые чанки не выгружаются: их число только растёт"
	)
	check(
		world.terrain_renderer.ground_layer.get_cell_source_id(world.start_cell) == -1,
		"клетка вне поля зрения должна быть выгружена"
	)


func test_visible_cells_are_drawn() -> void:
	var center: Vector2 = Grid.cell_to_world_center(world.start_cell)
	world.update_view(Rect2(center - Vector2(200, 200), Vector2(400, 400)))
	world.terrain_renderer.flush_pending()

	var layer: TileMapLayer = world.terrain_renderer.ground_layer
	check_eq(
		layer.get_cell_source_id(world.start_cell),
		TilesetFactory.TERRAIN_SOURCE_ID,
		"стартовая клетка не отрисована"
	)
	var expected: Vector2i = Art.terrain_tile(
		world.grid.get_terrain(world.start_cell),
		Art.variant_for(world.start_cell)
	)
	check_eq(layer.get_cell_atlas_coords(world.start_cell), expected, "неверный тайл поверхности")


func test_ore_layer_follows_grid() -> void:
	# Ищем клетку с рудой рядом со стартом и проверяем, что она видна и исчезает
	# после выработки.
	var found := Vector2i(-1, -1)
	for dy: int in range(-30, 30):
		for dx: int in range(-30, 30):
			var cell: Vector2i = world.start_cell + Vector2i(dx, dy)
			if world.grid.get_ore(cell) != TileTypes.Ore.NONE:
				found = cell
				break
		if found.x >= 0:
			break
	check(found.x >= 0, "рядом со стартом не нашлось руды")
	if found.x < 0:
		return

	var center: Vector2 = Grid.cell_to_world_center(found)
	world.update_view(Rect2(center - Vector2(200, 200), Vector2(400, 400)))
	world.terrain_renderer.flush_pending()
	check_ne(
		world.terrain_renderer.ore_layer.get_cell_source_id(found), -1,
		"руда не отрисована"
	)

	world.grid.extract_ore(found, world.grid.get_ore_amount(found))
	check_eq(
		world.terrain_renderer.ore_layer.get_cell_source_id(found), -1,
		"выработанная руда должна исчезать со слоя"
	)


func test_chunk_loading_is_budgeted_per_frame() -> void:
	var center: Vector2 = Grid.cell_to_world_center(world.start_cell)
	world.update_view(Rect2(center - Vector2(720, 1280), Vector2(1440, 2560)))
	var pending: int = world.terrain_renderer.pending_chunk_count()
	check(pending > TerrainRenderer.MAX_CHUNK_LOADS_PER_FRAME, "мало чанков для проверки бюджета")

	world.terrain_renderer._process(0.016)
	check_eq(
		world.terrain_renderer.loaded_chunk_count(),
		TerrainRenderer.MAX_CHUNK_LOADS_PER_FRAME,
		"за кадр должно грузиться не больше бюджета"
	)


func test_chunk_load_time_budget() -> void:
	var center: Vector2 = Grid.cell_to_world_center(world.start_cell)
	world.update_view(Rect2(center - Vector2(360, 640), Vector2(720, 1280)))
	var start_usec: int = Time.get_ticks_usec()
	world.terrain_renderer.flush_pending()
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	var chunks: int = world.terrain_renderer.loaded_chunk_count()
	var per_chunk: float = elapsed_ms / maxf(float(chunks), 1.0)
	# Бюджет кадра 16 мс; два чанка за кадр должны укладываться в его малую часть.
	check(per_chunk < 3.0, "чанк грузится %.2f мс — слишком дорого" % per_chunk)
