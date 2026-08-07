class_name Accumulator
extends Building

## Аккумулятор: копит излишки днём и отдаёт их ночью.
##
## Заряд хранится в кДж. Система электричества сама распределяет заряд по
## аккумуляторам сети, здание лишь предоставляет ёмкость.

var charge: float = 0.0


func capacity() -> float:
	return BuildingDefs.ACCUMULATOR_CAPACITY


func charge_ratio() -> float:
	return clampf(charge / capacity(), 0.0, 1.0)


## Принимает энергию, возвращает принятое количество (кДж).
func store(energy: float) -> float:
	if not enabled:
		return 0.0
	var accepted: float = minf(energy, capacity() - charge)
	charge += accepted
	return accepted


## Отдаёт энергию, возвращает выданное количество (кДж).
func draw(energy: float) -> float:
	if not enabled:
		return 0.0
	var given: float = minf(energy, charge)
	charge -= given
	return given


func tick(_delta: float, _context: Dictionary) -> void:
	if not enabled:
		status = Status.DISABLED
		return
	status = Status.WORKING if charge > 0.01 else Status.IDLE


func _serialize_extra() -> Dictionary:
	return {"charge": charge}


func _deserialize_extra(data: Dictionary) -> void:
	charge = clampf(float(data.get("charge", 0.0)), 0.0, capacity())
