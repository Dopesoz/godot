class_name BuildingRegistry
extends RefCounted

## Реестр всех зданий мира: постановка, снос, поиск.
##
## Кроме словаря по id ведётся индекс по чанкам. Логистика дронов и электросеть
## постоянно спрашивают «кто рядом», и перебор всех зданий на каждый запрос
## превращается в O(n²) при разрастании фабрики. Индекс сводит это к перебору
## нескольких чанков.

enum PlaceError { OK, UNKNOWN_DEF, OUT_OF_BOUNDS, OCCUPIED, BAD_TERRAIN, NO_ORE, NO_WATER }

const PLACE_ERROR_TEXT: Dictionary[int, String] = {
	PlaceError.OK: "",
	PlaceError.UNKNOWN_DEF: "Неизвестное здание",
	PlaceError.OUT_OF_BOUNDS: "За краем мира",
	PlaceError.OCCUPIED: "Место занято",
	PlaceError.BAD_TERRAIN: "Неподходящая поверхность",
	PlaceError.NO_ORE: "Здесь нет руды",
	PlaceError.NO_WATER: "Нужно поставить у воды",
}

var grid: Grid = null

var _buildings: Dictionary[int, Building] = {}
## Индекс «чанк -> id зданий, задевающих этот чанк».
var _chunk_index: Dictionary[Vector2i, PackedInt32Array] = {}
var _next_id: int = 1

## Кеши выборок. Системы спрашивают «все здания» и «здания такого-то вида»
## десять раз в секунду; собирать массив заново на каждый запрос — это тысячи
## лишних аллокаций в секунду на телефоне. Кеш сбрасывается только при
## постройке и сносе, то есть редко.
var _all_cache: Array[Building] = []
var _kind_cache: Dictionary[int, Array] = {}
var _cache_valid: bool = false


func _init(target_grid: Grid) -> void:
	grid = target_grid


## --- Постановка и снос -----------------------------------------------------

## Проверка места. Возвращает код ошибки, чтобы интерфейс объяснил игроку отказ.
func check_placement(def_id: StringName, origin: Vector2i) -> int:
	if not BuildingDefs.exists(def_id):
		return PlaceError.UNKNOWN_DEF
	var area := Rect2i(origin, BuildingDefs.size_of(def_id))
	if not grid.is_area_inside(area):
		return PlaceError.OUT_OF_BOUNDS

	for y: int in range(area.position.y, area.position.y + area.size.y):
		for x: int in range(area.position.x, area.position.x + area.size.x):
			var cell := Vector2i(x, y)
			if grid.get_building(cell) != Grid.NO_BUILDING:
				return PlaceError.OCCUPIED
			if not TileTypes.is_buildable(grid.get_terrain(cell)):
				return PlaceError.BAD_TERRAIN

	if BuildingDefs.needs_ore(def_id) and grid.dominant_ore_in_area(area).x == TileTypes.Ore.NONE:
		return PlaceError.NO_ORE
	if BuildingDefs.needs_water(def_id) and not _touches_water(area):
		return PlaceError.NO_WATER
	return PlaceError.OK


## Есть ли вода вплотную к площадке (по краю, без диагоналей).
func _touches_water(area: Rect2i) -> bool:
	for x: int in range(area.position.x - 1, area.position.x + area.size.x + 1):
		for y: int in range(area.position.y - 1, area.position.y + area.size.y + 1):
			var cell := Vector2i(x, y)
			if area.has_point(cell):
				continue
			# Диагонали не считаются: насос должен стоять к воде стороной.
			var on_corner: bool = (
				(x < area.position.x or x >= area.position.x + area.size.x)
				and (y < area.position.y or y >= area.position.y + area.size.y)
			)
			if on_corner:
				continue
			# Порядок важен: за краем мира get_terrain() отвечает «вода».
			if grid.in_bounds(cell) and grid.get_terrain(cell) == TileTypes.Terrain.WATER:
				return true
	return false


func can_place(def_id: StringName, origin: Vector2i) -> bool:
	return check_placement(def_id, origin) == PlaceError.OK


static func placement_error_text(error: int) -> String:
	return PLACE_ERROR_TEXT.get(error, "Нельзя построить")


## Ставит здание. Проверку места вызывающий код должен сделать заранее —
## здесь она повторяется как страховка.
func place(def_id: StringName, origin: Vector2i) -> Building:
	if not can_place(def_id, origin):
		return null
	var building: Building = BuildingFactory.create(def_id)
	if building == null:
		return null

	building.id = _next_id
	_next_id += 1
	building.setup(def_id, origin)

	_register(building)
	building.on_world_ready(grid)
	Events.building_placed.emit(building.id)
	return building


func remove(building_id: int) -> bool:
	var building: Building = _buildings.get(building_id)
	if building == null:
		return false
	grid.fill_area_building(building.rect(), Grid.NO_BUILDING)
	_unindex(building)
	_buildings.erase(building_id)
	_invalidate_cache()
	Events.building_removed.emit(building_id)
	return true


func clear() -> void:
	for building_id: int in _buildings.keys():
		var building: Building = _buildings[building_id]
		grid.fill_area_building(building.rect(), Grid.NO_BUILDING)
	_buildings.clear()
	_chunk_index.clear()
	_invalidate_cache()
	_next_id = 1


## --- Поиск -----------------------------------------------------------------

func get_building(building_id: int) -> Building:
	return _buildings.get(building_id)


func at_cell(cell: Vector2i) -> Building:
	var building_id: int = grid.get_building(cell)
	if building_id == Grid.NO_BUILDING:
		return null
	return _buildings.get(building_id)


func count() -> int:
	return _buildings.size()


