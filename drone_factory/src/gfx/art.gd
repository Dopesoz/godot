class_name Art
extends RefCounted

## Реестр сгенерированной графики. Строится один раз при старте и живёт до выхода.
##
## Почему процедурно, а не файлами: APK остаётся крошечным, нет этапа импорта
## текстур, палитра меняется в одном месте, и на слабом Android вся графика
## умещается в пару небольших атласов — это минимум переключений текстур.

static var terrain_texture: ImageTexture = null

static var _built: bool = false


## Идемпотентно: повторные вызовы бесплатны.
static func build() -> void:
	if _built:
		return
	var start_usec: int = Time.get_ticks_usec()

	var tiles: Vector2i = TerrainArt.atlas_size_in_tiles()
	var canvas := PixelCanvas.new(tiles.x * Constants.TILE_SIZE, tiles.y * Constants.TILE_SIZE)
	TerrainArt.draw_all(canvas)
	terrain_texture = canvas.to_texture()

	_built = true
	Log.info("Art: атлас поверхности %dx%d px за %.1f мс" % [
		terrain_texture.get_width(),
		terrain_texture.get_height(),
		float(Time.get_ticks_usec() - start_usec) / 1000.0,
	])


static func is_built() -> bool:
	return _built


## Координаты тайла поверхности в атласе.
static func terrain_tile(terrain: int, variant: int) -> Vector2i:
	return Vector2i(variant % TileTypes.VARIANTS, terrain)


## Координаты рудного наложения в атласе.
static func ore_tile(ore: int, variant: int) -> Vector2i:
	return Vector2i(variant % TileTypes.VARIANTS, TileTypes.TERRAIN_COUNT + ore)


## Вариант тайла для клетки: стабилен между запусками и не требует хранения.
static func variant_for(cell: Vector2i, salt: int = 0) -> int:
	return Rng.hash2i(cell.x, cell.y, TerrainArt.ART_SEED + salt) % TileTypes.VARIANTS
