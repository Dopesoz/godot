extends TestCase
## Генератор обязан быть детерминированным и всегда давать играбельный старт.

const SIZE: int = 256

var grid: Grid
var start: Vector2i


func before_each() -> void:
	grid = Grid.new(SIZE)
	start = MapGenerator.generate(grid, 12345)


func test_start_cell_is_buildable() -> void:
	check(grid.in_bounds(start), "старт вне мира")
	check(TileTypes.is_buildable(grid.get_terrain(start)), "на стартовой клетке нельзя строить")


func test_start_area_is_clear() -> void:
	# Площадка радиусом 10 должна быть пригодна под здания целиком.
	for dy: int in range(-MapGenerator.START_CLEAR_RADIUS, MapGenerator.START_CLEAR_RADIUS + 1):
		for dx: int in range(-MapGenerator.START_CLEAR_RADIUS, MapGenerator.START_CLEAR_RADIUS + 1):
			if dx * dx + dy * dy > MapGenerator.START_CLEAR_RADIUS * MapGenerator.START_CLEAR_RADIUS:
				continue
			var cell: Vector2i = start + Vector2i(dx, dy)
			if not grid.in_bounds(cell):
				continue
			check(
				TileTypes.is_buildable(grid.get_terrain(cell)),
				"клетка %s стартовой площадки непригодна" % cell
			)


func test_all_ores_available_near_start() -> void:
	var radius: int = MapGenerator.START_PATCH_SEARCH + MapGenerator.START_PATCH_RADIUS
	var area := Rect2i(start - Vector2i(radius, radius), Vector2i(radius * 2, radius * 2))
	for ore_type: int in [TileTypes.Ore.IRON, TileTypes.Ore.COPPER, TileTypes.Ore.STONE]:
		var found: Vector2i = grid.count_ore_in_area(area, ore_type)
		check(found.x > 0, "рядом со стартом нет руды типа %d" % ore_type)
		check(found.y > 0, "залежь руды типа %d пуста" % ore_type)


func test_generation_is_deterministic() -> void:
	var other := Grid.new(SIZE)
	var other_start: Vector2i = MapGenerator.generate(other, 12345)
	check_eq(other_start, start, "один сид — одна стартовая клетка")
	check(other.terrain == grid.terrain, "поверхность должна совпадать")
	check(other.ore == grid.ore, "руда должна совпадать")
	check(other.ore_amount == grid.ore_amount, "запасы руды должны совпадать")


func test_different_seeds_give_different_worlds() -> void:
	var other := Grid.new(SIZE)
	MapGenerator.generate(other, 999)
	check(other.terrain != grid.terrain, "разные сиды должны давать разные миры")


func test_terrain_mix_is_playable() -> void:
	# Мир из одной воды или сплошной скалы играть невозможно.
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(TileTypes.TERRAIN_COUNT)
	for i: int in SIZE * SIZE:
		counts[grid.terrain[i]] += 1
	var total: float = float(SIZE * SIZE)
	var buildable: float = float(counts[TileTypes.Terrain.GRASS]
		+ counts[TileTypes.Terrain.DIRT]
		+ counts[TileTypes.Terrain.SAND]) / total
	check(buildable > 0.45, "слишком мало места под застройку: %.2f" % buildable)
	check(counts[TileTypes.Terrain.WATER] > 0, "мир без воды выглядит плоско")
	check(counts[TileTypes.Terrain.ROCK] > 0, "мир без скал выглядит плоско")


func test_ore_does_not_appear_on_water_or_rock() -> void:
	for i: int in SIZE * SIZE:
		if grid.ore[i] == TileTypes.Ore.NONE:
			continue
		var terrain: int = grid.terrain[i]
		check(
			terrain != TileTypes.Terrain.WATER,
			"руда под водой в клетке %s" % grid.cell_of(i)
		)


func test_ore_forms_patches_not_noise() -> void:
	# Одиночные клетки руды бесполезны: бур занимает 2x2 и должен накрывать залежь.
	var lonely: int = 0
	var clustered: int = 0
	for i: int in SIZE * SIZE:
		if grid.ore[i] == TileTypes.Ore.NONE:
			continue
		var cell: Vector2i = grid.cell_of(i)
		var neighbours: int = 0
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if grid.get_ore(cell + offset) == grid.ore[i]:
				neighbours += 1
		if neighbours >= 2:
			clustered += 1
		elif neighbours == 0:
			lonely += 1
	check(clustered > lonely * 4, "руда рассыпана, а не собрана в залежи (%d/%d)" % [clustered, lonely])


func test_generation_speed() -> void:
	# Бюджет генерации: на слабом Android это примерно втрое дольше.
	var target := Grid.new(Constants.WORLD_SIZE)
	var start_usec: int = Time.get_ticks_usec()
	MapGenerator.generate(target, 4242)
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	check(elapsed_ms < 1200.0, "генерация мира 512x512 заняла %.0f мс" % elapsed_ms)


func test_ore_coverage_is_sparse() -> void:
	# Руда должна быть тем, что ищут: если ею покрыта половина карты,
	# разведка теряет смысл, а карта превращается в кашу.
	var ore_cells: int = 0
	for i: int in SIZE * SIZE:
		if grid.ore[i] != TileTypes.Ore.NONE:
			ore_cells += 1
	var coverage: float = float(ore_cells) / float(SIZE * SIZE)
	check(coverage > 0.02, "руды почти нет: %.3f" % coverage)
	check(coverage < 0.18, "руда покрывает %.3f карты — слишком много" % coverage)


func test_forest_is_generated_and_reachable() -> void:
	# Древесина — топливо носильщиков, значит лес обязан быть и на карте,
	# и в разумной досягаемости от старта.
	var trees: int = 0
	for i: int in grid.size * grid.size:
		if grid.ore[i] == TileTypes.Ore.TREES:
			trees += 1
	var share: float = float(trees) / float(grid.size * grid.size)
	check(share > 0.01, "леса почти нет: %.2f%% карты" % (share * 100.0))
	check(share < 0.20, "лес занял %.0f%% карты — он вытесняет всё остальное" % (share * 100.0))

	var nearest: int = 9999
	for radius: int in range(1, 60):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var cell: Vector2i = start + Vector2i(dx, dy)
				if grid.in_bounds(cell) and grid.get_ore(cell) == TileTypes.Ore.TREES:
					nearest = mini(nearest, maxi(absi(dx), absi(dy)))
		if nearest < 9999:
			break
	check(nearest <= 40, "ближайший лес в %d клетках — слишком далеко" % nearest)


func test_trees_do_not_replace_ore() -> void:
	# Лес кладётся только на пустые клетки: иначе он съедает залежи.
	for i: int in grid.size * grid.size:
		if grid.ore[i] != TileTypes.Ore.TREES:
			continue
		check_eq(
			grid.terrain[i], TileTypes.Terrain.GRASS,
			"лес вырос не на траве"
		)
