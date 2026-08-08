class_name Beacon
extends Building

## Спасательный маяк — цель игры.
##
## Маяк ничего не производит: он копит заряд, пока в сети есть ток, и теряет
## его, когда тока нет. Поэтому финал требует не разового рывка, а стабильной
## энергетики — ровно того, ради чего строилась вся фабрика.

## Сколько секунд полного питания нужно на передачу сигнала.
const CHARGE_SECONDS: float = 150.0
## Как быстро теряется заряд без питания (доля в секунду).
const DRAIN_PER_SECOND: float = 0.04

var charge: float = 0.0
var transmitted: bool = false


func progress() -> float:
	return clampf(charge / CHARGE_SECONDS, 0.0, 1.0)


func tick(delta: float, _context: Dictionary) -> void:
	if not enabled:
		status = Status.DISABLED
		return
	if transmitted:
		status = Status.WORKING
		return

	if power_satisfaction <= 0.01:
		# Заряд утекает: маяк нельзя «накопить» урывками при дефиците энергии.
		charge = maxf(charge - CHARGE_SECONDS * DRAIN_PER_SECOND * delta, 0.0)
		status = Status.NO_POWER
		Events.beacon_progress.emit(progress())
		return

	charge = minf(charge + delta * power_satisfaction, CHARGE_SECONDS)
	status = Status.WORKING
	Events.beacon_progress.emit(progress())

	if charge >= CHARGE_SECONDS:
		transmitted = true
		Events.game_won.emit()


func _serialize_extra() -> Dictionary:
	return {"charge": charge, "done": transmitted}


func _deserialize_extra(data: Dictionary) -> void:
	charge = clampf(float(data.get("charge", 0.0)), 0.0, CHARGE_SECONDS)
	transmitted = bool(data.get("done", false))
