class_name TerrainRenderer
extends Node2D

## Потоковая отрисовка поверхности чанками.
##
## Мир — 262144 клетки; заливать их в TileMapLayer целиком нельзя: это сотни
## тысяч вызовов set_cell и десятки мегабайт. Вместо этого держим в слое только
## чанки вокруг камеры и выгружаем ушедшие за поле зрения. Стоимость кадра
## перестаёт зависеть от размера мира.

## Запас чанков за краем экрана: подгружаются заранее, чтобы не было «мигания».
const CHUNK_MARGIN: int = 1
## Сколько чанков разрешено подгрузить за один кадр. Ограничение размазывает
## работу по кадрам и не даёт просадки при быстром пролёте камерой.
const MAX_CHUNK_LOADS_PER_FRAME: int = 2

var ground_layer: TileMapLayer
var ore_layer: TileMapLayer

var _grid: Grid = null
## Загруженные чанки: ключ — координата чанка.
var _loaded: Dictionary[Vector2i, bool] = {}
var _pending: Array[Vector2i] = []
var _last_range := Rect2i(0, 0, 0, 0)


func _ready() -> void:
	var tileset: TileSet = TilesetFactory.build_terrain_tileset()

	ground_layer = TileMapLayer.new()
	ground_layer.name = "Ground"
	ground_layer.tile_set = tileset
	add_child(ground_layer)

	ore_layer = TileMapLayer.new()
	ore_layer.name = "Ore"
	ore_layer.tile_set = tileset
	ore_layer.z_index = 1
	add_child(ore_layer)

	Events.cell_changed.connect(_on_cell_changed)


func setup(grid: Grid) -> void:
	_grid = grid
	clear()


func clear() -> void:
	_loaded.clear()
	_pending.clear()
	_last_range = Rect2i(0, 0, 0, 0)
	if is_instance_valid(ground_layer):
		ground_layer.clear()
		ore_layer.clear()


## Держит загруженными чанки, пересекающие видимую область (в клетках).
func update_visible(visible_cells: Rect2i) -> void:
	if _grid == null:
		return
	var chunk_range: Rect2i = _chunk_range(visible_cells)
	if chunk_range == _last_range:
		return
	_last_range = chunk_range

	_pending.clear()
	for cy: int in range(chunk_range.position.y, chunk_range.position.y + chunk_range.size.y):
		for cx: int in range(chunk_range.position.x, chunk_range.position.x + chunk_range.size.x):
			var chunk := Vector2i(cx, cy)
			if not _loaded.has(chunk):
				_pending.append(chunk)

	for chunk: Vector2i in _loaded.keys():
		if not chunk_range.has_point(chunk):
			_unload_chunk(chunk)


func _process(_delta: float) -> void:
	var budget: int = MAX_CHUNK_LOADS_PER_FRAME
	while budget > 0 and not _pending.is_empty():
		_load_chunk(_pending.pop_back())
		budget -= 1


## Загружает все ожидающие чанки немедленно: нужно при старте и загрузке
## сохранения, где кадр всё равно не показывается.
func flush_pending() -> void:
	while not _pending.is_empty():
		_load_chunk(_pending.pop_back())


func loaded_chunk_count() -> int:
	return _loaded.size()


func pending_chunk_count() -> int:
	return _pending.size()


func _chunk_range(visible_cells: Rect2i) -> Rect2i:
	var chunks: int = Constants.WORLD_CHUNKS
	var from := Vector2i(
		floori(float(visible_cells.position.x) / Constants.CHUNK_SIZE) - CHUNK_MARGIN,
		floori(float(visible_cells.position.y) / Constants.CHUNK_SIZE) - CHUNK_MARGIN
	)
	var to := Vector2i(
		floori(float(visible_cells.position.x + visible_cells.size.x) / Constants.CHUNK_SIZE) + CHUNK_MARGIN,
		floori(float(visible_cells.position.y + visible_cells.size.y) / Constants.CHUNK_SIZE) + CHUNK_MARGIN
	)
	from = from.clampi(0, chunks - 1)
	to = to.clampi(0, chunks - 1)
	return Rect2i(from, to - from + Vector2i.ONE)


func _load_chunk(chunk: Vector2i) -> void:
	if _loaded.has(chunk) or _grid == null:
		return
	_loaded[chunk] = true
	var origin: Vector2i = chunk * Constants.CHUNK_SIZE
	for y: int in Constants.CHUNK_SIZE:
		for x: int in Constants.CHUNK_SIZE:
			_draw_cell(origin + Vector2i(x, y))


func _unload_chunk(chunk: Vector2i) -> void:
	_loaded.erase(chunk)
	var origin: Vector2i = chunk * Constants.CHUNK_SIZE
	for y: int in Constants.CHUNK_SIZE:
		for x: int in Constants.CHUNK_SIZE:
			var cell: Vector2i = origin + Vector2i(x, y)
			ground_layer.erase_cell(cell)
			ore_layer.erase_cell(cell)


func _draw_cell(cell: Vector2i) -> void:
	if not _grid.in_bounds(cell):
		return
	var index: int = _grid.index_of(cell)
	var variant: int = Art.variant_for(cell)
	ground_layer.set_cell(
		cell,
		TilesetFactory.TERRAIN_SOURCE_ID,
		Art.terrain_tile(_grid.terrain[index], variant)
	)
	var ore: int = _grid.ore[index]
	if ore == TileTypes.Ore.NONE:
		ore_layer.erase_cell(cell)
		return
	# Богатая клетка получает более «плотный» вариант рисунка — залежь видно издалека.
	var richness_variant: int = variant
	if _grid.ore_amount[index] > MapGenerator.ORE_AMOUNT_MAX / 2:
		richness_variant = (variant + 1) % TileTypes.VARIANTS
	ore_layer.set_cell(
		cell,
		TilesetFactory.TERRAIN_SOURCE_ID,
		Art.ore_tile(ore, richness_variant)
	)


func _on_cell_changed(cell: Vector2i) -> void:
	var chunk: Vector2i = Vector2i(
		floori(float(cell.x) / Constants.CHUNK_SIZE),
		floori(float(cell.y) / Constants.CHUNK_SIZE)
	)
	if _loaded.has(chunk):
		_draw_cell(cell)
