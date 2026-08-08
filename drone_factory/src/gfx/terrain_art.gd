class_name TerrainArt
extends RefCounted

## Рисование тайлов поверхности и рудных наложений в общий атлас.
##
## Раскладка атласа: столбец — вариант тайла, строка — вид поверхности,
## далее строки рудных наложений (рисуются поверх поверхности отдельным слоем).

const TILE: int = Constants.TILE_SIZE
const ART_SEED: int = 0x5EED


## Возвращает размер атласа в клетках: (варианты, поверхности + руды).
static func atlas_size_in_tiles() -> Vector2i:
	return Vector2i(TileTypes.VARIANTS, TileTypes.TERRAIN_COUNT + TileTypes.ORE_COUNT)


static func draw_all(canvas: PixelCanvas) -> void:
	for terrain: int in TileTypes.TERRAIN_COUNT:
		for variant: int in TileTypes.VARIANTS:
			_draw_terrain(canvas, terrain, variant, variant * TILE, terrain * TILE)
	var ore_row_offset: int = TileTypes.TERRAIN_COUNT
	for ore: int in TileTypes.ORE_COUNT:
		for variant: int in TileTypes.VARIANTS:
			_draw_ore(canvas, ore, variant, variant * TILE, (ore_row_offset + ore) * TILE)


static func _draw_terrain(canvas: PixelCanvas, terrain: int, variant: int, ox: int, oy: int) -> void:
	var base: Color
	var dark: Color
	var light: Color
	match terrain:
		TileTypes.Terrain.GRASS:
			base = Palette.GRASS
			dark = Palette.GRASS_DARK
			light = Palette.GRASS_LIGHT
		TileTypes.Terrain.DIRT:
			base = Palette.DIRT
			dark = Palette.DIRT_DARK
			light = Palette.DIRT_LIGHT
		TileTypes.Terrain.SAND:
			base = Palette.SAND
			dark = Palette.SAND_DARK
			light = Palette.SAND_LIGHT
		TileTypes.Terrain.ROCK:
			base = Palette.ROCK
			dark = Palette.ROCK_DARK
			light = Palette.ROCK_LIGHT
		_:
			base = Palette.WATER
			dark = Palette.WATER_DARK
			light = Palette.WATER_LIGHT

	canvas.rect(ox, oy, TILE, TILE, base)
	var seed_value: int = ART_SEED + terrain * 131 + variant * 17
	canvas.speckle(ox, oy, TILE, TILE, dark, 0.10, seed_value)
	canvas.speckle(ox, oy, TILE, TILE, light, 0.08, seed_value + 1)

	match terrain:
		TileTypes.Terrain.GRASS:
			# Пучки травы: короткие вертикальные штрихи.
			for i: int in 3:
				var gx: int = ox + Rng.range_int(i, variant, seed_value + 2, 1, TILE - 2)
				var gy: int = oy + Rng.range_int(i, variant, seed_value + 3, 2, TILE - 4)
				canvas.vline(gx, gy, 2, Palette.GRASS_LIGHT)
				canvas.put(gx + 1, gy + 1, Palette.GRASS_DARK)
		TileTypes.Terrain.ROCK:
			# Крупные грани камня, чтобы скала читалась как непроходимая.
			canvas.rect(ox + 2, oy + 2, 6, 5, light)
			canvas.rect(ox + 9, oy + 7, 5, 6, dark)
			canvas.rect_outline(ox + 2, oy + 2, 6, 5, dark)
		TileTypes.Terrain.WATER:
			# Блики волн двумя рядами — анимации нет, чтобы не тратить кадры.
			canvas.hline(ox + 2 + variant, oy + 4, 4, light)
			canvas.hline(ox + 8 - variant, oy + 11, 3, light)
		_:
			pass


## Лес рисуется не самородками, а силуэтами деревьев: игрок должен отличать
## его от залежи с одного взгляда, не приближая камеру.
static func _draw_trees(canvas: PixelCanvas, variant: int, ox: int, oy: int) -> void:
	var seed_value: int = ART_SEED + 4441 + variant * 29
	# Два дерева на клетку, но крупных. Мелкая россыпь на траве не читается
	# вообще: зелёное на зелёном сливается, и залежь древесины не найти.
	for i: int in 2:
		var cx: int = ox + Rng.range_int(i, 7, seed_value, 7, TILE - 7)
		var cy: int = oy + Rng.range_int(i, 11, seed_value, 11, TILE - 5)
		# Ствол — коричневый, он и отделяет дерево от травы.
		canvas.rect(cx - 1, cy, 2, 5, Palette.DIRT_DARK)
		# Тень под кроной задаёт силуэт.
		canvas.blob(cx, cy - 4, 5.2, Palette.OUTLINE, seed_value + i)
		canvas.blob(cx, cy - 5, 4.4, Palette.TREE, seed_value + i * 7)
		# Блик сверху слева: без него крона выглядит плоским пятном.
		canvas.blob(cx - 1, cy - 7, 2.2, Palette.TREE_LIGHT, seed_value + i * 3)


static func _draw_ore(canvas: PixelCanvas, ore: int, variant: int, ox: int, oy: int) -> void:
	if ore == TileTypes.Ore.NONE:
		return
	var base: Color
	var light: Color
	match ore:
		TileTypes.Ore.STONE:
			base = Palette.STONE_ORE
			light = Palette.STONE_ORE_LIGHT
		TileTypes.Ore.IRON:
			base = Palette.IRON_ORE
			light = Palette.IRON_ORE_LIGHT
		TileTypes.Ore.COAL:
			base = Palette.COAL_ORE
			light = Palette.COAL_ORE_LIGHT
		TileTypes.Ore.URANIUM:
			base = Palette.URANIUM_ORE
			light = Palette.URANIUM_ORE_LIGHT
		TileTypes.Ore.TREES:
			_draw_trees(canvas, variant, ox, oy)
			return
		_:
			base = Palette.COPPER_ORE
			light = Palette.COPPER_ORE_LIGHT

	var seed_value: int = ART_SEED + 977 + ore * 71 + variant * 13
	# Три-четыре самородка на клетку: наложение прозрачное, земля видна между ними.
	var count: int = 3 + (variant % 2)
	for i: int in count:
		var cx: int = ox + Rng.range_int(i, ore, seed_value, 3, TILE - 4)
		var cy: int = oy + Rng.range_int(i, ore + 5, seed_value, 3, TILE - 4)
		var radius: float = 1.2 + Rng.value01(i, ore, seed_value + 2) * 1.4
		canvas.blob(cx, cy, radius, base, seed_value + i)
		canvas.put(cx, cy - 1, light)
