class_name SolarPanel
extends Building

## Солнечная панель: выработка пропорциональна освещённости.
##
## Панель ничего не хранит, поэтому ночью сеть питается только от
## аккумуляторов — это и делает их осмысленными.

var last_output: float = 0.0


func power_supply(daylight: float) -> float:
	if not enabled:
		return 0.0
	return BuildingDefs.power_gen(def_id) * clampf(daylight, 0.0, 1.0)


func tick(_delta: float, context: Dictionary) -> void:
	if not enabled:
		status = Status.DISABLED
		return
	last_output = power_supply(context["daylight"])
	status = Status.WORKING if last_output > 0.01 else Status.IDLE
