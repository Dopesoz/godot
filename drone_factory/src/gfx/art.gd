class_name Art
extends RefCounted

## Реестр сгенерированной графики. Строится один раз при старте и живёт до выхода.
##
## Почему процедурно, а не файлами: APK остаётся крошечным, нет этапа импорта
## текстур, палитра меняется в одном месте, и на слабом Android вся графика
## умещается в пару небольших атласов — это минимум переключений текстур.

## Ширина атласа объектов. Степень двойки — требование части мобильных GPU
## к эффективной выборке текстур.
const OBJECT_ATLAS_WIDTH: int = 256
## Прозрачный зазор между спрайтами: без него при билинейной фильтрации и
## масштабировании соседний спрайт «подтекает» по краю.
const ATLAS_PADDING: int = 1

static var terrain_texture: ImageTexture = null
static var object_texture: ImageTexture = null

static var _built: bool = false
static var _regions: Dictionary[StringName, Rect2i] = {}
static var _icons: Dictionary[StringName, AtlasTexture] = {}


## Идемпотентно: повторные вызовы бесплатны.
static func build() -> void:
	if _built:
		return
	var start_usec: int = Time.get_ticks_usec()

	var tiles: Vector2i = TerrainArt.atlas_size_in_tiles()
	var canvas := PixelCanvas.new(tiles.x * Constants.TILE_SIZE, tiles.y * Constants.TILE_SIZE)
	TerrainArt.draw_all(canvas)
	terrain_texture = canvas.to_texture()

	_build_object_atlas()

	_built = true
	Log.info("Art: атласы %dx%d и %dx%d px, %d спрайтов, за %.1f мс" % [
		terrain_texture.get_width(), terrain_texture.get_height(),
		object_texture.get_width(), object_texture.get_height(),
		_regions.size(),
		float(Time.get_ticks_usec() - start_usec) / 1000.0,
	])


## Полочная упаковка: спрайты кладутся рядами сверху вниз, ряд закрывается,
## когда очередной спрайт не помещается по ширине. Для нескольких десятков
## спрайтов этого достаточно, а код остаётся понятным.
static func _build_object_atlas() -> void:
	var sprites: Dictionary[StringName, PixelCanvas] = ObjectArt.draw_all()

	var keys: Array[StringName] = []
	for key: StringName in sprites:
		keys.append(key)
	# Высокие спрайты первыми — меньше пустот в рядах.
	keys.sort_custom(func(a: StringName, b: StringName) -> bool:
		return sprites[a].height > sprites[b].height
	)

	_regions.clear()
	var pen := Vector2i(ATLAS_PADDING, ATLAS_PADDING)
	var row_height: int = 0
	for key: StringName in keys:
		var sprite: PixelCanvas = sprites[key]
		if pen.x + sprite.width + ATLAS_PADDING > OBJECT_ATLAS_WIDTH:
			pen = Vector2i(ATLAS_PADDING, pen.y + row_height + ATLAS_PADDING)
			row_height = 0
		_regions[key] = Rect2i(pen, Vector2i(sprite.width, sprite.height))
		pen.x += sprite.width + ATLAS_PADDING
		row_height = maxi(row_height, sprite.height)

	var atlas := PixelCanvas.new(OBJECT_ATLAS_WIDTH, pen.y + row_height + ATLAS_PADDING)
	for key: StringName in _regions:
		var sprite: PixelCanvas = sprites[key]
		var region: Rect2i = _regions[key]
		atlas.image.blit_rect(sprite.image, Rect2i(Vector2i.ZERO, region.size), region.position)
	object_texture = atlas.to_texture()
	_icons.clear()


## Область спрайта в атласе объектов.
static func region(key: StringName) -> Rect2i:
	return _regions.get(key, Rect2i())


static func has_sprite(key: StringName) -> bool:
	return _regions.has(key)


## Готовая текстура для интерфейса (кнопки строительства, списки предметов).
## Кешируется: AtlasTexture создаётся один раз на ключ.
static func icon(key: StringName) -> AtlasTexture:
	build()
	if _icons.has(key):
		return _icons[key]
	var texture := AtlasTexture.new()
	texture.atlas = object_texture
	texture.region = Rect2(region(key))
	texture.filter_clip = true
	_icons[key] = texture
	return texture


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
