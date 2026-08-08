class_name WaterPump
extends Building

## Водозабор: качает воду из водоёма рядом.
##
## Вода на карте перестаёт быть картинкой: без неё не работают котлы и
## реакторы, а значит расположение базы у воды становится решением, а не
## декорацией.

## Литров (единиц) в секунду при полном питании.
const RATE: float = 3.0

var _progress: float = 0.0


func rate() -> float:
	return RATE * power_satisfaction


func tick(delta: float, _context: Dictionary) -> void:
	if not enabled:
		status = Status.DISABLED
		return
	if power_satisfaction <= 0.01:
		status = Status.NO_POWER
		return
	if output.is_full():
		status = Status.OUTPUT_FULL
		return

	_progress += rate() * delta
	if _progress < 1.0:
		status = Status.WORKING
		return
	var produced: int = mini(int(_progress), output.free_space())
	if produced <= 0:
		status = Status.OUTPUT_FULL
		return
	_progress -= float(produced)
	output.add(Items.WATER, produced)
	status = Status.WORKING
	Events.items_harvested.emit(Items.WATER, produced)
	Events.inventory_changed.emit(id)


func _serialize_extra() -> Dictionary:
	return {"progress": _progress}


func _deserialize_extra(data: Dictionary) -> void:
	_progress = float(data.get("progress", 0.0))
