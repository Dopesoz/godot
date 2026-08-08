class_name MapGenerator
extends RefCounted

## Генерация мира из одного сида.
##
## Ключевое решение по производительности: шум считается не поэлементно из
## GDScript, а целыми картами через Noise.get_image() — это C++ и потоки.
## Затем идёт ОДИН проход по байтам. Поэлементный get_noise_2d() на 262144
## клетки × 5 слоёв — это миллион вызовов из скрипта и секунды ожидания на
## телефоне; здесь же весь мир собирается за десятки миллисекунд.

## --- Пороги рельефа (значения шума 0..255 из карты L8) ---------------------

const WATER_LEVEL: int = 78
const SAND_LEVEL: int = 92
const ROCK_LEVEL: int = 186
## Ниже этого значения влажности — земля, выше — трава.
const DIRT_MOISTURE: int = 118

## --- Руда ------------------------------------------------------------------

## Порог шума, выше которого в клетке появляется руда. Значение подобрано так,
## чтобы руда лежала отдельными залежами примерно на десятой части карты:
## при более низком пороге руда покрывает половину мира и перестаёт быть
## тем, что нужно искать.
const ORE_THRESHOLD: int = 205
## Уран — редкость поздней игры: порог выше, залежи мельче и разбросаны дальше.
const URANIUM_THRESHOLD: int = 222
## Порог леса ниже рудного: рощи должны быть заметной частью пейзажа,
## а не редкой находкой — древесина нужна носильщикам постоянно.
const TREE_THRESHOLD: int = 190
const TREE_AMOUNT_MIN: int = 200
const TREE_AMOUNT_MAX: int = 900

const ORE_AMOUNT_MIN: int = 120
const ORE_AMOUNT_MAX: int = 2400

## Радиус гарантированно ровной площадки вокруг точки старта.
const START_CLEAR_RADIUS: int = 10
## Куда докладываются стартовые залежи, если их не сгенерировал шум.
const START_PATCH_OFFSETS: Dictionary[int, Vector2i] = {
	TileTypes.Ore.IRON: Vector2i(-14, -6),
	TileTypes.Ore.COPPER: Vector2i(13, -8),
	TileTypes.Ore.STONE: Vector2i(2, 15),
	TileTypes.Ore.COAL: Vector2i(-12, 12),
	TileTypes.Ore.TREES: Vector2i(11, 11),
}
const START_PATCH_RADIUS: int = 4
const START_PATCH_AMOUNT: int = 900
## В каком радиусе от старта ищем уже сгенерированную залежь, прежде чем добавлять свою.
const START_PATCH_SEARCH: int = 26


## Заполняет сетку миром по сиду. Возвращает клетку, с которой начинает игрок.
static func generate(grid: Grid, seed_value: int) -> Vector2i:
	var start_usec: int = Time.get_ticks_usec()
	var size: int = grid.size

	var elevation: PackedByteArray = _noise_map(size, seed_value, 0.0055, 4)
	var moisture: PackedByteArray = _noise_map(size, seed_value + 7717, 0.011, 2)
	# Каждая руда — свой слой шума со своим порогом. Уран режется жёстче,
	# поэтому его залежи редкие и далеко от старта.
	var ore_layers: Array[Dictionary] = [
		{"ore": TileTypes.Ore.IRON, "map": _noise_map(size, seed_value + 1301, 0.055, 2),
			"threshold": ORE_THRESHOLD},
		{"ore": TileTypes.Ore.COPPER, "map": _noise_map(size, seed_value + 2609, 0.055, 2),
			"threshold": ORE_THRESHOLD},
		{"ore": TileTypes.Ore.STONE, "map": _noise_map(size, seed_value + 3907, 0.048, 2),
			"threshold": ORE_THRESHOLD},
		{"ore": TileTypes.Ore.COAL, "map": _noise_map(size, seed_value + 5119, 0.05, 2),
			"threshold": ORE_THRESHOLD},
		{"ore": TileTypes.Ore.URANIUM, "map": _noise_map(size, seed_value + 6221, 0.07, 2),
			"threshold": URANIUM_THRESHOLD},
	]

	_fill_terrain(grid, elevation, moisture)
	_fill_ore(grid, ore_layers)
	# Лес кладётся последним и только на пустые клетки: древесина не должна
	# отнимать место у руды, иначе на карте станет тесно именно там, где
	# игрок и строит фабрику.
	_fill_trees(grid, _noise_map(size, seed_value + 8419, 0.06, 2))

	var start: Vector2i = _prepare_start_area(grid, seed_value)

	Log.info("MapGenerator: мир %dx%d, сид %d, за %.1f мс" % [
		size, size, seed_value, float(Time.get_ticks_usec() - start_usec) / 1000.0,
	])
	return start


