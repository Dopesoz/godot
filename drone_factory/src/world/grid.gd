class_name Grid
extends RefCounted

## Данные мира по клеткам, хранятся в плоских типизированных массивах.
##
## Почему не объекты-клетки: 512x512 = 262144 клетки. Объект на клетку — это
## сотни мегабайт и мусор для сборщика; плоские Packed*Array занимают ~1.3 МБ,
## лежат в непрерывной памяти и читаются за один индекс. Для слабого Android
## это разница между «идёт» и «не запускается».
##
## Раскладка (индекс = y * size + x):
##   terrain      PackedByteArray  — TileTypes.Terrain
##   ore          PackedByteArray  — TileTypes.Ore
##   ore_amount   PackedInt32Array — остаток руды в клетке
##   building     PackedInt32Array — id здания, занимающего клетку (0 — пусто)

const NO_BUILDING: int = 0

var size: int

var terrain: PackedByteArray
var ore: PackedByteArray
var ore_amount: PackedInt32Array
var building: PackedInt32Array


func _init(world_size: int = Constants.WORLD_SIZE) -> void:
	size = world_size
	var count: int = size * size
	terrain = PackedByteArray()
	terrain.resize(count)
	ore = PackedByteArray()
	ore.resize(count)
	ore_amount = PackedInt32Array()
	ore_amount.resize(count)
	building = PackedInt32Array()
	building.resize(count)


## --- Координаты ------------------------------------------------------------

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size and cell.y < size


func index_of(cell: Vector2i) -> int:
	return cell.y * size + cell.x


func cell_of(index: int) -> Vector2i:
	return Vector2i(index % size, index / size)


## Левый верхний угол клетки в мировых пикселях.
static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * float(Constants.TILE_SIZE)


## Центр клетки в мировых пикселях — точка, к которой летят дроны.
static func cell_to_world_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * float(Constants.TILE_SIZE)


static func world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / Constants.TILE_SIZE), floori(position.y / Constants.TILE_SIZE))


## Центр прямоугольной области в мировых пикселях.
static func area_center(area: Rect2i) -> Vector2:
	return (Vector2(area.position) + Vector2(area.size) * 0.5) * float(Constants.TILE_SIZE)


## --- Доступ к клеткам ------------------------------------------------------

