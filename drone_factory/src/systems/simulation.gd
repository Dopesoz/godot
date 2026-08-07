class_name Simulation
extends Node

## Сердце игры: фиксированный логический тик.
##
## Симуляция идёт с частотой Constants.TICKS_PER_SECOND и не зависит от FPS.
## На слабом телефоне кадры проседают и «плавают» — привязанная к кадру
## фабрика в такие моменты работала бы то быстрее, то медленнее, а сохранение
## переставало бы воспроизводиться. Здесь же 100 тиков — это ровно 10 секунд
## игрового времени на любом устройстве.
##
## Отставание догоняется не более чем MAX_CATCHUP_TICKS тиков за кадр: иначе
## после сворачивания приложения игра пыталась бы отсчитать тысячи тиков
## в одном кадре и повисла бы.

## Длительность полных суток в секундах игрового времени.
const DAY_LENGTH: float = 300.0
## Доля суток, занятая полноценным днём и полноценной ночью.
const DAY_RATIO: float = 0.5
const NIGHT_RATIO: float = 0.2

var paused: bool = false

var tick_count: int = 0
var game_time: float = 0.0

var world: GameWorld = null
## Системы в порядке выполнения. Порядок — часть правил игры: сначала считается
## энергия (от неё зависит скорость работы), затем работают здания, затем
## логистика развозит результат.
var systems: Array[GameSystem] = []

var _accumulator: float = 0.0
## Сколько тиков было пропущено из-за ограничения догона — диагностика для HUD.
var _dropped_ticks: int = 0


func setup(game_world: GameWorld) -> void:
	world = game_world
	for system: GameSystem in systems:
		system.setup(game_world)


## Регистрирует систему. Порядок добавления — порядок выполнения.
func add_system(system: GameSystem) -> GameSystem:
	systems.append(system)
	if world != null:
		system.setup(world)
	return system


func get_system(script_class: Variant) -> GameSystem:
	for system: GameSystem in systems:
		if is_instance_of(system, script_class):
			return system
	return null


func _process(delta: float) -> void:
	if paused or world == null or world.buildings == null:
		return
	# Огромная delta приходит после сворачивания приложения или паузы ОС.
	_accumulator += minf(delta, 1.0)

	var ticks: int = 0
	while _accumulator >= Constants.TICK_DELTA:
		_accumulator -= Constants.TICK_DELTA
		if ticks >= Constants.MAX_CATCHUP_TICKS:
			_dropped_ticks += 1
			continue
		tick()
		ticks += 1


## Один логический тик. Вызывается и из тестов напрямую.
func tick() -> void:
	tick_count += 1
	game_time += Constants.TICK_DELTA

	var context: Dictionary = {
		"grid": world.grid,
		"registry": world.buildings,
		"daylight": daylight(),
		"tick": tick_count,
	}

	for system: GameSystem in systems:
		system.tick(Constants.TICK_DELTA, context)


## Освещённость 0..1: день, плавные сумерки, ночь.
func daylight() -> float:
	return daylight_at(game_time)


static func daylight_at(time: float) -> float:
	var phase: float = fposmod(time, DAY_LENGTH) / DAY_LENGTH
	var dusk_start: float = DAY_RATIO
	var night_start: float = DAY_RATIO + (1.0 - DAY_RATIO - NIGHT_RATIO) * 0.5
	var night_end: float = night_start + NIGHT_RATIO

	if phase < dusk_start:
		return 1.0
	if phase < night_start:
		return 1.0 - (phase - dusk_start) / (night_start - dusk_start)
	if phase < night_end:
		return 0.0
	return (phase - night_end) / (1.0 - night_end)


## Время суток строкой для интерфейса.
func time_of_day_text() -> String:
	var light: float = daylight()
	if light >= 0.99:
		return "День"
	if light <= 0.01:
		return "Ночь"
	return "Сумерки"


func dropped_ticks() -> int:
	return _dropped_ticks


func reset() -> void:
	tick_count = 0
	game_time = 0.0
	_accumulator = 0.0
	_dropped_ticks = 0
	for system: GameSystem in systems:
		system.reset()