## Карта шума размером size×size в виде байтов 0..255.
static func _noise_map(size: int, seed_value: int, frequency: float, octaves: int) -> PackedByteArray:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	# normalize=true приводит значения к 0..1, поэтому L8 использует весь диапазон.
	var image: Image = noise.get_image(size, size, false, false, true)
	return image.get_data()


static func _fill_terrain(grid: Grid, elevation: PackedByteArray, moisture: PackedByteArray) -> void:
	var count: int = grid.size * grid.size
	var terrain: PackedByteArray = grid.terrain
	for i: int in count:
		var e: int = elevation[i]
		var t: int
		if e < WATER_LEVEL:
			t = TileTypes.Terrain.WATER
		elif e < SAND_LEVEL:
			t = TileTypes.Terrain.SAND
		elif e > ROCK_LEVEL:
			t = TileTypes.Terrain.ROCK
		elif moisture[i] < DIRT_MOISTURE:
			t = TileTypes.Terrain.DIRT
		else:
			t = TileTypes.Terrain.GRASS
		terrain[i] = t
	grid.terrain = terrain


## Слои руды сводятся в один результат.
##
## Проход идёт по слоям снаружи и по клеткам внутри, а не наоборот: обращение
## к словарю слоя внутри цикла по четверти миллиона клеток стоило втрое дороже
## самой генерации шума. Здесь словарь читается пять раз за всю функцию.
static func _fill_ore(grid: Grid, layers: Array[Dictionary]) -> void:
	var count: int = grid.size * grid.size
	var terrain: PackedByteArray = grid.terrain
	var ore: PackedByteArray = grid.ore
	var amount: PackedInt32Array = grid.ore_amount
	var span: float = float(ORE_AMOUNT_MAX - ORE_AMOUNT_MIN)

	# Лучшее «превышение порога» по каждой клетке: пороги у руд разные,
	# поэтому сравнивать сырые значения шума нельзя.
	var best_richness := PackedFloat32Array()
	best_richness.resize(count)
	var best_type := PackedByteArray()
	best_type.resize(count)

	for layer: Dictionary in layers:
		var noise_map: PackedByteArray = layer["map"]
		var threshold: int = layer["threshold"]
		var ore_type: int = layer["ore"]
		var inverse_span: float = 1.0 / float(255 - threshold)
		for i: int in count:
			var value: int = noise_map[i]
			if value <= threshold:
				continue
			var richness: float = float(value - threshold) * inverse_span
			if richness > best_richness[i]:
				best_richness[i] = richness
				best_type[i] = ore_type

	for i: int in count:
		if best_type[i] == TileTypes.Ore.NONE:
			continue
		# Под водой руду не добыть, в скале руды нет — экономим и память, и логику.
		if terrain[i] == TileTypes.Terrain.WATER or terrain[i] == TileTypes.Terrain.ROCK:
			continue
		var richness: float = best_richness[i]
		ore[i] = best_type[i]
		amount[i] = ORE_AMOUNT_MIN + int(richness * richness * span)
	grid.ore = ore
	grid.ore_amount = amount


