class_name Building
extends RefCounted

## Базовое здание. Здания — обычные объекты, а не узлы сцены.
##
## Почему так: тысяча зданий в виде Node2D — это тысяча _process, тысяча
## трансформов и обход дерева каждый кадр. Здесь здание — данные, которые
## обновляет система, а рисуются они пакетно (тайлы и MultiMesh). На слабом
## Android это единственный способ удержать 60 FPS при большой фабрике.

## Состояние для интерфейса и подсветки на карте.
enum Status { WORKING, IDLE, NO_POWER, NO_INPUT, OUTPUT_FULL, NO_ORE, DISABLED }

const STATUS_TEXT: Dictionary[int, String] = {
	Status.WORKING: "Работает",
	Status.IDLE: "Ожидание",
	Status.NO_POWER: "Нет энергии",
	Status.NO_INPUT: "Нет сырья",
	Status.OUTPUT_FULL: "Выход заполнен",
	Status.NO_ORE: "Руда исчерпана",
	Status.DISABLED: "Выключено",
}

var id: int = 0
var def_id: StringName = &""
var origin: Vector2i = Vector2i.ZERO
var size: Vector2i = Vector2i.ONE

var input: Inventory = null
var output: Inventory = null

## Доля удовлетворённого спроса на энергию, 0..1. Ставит система электричества.
var power_satisfaction: float = 1.0
## Здание подключено к какой-либо электросети.
var connected: bool = false
var enabled: bool = true
var status: int = Status.IDLE


## Вызывается сразу после создания: настраивает инвентари по описанию.
func setup(building_def_id: StringName, cell: Vector2i) -> void:
	def_id = building_def_id
	origin = cell
	size = BuildingDefs.size_of(def_id)
	var input_capacity: int = BuildingDefs.input_capacity(def_id)
	var output_capacity: int = BuildingDefs.output_capacity(def_id)
	input = Inventory.new(input_capacity) if input_capacity > 0 else null
	output = Inventory.new(output_capacity) if output_capacity > 0 else null
	_on_setup()


## Точка расширения для наследников (бур, печь, ...).
func _on_setup() -> void:
	pass


## Вызывается реестром сразу после постановки и после загрузки сохранения,
## когда здание уже знает своё место и может посмотреть на мир под собой.
func on_world_ready(_grid: Grid) -> void:
	pass


## --- Геометрия -------------------------------------------------------------

func rect() -> Rect2i:
	return Rect2i(origin, size)


func center() -> Vector2:
	return Grid.area_center(rect())


func center_cell() -> Vector2i:
	return origin + size / 2


func covers(cell: Vector2i) -> bool:
	return rect().has_point(cell)


## Расстояние между зданиями в клетках (по центрам) — для радиусов сети и дронов.
func distance_to(other: Building) -> float:
	return Vector2(center_cell()).distance_to(Vector2(other.center_cell()))


## --- Энергия ---------------------------------------------------------------

## Сколько кВт здание хочет получить прямо сейчас.
func power_demand() -> float:
	if not enabled:
		return 0.0
	return BuildingDefs.power_use(def_id)


## Сколько кВт здание отдаёт в сеть прямо сейчас.
func power_supply(_daylight: float) -> float:
	return 0.0


func has_power() -> bool:
	return power_satisfaction > 0.01


## --- Симуляция -------------------------------------------------------------

## Один логический тик. Наследники переопределяют.
func tick(_delta: float, _context: Dictionary) -> void:
	status = Status.DISABLED if not enabled else Status.IDLE


## Предметы, которые здание готово отдать дронам.
func provides() -> Dictionary[StringName, int]:
	if output == null:
		return {}
	return output.contents()


## Предметы, которых зданию не хватает: id -> сколько запросить.
func requests() -> Dictionary[StringName, int]:
	return {}


func status_text() -> String:
	return STATUS_TEXT.get(status, "?")


func display_name() -> String:
	return BuildingDefs.display_name(def_id)


## --- Сохранение ------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"def": String(def_id),
		"x": origin.x,
		"y": origin.y,
		"enabled": enabled,
	}
	if input != null and not input.is_empty():
		data["in"] = input.serialize()
	if output != null and not output.is_empty():
		data["out"] = output.serialize()
	var extra: Dictionary = _serialize_extra()
	if not extra.is_empty():
		data["extra"] = extra
	return data


func deserialize(data: Dictionary) -> void:
	enabled = bool(data.get("enabled", true))
	if input != null and data.has("in"):
		input.deserialize(data["in"])
	if output != null and data.has("out"):
		output.deserialize(data["out"])
	if data.has("extra"):
		_deserialize_extra(data["extra"])


## Точки расширения для состояния наследников (рецепт, прогресс, ...).
func _serialize_extra() -> Dictionary:
	return {}


func _deserialize_extra(_data: Dictionary) -> void:
	pass
