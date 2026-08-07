class_name Drill
extends Building

## Бур: добывает руду из клеток под собой.
##
## Тип руды определяется один раз при постановке по преобладающей руде под
## площадкой — «бур на железе» понятнее, чем бур, выдающий вперемешку три
## ресурса. Когда руда под буром кончается, он останавливается и сообщает об
## этом значком, а не молча.

## Базовая скорость добычи, единиц руды в секунду при полном питании.
const BASE_SPEED: float = 0.6

var ore_type: int = TileTypes.Ore.NONE
var mined_item: StringName = &""

var _progress: float = 0.0
## Клетки с рудой под буром. Пересчитываются при исчерпании очередной клетки.
var _resolved: bool = false


func speed() -> float:
	return BASE_SPEED * power_satisfaction


## Сколько руды осталось под буром — показывается в панели здания.
func remaining_ore(grid: Grid) -> int:
	return grid.count_ore_in_area(rect(), ore_type).y


func on_world_ready(grid: Grid) -> void:
	if not _resolved:
		_resolve_ore(grid)


func tick(delta: float, context: Dictionary) -> void:
	if not enabled:
		status = Status.DISABLED
		return
	var grid: Grid = context["grid"]
	if not _resolved:
		_resolve_ore(grid)

	# Наличие руды проверяем до накопления прогресса. Иначе бур над
	# выработанной залежью мигал бы между «работает» и «руда кончилась»,
	# каждый раз дёргая значок и панель.
	var cell: Vector2i = _richest_cell(grid)
	if ore_type == TileTypes.Ore.NONE or mined_item == &"" or cell.x < 0:
		_progress = 0.0
		status = Status.NO_ORE
		return
	if output.is_full():
		status = Status.OUTPUT_FULL
		return
	if power_satisfaction <= 0.01:
		status = Status.NO_POWER
		return

	_progress += speed() * delta
	if _progress < 1.0:
		status = Status.WORKING
		return

	var wanted: int = int(_progress)
	var mined: int = grid.extract_ore(cell, mini(wanted, output.free_space()))
	if mined <= 0:
		status = Status.OUTPUT_FULL
		return
	_progress -= float(mined)
	output.add(mined_item, mined)
	status = Status.WORKING
	Events.inventory_changed.emit(id)


## Клетка с наибольшим запасом нужной руды: бур выедает залежь равномерно
## сверху вниз, а не роет одну клетку до дна.
func _richest_cell(grid: Grid) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_amount: int = 0
	var area: Rect2i = rect()
	for y: int in range(area.position.y, area.position.y + area.size.y):
		for x: int in range(area.position.x, area.position.x + area.size.x):
			var cell := Vector2i(x, y)
			if grid.get_ore(cell) != ore_type:
				continue
			var amount: int = grid.get_ore_amount(cell)
			if amount > best_amount:
				best_amount = amount
				best = cell
	return best


func _resolve_ore(grid: Grid) -> void:
	_resolved = true
	ore_type = grid.dominant_ore_in_area(rect()).x
	mined_item = Items.from_ore(ore_type)


func _serialize_extra() -> Dictionary:
	return {"progress": _progress, "ore": ore_type}


func _deserialize_extra(data: Dictionary) -> void:
	_progress = float(data.get("progress", 0.0))
	ore_type = int(data.get("ore", TileTypes.Ore.NONE))
	mined_item = Items.from_ore(ore_type)
	# Тип руды восстановлен из сохранения — заново определять его не нужно.
	_resolved = ore_type != TileTypes.Ore.NONE