func get_terrain(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return TileTypes.Terrain.WATER
	return terrain[index_of(cell)]


func set_terrain(cell: Vector2i, value: int) -> void:
	if in_bounds(cell):
		terrain[index_of(cell)] = value


func get_ore(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return TileTypes.Ore.NONE
	return ore[index_of(cell)]


func get_ore_amount(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return 0
	return ore_amount[index_of(cell)]


func set_ore(cell: Vector2i, ore_type: int, amount: int) -> void:
	if not in_bounds(cell):
		return
	var index: int = index_of(cell)
	ore[index] = ore_type if amount > 0 else TileTypes.Ore.NONE
	ore_amount[index] = maxi(amount, 0)


## Снимает до `amount` единиц руды. Возвращает, сколько удалось снять.
func extract_ore(cell: Vector2i, amount: int) -> int:
	if not in_bounds(cell) or amount <= 0:
		return 0
	var index: int = index_of(cell)
	var taken: int = mini(amount, ore_amount[index])
	if taken <= 0:
		return 0
	ore_amount[index] -= taken
	if ore_amount[index] <= 0:
		ore[index] = TileTypes.Ore.NONE
		Events.cell_changed.emit(cell)
	return taken


func get_building(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return NO_BUILDING
	return building[index_of(cell)]


func set_building(cell: Vector2i, building_id: int) -> void:
	if in_bounds(cell):
		building[index_of(cell)] = building_id


## --- Работа с областями (здания занимают до нескольких клеток) -------------

func is_area_inside(area: Rect2i) -> bool:
	return (
		area.position.x >= 0 and area.position.y >= 0
		and area.position.x + area.size.x <= size
		and area.position.y + area.size.y <= size
	)


## Свободна ли область под постройку: внутри мира, пригодный грунт, нет зданий.
func is_area_buildable(area: Rect2i) -> bool:
	if not is_area_inside(area) or area.size.x <= 0 or area.size.y <= 0:
		return false
	for y: int in range(area.position.y, area.position.y + area.size.y):
		var row: int = y * size
		for x: int in range(area.position.x, area.position.x + area.size.x):
			var index: int = row + x
			if building[index] != NO_BUILDING:
				return false
			if not TileTypes.is_buildable(terrain[index]):
				return false
	return true


func fill_area_building(area: Rect2i, building_id: int) -> void:
	for y: int in range(area.position.y, area.position.y + area.size.y):
		var row: int = y * size
		for x: int in range(area.position.x, area.position.x + area.size.x):
			if y >= 0 and x >= 0 and x < size and y < size:
				building[row + x] = building_id


## Сколько клеток области содержат указанную руду и сколько её всего.
func count_ore_in_area(area: Rect2i, ore_type: int) -> Vector2i:
	var cells: int = 0
	var total: int = 0
	for y: int in range(area.position.y, area.position.y + area.size.y):
		if y < 0 or y >= size:
			continue
		var row: int = y * size
		for x: int in range(area.position.x, area.position.x + area.size.x):
			if x < 0 or x >= size:
				continue
			var index: int = row + x
			if ore[index] == ore_type and ore_amount[index] > 0:
				cells += 1
				total += ore_amount[index]
	return Vector2i(cells, total)


## Преобладающая руда в области: (тип, суммарный запас). Нужна бурам.
func dominant_ore_in_area(area: Rect2i) -> Vector2i:
	var totals: PackedInt32Array = PackedInt32Array()
	totals.resize(TileTypes.ORE_COUNT)
	for y: int in range(area.position.y, area.position.y + area.size.y):
		if y < 0 or y >= size:
			continue
		var row: int = y * size
		for x: int in range(area.position.x, area.position.x + area.size.x):
			if x < 0 or x >= size:
				continue
			var index: int = row + x
			if ore_amount[index] > 0:
				totals[ore[index]] += ore_amount[index]
	var best_type: int = TileTypes.Ore.NONE
	var best_total: int = 0
	for ore_type: int in range(1, TileTypes.ORE_COUNT):
		if totals[ore_type] > best_total:
			best_total = totals[ore_type]
			best_type = ore_type
	return Vector2i(best_type, best_total)


## --- Сериализация ----------------------------------------------------------

## Слои мира пакуются в бинарный блоб: JSON-массив на 262144 числа неприемлем
## ни по размеру файла, ни по времени разбора на телефоне.
func serialize_layers() -> Dictionary:
	var blob := PackedByteArray()
	blob.append_array(terrain)
	blob.append_array(ore)
	blob.append_array(ore_amount.to_byte_array())
	return {
		"size": size,
		"blob": Marshalls.raw_to_base64(blob.compress(FileAccess.COMPRESSION_ZSTD)),
		"blob_size": blob.size(),
	}


func deserialize_layers(data: Dictionary) -> bool:
	var stored_size: int = int(data.get("size", 0))
	if stored_size != size:
		Log.error("Grid: размер мира в сохранении (%d) не совпадает с текущим (%d)" % [stored_size, size])
		return false
	var raw: PackedByteArray = Marshalls.base64_to_raw(String(data.get("blob", "")))
	var expected: int = int(data.get("blob_size", 0))
	var blob: PackedByteArray = raw.decompress(expected, FileAccess.COMPRESSION_ZSTD)
	var count: int = size * size
	if blob.size() != count * 6:
		Log.error("Grid: повреждённый блоб мира (%d байт)" % blob.size())
		return false
	terrain = blob.slice(0, count)
	ore = blob.slice(count, count * 2)
	ore_amount = blob.slice(count * 2, count * 6).to_int32_array()
	building.fill(NO_BUILDING)
	return true
