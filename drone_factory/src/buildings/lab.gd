class_name Lab
extends Building

## Лаборатория: тратит колбы на текущее исследование.
##
## Что именно нужно, лаборатории сообщает система исследований — здание не
## знает про дерево технологий и просто потребляет заказанное.

## Сколько колб съедает лаборатория в секунду при полном питании.
const CONSUMPTION_RATE: float = 0.5
## Запас колб, который лаборатория просит у дронов (в штуках каждого вида).
const REQUEST_BUFFER: int = 10

## Какие колбы нужны прямо сейчас: ставит ResearchSystem.
var required_science: Array[StringName] = []

var _progress: float = 0.0


func is_working() -> bool:
	return status == Status.WORKING


## Пытается потребить колбы на dt секунд. Возвращает, сколько колб съедено.
func consume(delta: float) -> int:
	if not enabled or required_science.is_empty():
		status = Status.IDLE
		return 0
	if power_satisfaction <= 0.01:
		status = Status.NO_POWER
		return 0

	_progress += CONSUMPTION_RATE * power_satisfaction * delta
	if _progress < 1.0:
		# Колбы должны быть в наличии, иначе прогресс не идёт.
		if not _has_any_science():
			status = Status.NO_INPUT
			_progress = 0.0
			return 0
		status = Status.WORKING
		return 0

	var consumed: int = 0
	while _progress >= 1.0:
		var item_id: StringName = _pick_science()
		if item_id == &"":
			_progress = 0.0
			status = Status.NO_INPUT
			return consumed
		input.remove(item_id, 1)
		consumed += 1
		_progress -= 1.0
	status = Status.WORKING
	if consumed > 0:
		Events.inventory_changed.emit(id)
	return consumed


func tick(_delta: float, _context: Dictionary) -> void:
	# Потребление вызывает система исследований: только она знает, идёт ли
	# сейчас изучение и на что тратить колбы.
	if not enabled:
		status = Status.DISABLED


func requests() -> Dictionary[StringName, int]:
	var needed: Dictionary[StringName, int] = {}
	if not enabled:
		return needed
	for item_id: StringName in required_science:
		var missing: int = REQUEST_BUFFER - input.count(item_id)
		if missing > 0:
			needed[item_id] = mini(missing, input.free_space())
	return needed


func _has_any_science() -> bool:
	for item_id: StringName in required_science:
		if input.count(item_id) > 0:
			return true
	return false


## Колбы тратятся по очереди, чтобы исследование не встало из-за одного
## закончившегося вида.
func _pick_science() -> StringName:
	var best: StringName = &""
	var best_count: int = 0
	for item_id: StringName in required_science:
		var count: int = input.count(item_id)
		if count > best_count:
			best_count = count
			best = item_id
	return best


func _on_setup() -> void:
	if input != null:
		input.filter = [Items.SCIENCE_RED, Items.SCIENCE_GREEN]


func _serialize_extra() -> Dictionary:
	return {"progress": _progress}


func _deserialize_extra(data: Dictionary) -> void:
	_progress = float(data.get("progress", 0.0))
