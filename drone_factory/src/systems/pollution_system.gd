class_name PollutionSystem
extends GameSystem

## Загрязнение от сжигания угля.
##
## Смысл механики — сделать уголь выгодным, но не бесплатным. Котёл мощнее
## солнечной панели и работает ночью, зато копоть висит над картой и режет
## выработку ВСЕХ панелей. Чем больше угля, тем меньше толку от солнца:
## игрок вынужден выбирать, а не просто ставить котлы вместо панелей.
##
## Система выполняется первой в тике: расчёт энергии должен видеть уже
## обновлённый множитель, иначе штраф отставал бы на тик.

## Уровень загрязнения, при котором штраф солнцу достигает максимума.
const HEAVY_LEVEL: float = 420.0
## Максимальная доля выработки, которую съедает копоть.
const MAX_PENALTY: float = 0.6
## Какая доля загрязнения рассеивается за секунду.
const DECAY_PER_SECOND: float = 0.02

var level: float = 0.0

var _last_reported: float = -1.0


func system_name() -> String:
	return "загрязнение"


func reset() -> void:
	level = 0.0
	_last_reported = -1.0


func tick(delta: float, context: Dictionary) -> void:
	var registry: BuildingRegistry = context["registry"]

	var emitted: float = 0.0
	for kind: int in [BuildingDefs.Kind.BOILER, BuildingDefs.Kind.REACTOR]:
		for building: Building in registry.of_kind(kind):
			emitted += (building as FuelGenerator).pollution_rate()

	# Рассеивание пропорционально уровню: загрязнение выходит на равновесие,
	# а не растёт бесконечно и не исчезает мгновенно после сноса котлов.
	level = maxf(level + emitted * delta - level * DECAY_PER_SECOND * delta, 0.0)

	var factor: float = solar_factor()
	for building: Building in registry.of_kind(BuildingDefs.Kind.SOLAR):
		(building as SolarPanel).pollution_multiplier = factor

	_report_if_changed(factor)


## Во сколько раз загрязнение режет выработку солнечных панелей.
func solar_factor() -> float:
	return 1.0 - minf(level / HEAVY_LEVEL, 1.0) * MAX_PENALTY


## Уровень в процентах от «тяжёлого» — так его показывает интерфейс.
func level_percent() -> int:
	return int(round(minf(level / HEAVY_LEVEL, 1.0) * 100.0))


func serialize() -> float:
	return level


func deserialize(value: float) -> void:
	level = maxf(value, 0.0)


func _report_if_changed(factor: float) -> void:
	var rounded: float = snappedf(level, 5.0)
	if is_equal_approx(rounded, _last_reported):
		return
	_last_reported = rounded
	Events.pollution_changed.emit(level, factor)