## Лес: рощи на траве там, где не легла руда.
static func _fill_trees(grid: Grid, tree_map: PackedByteArray) -> void:
	var count: int = grid.size * grid.size
	var terrain: PackedByteArray = grid.terrain
	var ore: PackedByteArray = grid.ore
	var amount: PackedInt32Array = grid.ore_amount
	var inverse_span: float = 1.0 / float(255 - TREE_THRESHOLD)
	var span: float = float(TREE_AMOUNT_MAX - TREE_AMOUNT_MIN)

	for i: int in count:
		if ore[i] != TileTypes.Ore.NONE:
			continue
		if terrain[i] != TileTypes.Terrain.GRASS:
			continue
		var value: int = tree_map[i]
		if value <= TREE_THRESHOLD:
			continue
		var density: float = float(value - TREE_THRESHOLD) * inverse_span
		ore[i] = TileTypes.Ore.TREES
		amount[i] = TREE_AMOUNT_MIN + int(density * span)
	grid.ore = ore
	grid.ore_amount = amount


## Готовит площадку старта: ровный грунт и гарантированный доступ ко всем трём рудам.
## Без этого игрок с шансом в несколько процентов появляется среди воды и скал.
static func _prepare_start_area(grid: Grid, seed_value: int) -> Vector2i:
	var start: Vector2i = _find_start_cell(grid, seed_value)

	for dy: int in range(-START_CLEAR_RADIUS, START_CLEAR_RADIUS + 1):
		for dx: int in range(-START_CLEAR_RADIUS, START_CLEAR_RADIUS + 1):
			if dx * dx + dy * dy > START_CLEAR_RADIUS * START_CLEAR_RADIUS:
				continue
			var cell: Vector2i = start + Vector2i(dx, dy)
			if not grid.in_bounds(cell):
				continue
			if not TileTypes.is_buildable(grid.get_terrain(cell)):
				grid.set_terrain(cell, TileTypes.Terrain.GRASS)
			# Под самой базой руда мешает: место нужно под здания.
			if dx * dx + dy * dy <= 16:
				grid.set_ore(cell, TileTypes.Ore.NONE, 0)

	for ore_type: int in START_PATCH_OFFSETS:
		if _has_ore_near(grid, start, ore_type, START_PATCH_SEARCH):
			continue
		_stamp_ore_patch(grid, start + START_PATCH_OFFSETS[ore_type], ore_type, seed_value)

	return start


## Ищет пригодную стартовую клетку по спирали от центра мира.
static func _find_start_cell(grid: Grid, seed_value: int) -> Vector2i:
	var center := Vector2i(grid.size / 2, grid.size / 2)
	var offset: int = Rng.range_int(seed_value, 0, 55, -24, 24)
	center += Vector2i(offset, Rng.range_int(0, seed_value, 55, -24, 24))
	for radius: int in range(0, grid.size / 2):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				# Проверяем только новую «рамку» на каждом радиусе.
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var cell: Vector2i = center + Vector2i(dx, dy)
				if grid.in_bounds(cell) and TileTypes.is_buildable(grid.get_terrain(cell)):
					return cell
	return center


static func _has_ore_near(grid: Grid, center: Vector2i, ore_type: int, radius: int) -> bool:
	var area := Rect2i(center - Vector2i(radius, radius), Vector2i(radius * 2, radius * 2))
	return grid.count_ore_in_area(area, ore_type).x > 0


static func _stamp_ore_patch(grid: Grid, center: Vector2i, ore_type: int, seed_value: int) -> void:
	for dy: int in range(-START_PATCH_RADIUS, START_PATCH_RADIUS + 1):
		for dx: int in range(-START_PATCH_RADIUS, START_PATCH_RADIUS + 1):
			var cell: Vector2i = center + Vector2i(dx, dy)
			if not grid.in_bounds(cell):
				continue
			var distance: float = sqrt(float(dx * dx + dy * dy))
			var wobble: float = 0.7 + Rng.value01(cell.x, cell.y, seed_value + ore_type) * 0.55
			if distance > float(START_PATCH_RADIUS) * wobble:
				continue
			if not TileTypes.is_buildable(grid.get_terrain(cell)):
				grid.set_terrain(cell, TileTypes.Terrain.DIRT)
			var falloff: float = 1.0 - distance / float(START_PATCH_RADIUS + 1)
			grid.set_ore(cell, ore_type, maxi(ORE_AMOUNT_MIN, int(START_PATCH_AMOUNT * falloff)))
