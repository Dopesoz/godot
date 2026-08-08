class_name WindTurbine
extends Building

## Ветряк: слабее солнечной панели, но не зависит от времени суток.
##
## Смысл в надёжности, а не в мощности: панель днём даёт больше, но ночью
## ноль, а ветряк держит небольшую, почти постоянную выработку. Ставить
## только ветряки невыгодно, но пара штук закрывает ночной провал дешевле,
## чем поле аккумуляторов.

var last_output: float = 0.0
## Сила ветра на текущем тике, 0..1. Ставит сам ветряк из контекста.
var wind: float = 0.5


func power_supply(_daylight: float) -> float:
	if not enabled:
		return 0.0
	return BuildingDefs.power_gen(def_id) * wind


func tick(_delta: float, context: Dictionary) -> void:
	if not enabled:
		status = Status.DISABLED
		return
	wind = clampf(float(context.get("wind", 0.5)), 0.0, 1.0)
	last_output = power_supply(0.0)
	status = Status.WORKING if last_output > 0.01 else Status.IDLE