func all_ids() -> Array[int]:
	var ids: Array[int] = []
	for building_id: int in _buildings:
		ids.append(building_id)
	return ids


## Все здания. Возвращается общий массив кеша — менять его снаружи нельзя.
func all() -> Array[Building]:
	_ensure_cache()
	return _all_cache


## Здания указанного вида (порты, склады, лаборатории) — тоже из кеша.
func of_kind(kind: int) -> Array[Building]:
	_ensure_cache()
	if not _kind_cache.has(kind):
		var empty: Array[Building] = []
		_kind_cache[kind] = empty
	return _kind_cache[kind]


## Кеш пересобирается в НОВЫЕ массивы, а не очищается на месте: снос здания
## во время обхода (обычное дело в игровом коде и в тестах) иначе обрезал бы
## массив прямо под ногами у цикла. Со свежими массивами обход спокойно
## дорабатывает по устаревшему снимку.
func _ensure_cache() -> void:
	if _cache_valid:
		return
	var all_buildings: Array[Building] = []
	var by_kind: Dictionary[int, Array] = {}
	for building_id: int in _buildings:
		var building: Building = _buildings[building_id]
		all_buildings.append(building)
		var kind: int = BuildingDefs.kind(building.def_id)
		if not by_kind.has(kind):
			var bucket: Array[Building] = []
			by_kind[kind] = bucket
		var kind_bucket: Array[Building] = by_kind[kind]
		kind_bucket.append(building)
	_all_cache = all_buildings
	_kind_cache = by_kind
	_cache_valid = true


func _invalidate_cache() -> void:
	_cache_valid = false


## Здания, чей центр лежит в радиусе (в клетках) от точки. Идёт по индексу чанков.
func in_radius(center_cell: Vector2i, radius: float) -> Array[Building]:
	var result: Array[Building] = []
	var seen: Dictionary[int, bool] = {}
	var chunk_radius: int = int(ceilf(radius / float(Constants.CHUNK_SIZE))) + 1
	var center_chunk: Vector2i = _chunk_of(center_cell)
	var radius_squared: float = radius * radius

	for cy: int in range(center_chunk.y - chunk_radius, center_chunk.y + chunk_radius + 1):
		for cx: int in range(center_chunk.x - chunk_radius, center_chunk.x + chunk_radius + 1):
			var bucket: PackedInt32Array = _chunk_index.get(Vector2i(cx, cy), PackedInt32Array())
			for building_id: int in bucket:
				if seen.has(building_id):
					continue
				seen[building_id] = true
				var building: Building = _buildings.get(building_id)
				if building == null:
					continue
				if Vector2(building.center_cell()).distance_squared_to(Vector2(center_cell)) <= radius_squared:
					result.append(building)
	return result


## Здания, пересекающие прямоугольную область (в клетках). Используется
## отрисовкой: перебирать весь мир ради экрана нельзя.
func in_rect(area: Rect2i) -> Array[Building]:
	var result: Array[Building] = []
	var seen: Dictionary[int, bool] = {}
	for chunk: Vector2i in _chunks_of(area):
		var bucket: PackedInt32Array = _chunk_index.get(chunk, PackedInt32Array())
		for building_id: int in bucket:
			if seen.has(building_id):
				continue
			seen[building_id] = true
			var building: Building = _buildings.get(building_id)
			if building != null and building.rect().intersects(area):
				result.append(building)
	return result


## --- Сохранение ------------------------------------------------------------

func serialize() -> Array:
	var list: Array = []
	for building_id: int in _buildings:
		list.append(_buildings[building_id].serialize())
	return list


func deserialize(list: Array) -> void:
	clear()
	for entry: Variant in list:
		var data: Dictionary = entry
		var def_id := StringName(data.get("def", ""))
		if not BuildingDefs.exists(def_id):
			Log.warn("Реестр: пропущено неизвестное здание %s" % def_id)
			continue
		var building: Building = BuildingFactory.create(def_id)
		if building == null:
			continue
		building.id = int(data.get("id", _next_id))
		building.setup(def_id, Vector2i(int(data.get("x", 0)), int(data.get("y", 0))))
		building.deserialize(data)
		_register(building)
		building.on_world_ready(grid)
		_next_id = maxi(_next_id, building.id + 1)


## --- Индекс ----------------------------------------------------------------

func _register(building: Building) -> void:
	_invalidate_cache()
	_buildings[building.id] = building
	grid.fill_area_building(building.rect(), building.id)
	_index(building)


func _index(building: Building) -> void:
	for chunk: Vector2i in _chunks_of(building.rect()):
		var bucket: PackedInt32Array = _chunk_index.get(chunk, PackedInt32Array())
		bucket.append(building.id)
		_chunk_index[chunk] = bucket


func _unindex(building: Building) -> void:
	for chunk: Vector2i in _chunks_of(building.rect()):
		if not _chunk_index.has(chunk):
			continue
		var bucket: PackedInt32Array = _chunk_index[chunk]
		var position: int = bucket.find(building.id)
		if position >= 0:
			bucket.remove_at(position)
		if bucket.is_empty():
			_chunk_index.erase(chunk)
		else:
			_chunk_index[chunk] = bucket


static func _chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(cell.x) / Constants.CHUNK_SIZE),
		floori(float(cell.y) / Constants.CHUNK_SIZE)
	)


static func _chunks_of(area: Rect2i) -> Array[Vector2i]:
	var from: Vector2i = _chunk_of(area.position)
	var to: Vector2i = _chunk_of(area.position + area.size - Vector2i.ONE)
	var chunks: Array[Vector2i] = []
	for cy: int in range(from.y, to.y + 1):
		for cx: int in range(from.x, to.x + 1):
			chunks.append(Vector2i(cx, cy))
	return chunks
